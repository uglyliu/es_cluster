#!/bin/bash
#
# 本地节点服务管理工具

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

    export SUPERVISOR_PATH_CONF=${HOME}/conf/supervisor
    export SUPERVISOR_PATH_DATA=${HOME}/data/supervisor
    export SUPERVISOR_PATH_LOG=${HOME}/log/supervisor
    export CONFIGFILE=${SUPERVISOR_PATH_CONF}/supervisord.conf
}

run() {
    init_cmd="supervisord -c ${CONFIGFILE}"
    ctl_cmd="supervisorctl -c ${CONFIGFILE} $@"

    mkdir -p ${SUPERVISOR_PATH_CONF}
    mkdir -p ${SUPERVISOR_PATH_DATA}
    mkdir -p ${SUPERVISOR_PATH_LOG}
    if [ "$1" = "init" ]; then
        eval "${init_cmd}"
    else
        eval "${ctl_cmd}"
    fi
}

main() {
    init
    run "$@"
}


case "$1" in
    init|start|stop|shutdown|restart|status)
        main "$@"
        ;;
    *)
        die "Usage $(basename "$0") {init|start|stop|shutdown|restart|status}"
        ;;
esac
