#!/bin/bash
#
# Zookeeper服务管理工具

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

    export KAFKA_HOME=${HOME}/software/kafka
    export KAFKA_PATH_CONF=${HOME}/conf/kafka
    export ZOOKEEPER_PATH_DATA=${HOME}/data/zookeeper
    export ZOOKEEPER_PATH_LOG=${HOME}/log/zookeeper
    export KAFKA_LOG4J_OPTS="-Dlog4j.configuration=file:${KAFKA_PATH_CONF}/log4j.properties"
    export KAFKA_HEAP_OPTS="-Xmx256m -Xms256m"
    export LOG_DIR=${ZOOKEEPER_PATH_LOG}
    #export KAFKA_OPTS=-javaagent:${HOME}/install/jolokia-1.6.0/jolokia-jvm-1.6.0-agent.jar=port=8779,host=localhost
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
    }' ${HOME}/conf/zookeeper.list)
}

run() {
    if [ "$1" = "start" ]; then
        if check_server ; then
            mkdir -p ${ZOOKEEPER_PATH_DATA}
            mkdir -p ${ZOOKEEPER_PATH_LOG}
            hostname | sed 's/[^0-9]*//g' > ${HOME}/data/zookeeper/myid
            exec ${KAFKA_HOME}/bin/zookeeper-server-start.sh ${KAFKA_PATH_CONF}/zookeeper.properties
        else
            exec cat
        fi
    elif [ "$1" = "stop" ]; then
        ps ax | grep java | grep -i QuorumPeerMain | grep -v grep | awk '{print $1}' | awk '{printf "kill -15 %d", $1}' | sh
    elif [ "$1" = "status" ]; then
        ps p $(ps ax | grep java | grep -i QuorumPeerMain | grep -v grep | awk '{print $1}') | awk '$0 !~ /awk/ {gsub(/ -/, "\n\t-");print}'
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
