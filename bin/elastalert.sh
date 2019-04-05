#!/bin/bash
#
# Elastalert服务管理工具

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

    export ELASTALERT_SERVER_HOME=${HOME}/software/elastalert-server
    export ELASTALERT_PATH_CONF=${HOME}/conf/elastalert
    export ELASTALERT_PATH_DATA=${HOME}/data/elastalert
    export ELASTALERT_PATH_LOG=${HOME}/log/elastalert
    export NODE_PATH=${ELASTALERT_SERVER_HOME}
    export BABEL_DISABLE_CACHE=1
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
    }' ${HOME}/conf/elastalert.list)
}

run() {
    if [ "$1" = "start" ]; then
        if check_server ; then
            ESSTATUS="red"
            while [ ${ESSTATUS} = "red" -o ${ESSTATUS} = "yellow" -o ${ESSTATUS} = "401" ]
            do
                sleep 10
                ESSTATUS=$(curl -GET "localhost:9200/_cluster/health?pretty" 2>/dev/null | \
                    awk -F":" 'BEGIN{status="red"} {gsub(/[\" ,]/,""); if ( $1 == "status" ) status=$2;} END{print status}')
            done
            mkdir -p ${ELASTALERT_PATH_CONF}
            mkdir -p ${ELASTALERT_PATH_DATA}
            mkdir -p ${ELASTALERT_PATH_LOG}
            cd ${SOFT_HOME}
            exec ${HOME}/software/kibana/node/bin/node ${ELASTALERT_SERVER_HOME}/index.js | tee ${ELASTALERT_PATH_LOG}/elastalert.log | cat
        else
            exec cat
        fi
    elif [ "$1" = "stop" ]; then
        ps -ef | awk '/[\/]elastalert[^_]/{printf "kill -9 %d\n", $2}' | sh
    elif [ "$1" = "status" ]; then
        ps -ef | awk '/elastalert.sh.*start$/{printf "pstree %d -p\n", $2}' | sh
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
