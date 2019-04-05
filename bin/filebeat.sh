#!/bin/bash
#
# Filebeat服务管理工具

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

    export FILEBEAT_HOME=${HOME}/software/filebeat
    export FILEBEAT_PATH_CONF=${HOME}/conf/filebeat
    export FILEBEAT_PATH_DATA=${HOME}/data/filebeat
    export FILEBEAT_PATH_LOG=${HOME}/log/filebeat
    export LOCAL_IP=$(awk -v hostname=${HOSTNAME} '{for (i=2; i<=NF; i++) if ($i == hostname) {print $1}}' /etc/hosts)
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
    }' ${HOME}/conf/filebeat.list)
}

run() {
    if [ "$1" = "start" ]; then
        if check_server ; then
            mkdir -p ${FILEBEAT_PATH_CONF}
            mkdir -p ${FILEBEAT_PATH_DATA}
            mkdir -p ${FILEBEAT_PATH_LOG}
            exec ${FILEBEAT_HOME}/filebeat -E LOCAL_IP=${LOCAL_IP} --path.config ${FILEBEAT_PATH_CONF} --path.data ${FILEBEAT_PATH_DATA} --path.home ${FILEBEAT_HOME} --path.logs ${FILEBEAT_PATH_LOG}
        else
            exec cat
        fi
    elif [ "$1" = "stop" ]; then
        ps -ef | awk '$8 ~ /filebeat$/ {print $2}' | awk '{printf "kill -15 %d", $1}' | sh
    elif [ "$1" = "status" ]; then
        ps p $(ps -ef | awk '$8 ~ /filebeat$/ {print $2}') | awk '$0 !~ /awk/ {gsub(/ -/, "\n\t-");print}'
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
