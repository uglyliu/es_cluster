#!/bin/bash
#
# Kibana服务管理工具

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

    export KIBANA_HOME=${HOME}/software/kibana
    export KIBANA_PATH_CONF=${HOME}/conf/kibana
    export KIBANA_PATH_DATA=${HOME}/data/kibana
    export KIBANA_PATH_LOG=${HOME}/log/kibana
    export KIBANA_PID=${KIBANA_PATH_DATA}/pid.txt
    export CONFIG_PATH=${KIBANA_PATH_CONF}/kibana.yml

#   sed -i 's%^server.host:.*$%server.host: \"'"${HOSTNAME}"'\"%' ${CONFIG_PATH}
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
    }' ${HOME}/conf/kibana.list)
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
            mkdir -p ${KIBANA_PATH_CONF}
            mkdir -p ${KIBANA_PATH_DATA}
            mkdir -p ${KIBANA_PATH_LOG}
            exec ${KIBANA_HOME}/bin/kibana
        else
            exec cat
        fi
    elif [ "$1" = "stop" ]; then
        cat ${KIBANA_PID} | awk '{printf "kill -15 %d", $1}' | sh
    elif [ "$1" = "status" ]; then
        ps p $(cat ${KIBANA_PID}) | awk '$0 !~ /awk/ {gsub(/ -/, "\n\t-");print}'
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
