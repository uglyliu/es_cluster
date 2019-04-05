#!/bin/bash
#
# Nginx鏈嶅姟绠＄悊宸ュ叿

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

    export NGINX_HOME=${HOME}/software/nginx
    export NGINX_PATH_CONF=${HOME}/conf/nginx
    export NGINX_PATH_DATA=${HOME}/data/nginx
    export NGINX_PATH_LOG=${HOME}/log/nginx
    export NGINX_PID=${NGINX_PATH_DATA}/nginx.pid
    export CONFIG_PATH=${NGINX_PATH_CONF}/nginx.conf
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
    }' ${HOME}/conf/nginx.list)
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
            mkdir -p ${NGINX_PATH_CONF}
            mkdir -p ${NGINX_PATH_DATA}
            mkdir -p ${NGINX_PATH_LOG}
            exec ${NGINX_HOME}/nginx/sbin/nginx -c ${CONFIG_PATH}
        else
            exec cat
        fi
    elif [ "$1" = "stop" -o "$1" = "reload" ]; then
        exec ${NGINX_HOME}/nginx/sbin/nginx -c ${CONFIG_PATH} -s $1
    elif [ "$1" = "status" ]; then
        ps p $(cat ${NGINX_PID}) | awk '$0 !~ /awk/ {gsub(/ -/, "\n\t-");print}'
    fi
}

main() {
    init
    run "$@"
}


case "$1" in
    start|stop|status|reload)
        main "$@"
        ;;
    restart)
        main "stop"
        main "start"
        ;;
    *)
        die "Usage $(basename "$0") {start|stop|restart|status|reload}"
        ;;
esac
