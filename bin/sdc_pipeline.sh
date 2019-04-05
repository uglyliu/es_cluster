#!/bin/bash
#
# SDC pipeline管理工具

PROGNAME=$(basename "$0")

warn() {
    echo "${PROGNAME}: $*"
}

die() {
    warn "$*"
    exit 1
}

detectOS() {
    # OS specific support (must be 'true' or 'false').
    cygwin=false;
    aix=false;
    os400=false;
    darwin=false;
    case "$(uname)" in
        CYGWIN*)
            cygwin=true
            ;;
        AIX*)
            aix=true
            ;;
        OS400*)
            os400=true
            ;;
        Darwin)
            darwin=true
            ;;
    esac
    # For AIX, set an environment variable
    if ${aix}; then
         export LDR_CNTRL=MAXDATA=0xB0000000@DSA
         echo ${LDR_CNTRL}
    fi
    # In addition to those, go around the linux space and query the widely
    # adopted /etc/os-release to detect linux variants
    if [ -f /etc/os-release ]; then
        . /etc/os-release
    fi
}

init() {
    # Determine if there is special OS handling we must perform
    detectOS

    export SDC_HOME=${HOME}/software/streamsets-datacollector
    export SDC_DATA=${HOME}/data/sdc
    export SDC_LOG=${HOME}/log/sdc
    export SDC_CONF=${HOME}/conf/sdc
}

check_server() {
    return $(awk -v hostname=${HOSTNAME} 'BEGIN {ret=1;}
    { 
        if ( $1 == hostname ) {
            ret=0; exit; 
        }
    }
    END {
        print ret;
    }' ${HOME}/conf/sdc.list)
}

pipe() {
    for i in $@
    do
        if [ "${OPTION}" = "status" ]; then
            TITLE=$(curl -u admin:admin -X GET http://localhost:18630/rest/v1/pipeline/${i} -H "X-Requested-By:sdc" 2>/dev/null | \
                awk -F " : " '{gsub(/"/,""); gsub(/^ */,""); gsub(/,$/,"");
                    if ($1 == "title") title=$2;
                    } END {printf "%s\n", title;}')
            curl -u admin:admin -X GET http://localhost:18630/rest/v1/pipeline/${i}/${OPTION} -H "X-Requested-By:sdc" 2>/dev/null | \
                awk -F " : " -v title="${TITLE}" '{gsub(/"/,""); gsub(/^ */,""); gsub(/,$/,"");
                    if ($1 == "pipelineId") pipelineId=$2;
                    if ($1 == "status") status=$2;
                    } END {printf "%-40.40s %-100.100s %s\n", title, pipelineId, status;}'
        else
            curl -u admin:admin -X POST http://localhost:18630/rest/v1/pipeline/${i}/${OPTION} -H "X-Requested-By:sdc" 2>/dev/null
        fi
    done
}

run() {
    if [ $# -eq 0 ];then
        ID=$(${SDC_HOME}/bin/streamsets cli -U http://localhost:18630 store list | \
        awk -F" : " -v range=${RANGE} '
        BEGIN {result="";}
        /pipelineId/ || /labels/{
            if (/pipelineId/) {
                sub(/^"/, "", $2);
                sub(/",$/, "", $2);
                pipelineId=$2;
            } else if (/labels/) {
                if (index($2, range))
                    result=result" "pipelineId;
            }
        }
        END {print result}')

        pipe ${ID}
    else
        pipe $@
    fi
}

main() {
    if check_server ; then
        init
        run "$@"
    fi
}

if [ $# -lt 2 ]; then
    die "Usage $(basename "$0") {start range [pipelineId]|stop range [pipelineId]|restart range [pipelineId]|status range [pipelineId]}"
fi

case "$1" in
    start|stop|status)
        OPTION=$1
        shift
        RANGE=$1
        shift
        main "$@"
        ;;
    restart)
        shift
        OPTION="stop"
        RANGE=$1
        shift
        main "$@"
        sleep 10
        OPTION="start"
        main "$@"
        ;;
    *)
        die "Usage $(basename "$0") {start range [pipelineId]|stop range [pipelineId]|restart range [pipelineId]|status range [pipelineId]}"
        ;;
esac
