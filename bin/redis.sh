#!/bin/bash
#
# Redis服务管理工具

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

    export REDIS_HOME=${HOME}/software/redis
    export REDIS_PATH_CONF=${HOME}/conf/redis
    export REDIS_PATH_DATA=${HOME}/data/redis
    export REDIS_PATH_LOG=${HOME}/log/redis
    export REDIS_PID=${REDIS_PATH_DATA}/redis_6379.pid
    export CONFIG_PATH=${REDIS_PATH_CONF}/redis.conf
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
    }' ${HOME}/conf/redis.list)
}

run() {
    if [ "$1" = "start" ]; then
        if check_server ; then
            mkdir -p ${REDIS_PATH_CONF}
            mkdir -p ${REDIS_PATH_DATA}
            mkdir -p ${REDIS_PATH_LOG}
            exec ${REDIS_HOME}/src/redis-server ${CONFIG_PATH}
        else
            exec cat
        fi
    elif [ "$1" = "stop" ]; then
        cat ${REDIS_PID} | awk '{printf "kill -15 %d", $1}' | sh
    elif [ "$1" = "status" ]; then
        ps p $(cat ${REDIS_PID}) | awk '$0 !~ /awk/ {gsub(/ -/, "\n\t-");print}'
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
