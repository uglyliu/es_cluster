#!/bin/bash
#
# Kafka服务管理工具

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
    export KAFKA_PATH_DATA=${HOME}/data/kafka
    export KAFKA_PATH_LOG=${HOME}/log/kafka
    export KAFKA_LOG4J_OPTS="-Dlog4j.configuration=file:${KAFKA_PATH_CONF}/log4j.properties"
    export KAFKA_HEAP_OPTS="-Xmx512m -Xms512m"
    export ID=`hostname | sed 's/[^0-9]*//g'`
    export LOG_DIR=${KAFKA_PATH_LOG}
    #export KAFKA_OPTS=-javaagent:${HOME}/install/jolokia-1.6.0/jolokia-jvm-1.6.0-agent.jar=port=8778,host=localhost
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
    }' ${HOME}/conf/kafka.list)
}

run() {
    if [ "$1" = "start" ]; then
        if check_server ; then
            sed -i -e 's/broker.id=.*$/broker.id='${ID}'/' ${KAFKA_PATH_CONF}/server.properties
	    mkdir -p ${KAFKA_PATH_CONF}
	    mkdir -p ${KAFKA_PATH_DATA}/kafka-logs
	    mkdir -p ${KAFKA_PATH_LOG}
            exec ${KAFKA_HOME}/bin/kafka-server-start.sh ${KAFKA_PATH_CONF}/server.properties
        else
            exec cat
        fi
    elif [ "$1" = "stop" ]; then
        ps ax | grep -i 'kafka\.Kafka' | grep java | grep -v grep | awk '{print $1}' | awk '{printf "kill -9 %d", $1}' | sh
    elif [ "$1" = "status" ]; then
        ps p $(ps ax | grep -i 'kafka\.Kafka' | grep java | grep -v grep | awk '{print $1}') | awk '$0 !~ /awk/ {gsub(/ -/, "\n\t-");print}'
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
