#!/bin/bash
#
# Elasticsearch服务管理工具

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

    export JAVA_HOME=${HOME}/software/jdk
    export ES_HOME=${HOME}/software/elasticsearch
    export ES_TYPE=$(echo ${PROGNAME} | awk '{sub(/^.*_/,""); sub(/\..*$/,""); print}')
    export ES_PID=${HOME}/data/elasticsearch/${ES_TYPE}/pid.txt
    export ES_PATH_CONF=${HOME}/conf/elasticsearch/${ES_TYPE}
    export ES_DATADIR=${HOME}/data/elasticsearch/${ES_TYPE}
    export ES_LOGDIR=${HOME}/log/elasticsearch/${ES_TYPE}
    export ES_JAVA_OPTS="-Xms512m -Xmx512m"

    sed -i -e 's%^-XX:HeapDumpPath=.*$%-XX:HeapDumpPath='"${ES_LOGDIR}"'%' \
        -e 's%^8:-Xloggc:.*$%8:-Xloggc:'"${ES_LOGDIR}"'/gc.log%' \
        -e 's%^\(9-.*file=\).*\(\/gc.log.*$\)%\1'"${ES_LOGDIR}"'\2%g' ${ES_PATH_CONF}/jvm.options

    set_config
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
    }' ${HOME}/conf/elasticsearch_${ES_TYPE}.list)
}

set_config() {
    awk -v node_type=${ES_TYPE} -v host=${HOSTNAME} 'BEGIN {
        num=1
        cmd="df"
        while ((cmd | getline) > 0) {
            if (node_type == "hot") {
                if ($6 ~ /ssd/) {
                    ssd[num++]=$6
                }
            } else if (node_type == "warm") {
                if ($6 ~ /disk/) {
                    disk[num++]=$6
                }
            }
        }
    }
    {
        if (FILENAME ~ /.*_master.list$/) {
            master[$1] = 1
        }
        if (FILENAME ~ /.*_data.list$/) {
            data[$1] = 1
        }
        if (FILENAME ~ /.*elasticsearch.yml$/) {
            if (path_flag == 1) {
                if ($0 ~ /[  ]+-/) {
                    next
                } else {
                    path_flag=0
                }
            }
            if (discovery_flag == 1) {
                if ($0 ~ /[  ]+-/) {
                    next
                } else {
                    discovery_flag=0
                }
            }
            if ($0 ~ /^node.master/) {
                if (host in master && node_type == "hot") {
                    print "node.master: true"
                } else {
                    print "node.master: false"
                }
            } else if ($0 ~ /^node.data/) {
                if (host in data) {
                    print "node.data: true"
                } else {
                    print "node.data: false"
                }
#           } else if ($0 ~ /^path.data/) {
#               path_flag=1
#                   print "path.data:"
#                   if (node_type == "hot") {
#                       for (i in ssd) 
#                           printf "    - %s\n", ssd[i]
#                   } else if (node_type == "warm") {
#                       for (i in disk) 
#                           printf "    - %s\n", disk[i]
#                   }
            } else if ($0 ~ /^discovery.zen.ping.unicast.hosts/) {
                discovery_flag=1
                    print "discovery.zen.ping.unicast.hosts:"
                    for (i in master) 
                        printf "    - %s\n", i
            } else {
                print
            }
        }
    }' ${HOME}/conf/elasticsearch_master.list ${HOME}/conf/elasticsearch_data.list ${ES_PATH_CONF}/elasticsearch.yml > /tmp/es_tmp_config$$
    mv /tmp/es_tmp_config$$ ${ES_PATH_CONF}/elasticsearch.yml
}

run() {
    if [ "$1" = "start" ]; then
        if check_server ; then
            ESSTATUS="401"
            #确保在并行启动时不会出现竞争,9200端口肯定由hot节点启动
            while [ ${ESSTATUS} = "401" ]
            do
                sleep 10
                ESSTATUS=$(curl -GET "localhost:9200/_cluster/health?pretty" 2>/dev/null | \
                    awk -F":" 'BEGIN{status="401"} {gsub(/[\" ,]/,""); if ( $1 == "status" ) status=$2;} END{print status}')
            done
            mkdir -p ${ES_PATH_CONF}
            mkdir -p ${ES_DATADIR}
            mkdir -p ${ES_LOGDIR}
            exec ${ES_HOME}/bin/elasticsearch -p ${ES_PID} -Enode.attr.box_type=${ES_TYPE}
        else
            exec cat
        fi
    elif [ "$1" = "stop" ]; then
        cat ${ES_PID} | awk '{printf "kill -15 %d", $1}' | sh
    elif [ "$1" = "status" ]; then
        ps p $(cat ${ES_PID}) | awk '$0 !~ /awk/ {gsub(/ -/, "\n\t-");print}'
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
