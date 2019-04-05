#!/bin/bash
#
# SDC服务管理工具

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
    #export SDC_JAVA_OPTS="-Xmx512m -Xms512m -javaagent:${HOME}/software/streamsets-datacollector/libexec/bootstrap-libs/main/jolokia-jvm-1.6.0-agent.jar=port=8778,host=localhost"
    export SDC_JAVA_OPTS="-Xmx512m -Xms512m"
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

run() {
    if [ "$1" = "start" ]; then
        if check_server ; then
            ESSTATUS="red"
            while [ ${ESSTATUS} = "red" -o ${ESSTATUS} = "401" ]
            do
                sleep 10
                ESSTATUS=$(curl -GET "localhost:9200/_cluster/health?pretty" 2>/dev/null | \
                    awk -F":" 'BEGIN{status="red"} {gsub(/[\" ,]/,""); if ( $1 == "status" ) status=$2;} END{print status}')
            done
            mkdir -p ${SDC_DATA}/runInfo
            mkdir -p ${SDC_DATA}/pipelines
            mkdir -p ${SDC_LOG}
            mkdir -p ${SDC_CONF}
            exec ${SDC_HOME}/bin/streamsets dc -exec
        else
            exec cat
        fi
    elif [ "$1" = "stop" ]; then
        jps | awk '/BootstrapMain/ {printf "kill -15 %d", $1}' | sh
    elif [ "$1" = "status" ]; then
        jps | awk '/BootstrapMain/ {printf "ps p %d", $1}' | sh | awk '$0 !~ /awk/ {gsub(/ -/, "\n\t-");print}'
    fi
}

main() {
    init
    run "$@"
}


case "$1" in
    start|stop|status)
        main "$@"
        ;;
    restart)
        main "stop"
        main "start"
        ;;
    *)
        die "Usage $(basename "$0") {start|stop|restart|status}"
        ;;
esac
