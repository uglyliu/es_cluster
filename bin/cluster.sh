#!/bin/bash
#
# 集群管理工具

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

    export CONFIGFILE=${HOME}/conf/supervisor/supervisord.conf
}

run() {
    eval "pssh -h ${SERVRE_LIST} -i \"${HOME}/bin/${COMMAND} ${OPTION} $@\""
}

main() {
    init
    run "$@"
}


if [ $# -eq 0 ]; then
     die "Usage $(basename "$0") -h cluster.list command {init|start|stop|shutdown|restart|status}"
fi

while [ $# -gt 0 ] ;
do
    case "$1" in
        -h) shift
            SERVRE_LIST="$1"
            shift
            ;;
        supervisor.sh|elastalert.sh|elasticsearch_hot.sh|elasticsearch_warm.sh|sdc.sh|filebeat.sh|heartbeat.sh|kibana.sh|metricbeat.sh|packetbeat.sh|sdc_pipeline.sh)
            COMMAND="$1"
            shift
            ;;
        init|start|stop|shutdown|restart|status)
            if [ -s ${SERVRE_LIST} ]; then
                OPTION="$1"
                shift
                main "$@"
            else
                die "Usage $(basename "$0") -h cluster.list command {init|start|stop|shutdown|restart|status}"
            fi
            shift
            ;;
        *)
            die "Usage $(basename "$0") -h cluster.list command {init|start|stop|shutdown|restart|status}"
            shift
            ;;
    esac
done
