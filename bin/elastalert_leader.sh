#!/bin/bash
#
# 每分钟进行一轮检测，检查3分钟之内是否有leader存在，如果没有开始新一轮选举，
# 如果有是否与自己一致，如果不一致则停止自身服务
# 如果一致则插入新的心跳数据,如果进程异常终止则启动之
# vote:1 投票所用；vote:0 心跳所用

# 初始化相关index
curl -XPUT "http://localhost:9200/elastalert_leader" >/dev/null 2>&1 -H 'Content-Type: application/json' -d'
{
    "settings": {
        "index": {
            "routing.allocation.require.box_type": "hot",
            "codec": "best_compression",
            "refresh_interval": "1s",
            "number_of_shards": 1,
            "number_of_replicas": 1
        }
    }
}'

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

BINPATH=${HOME}/bin

if check_server ; then
    while :
    do
        list=$(curl -XGET "http://localhost:9200/elastalert_leader/_search?pretty" 2>/dev/null -H 'Content-Type: application/json' -d'{"query":{"bool":{"must":[{"term":{"vote":{"value":0}}},{"range":{"date":{"gte":"now-3m"}}}]}},"sort":[{"date":{"order":"desc"},"nanoseconds":{"order":"desc"}}]}' | awk '/hostname/ {gsub(/\"/,""); gsub(/,/,""); print $3;}')

        if [ -z "${list}" ]
        then
            #投票
            curl -XPOST "http://localhost:9200/elastalert_leader/_doc?pretty" >/dev/null 2>&1 -H 'Content-Type: application/json' -d'{
                "hostname": "'$(hostname)'",
                "date": "'$(date -u +"%FT%T.%3NZ")'",
                "nanoseconds": '$(expr $(date +"%s%N") % 1000000000000)',
                "vote": 1
            }'

            sleep 10

            #检查投票结果，最早者胜出
            leader=$(curl -XGET "http://localhost:9200/elastalert_leader/_search?pretty" 2>/dev/null -H 'Content-Type: application/json' -d'{"query":{"bool":{"must":[{"term":{"vote":{"value":1}}},{"range":{"date":{"gte":"now-15s"}}}]}},"sort":[{"date":{"order":"desc"},"nanoseconds":{"order":"desc"}}],"size":3,"_source":"hostname"}' | awk '/hostname/ {gsub(/\"/,""); host=$3;} END{print host}')

            #如果获胜，开始发号施令
            if [ "x"${leader} = "x"$(hostname) ]
            then
                nohup ${BINPATH}/elastalert.sh start >> ${HOME}/log/elastalert/elastalert.log &
                curl -XPOST "http://localhost:9200/elastalert_leader/_doc?pretty" >/dev/null 2>&1 -H 'Content-Type: application/json' -d'{
                    "hostname": "'$(hostname)'",
                    "date": "'$(date -u +"%FT%T.%3NZ")'",
                    "nanoseconds": '$(expr $(date +"%s%N") % 1000000000000)',
                    "vote": 0
                }'
            fi
        else
            stopflag=0
            for i in ${list}
            do
                #如果发现非自身为主的信息，将进行自我清理
                if [ "x"$i != "x"$(hostname) ]
                then
                    ${BINPATH}/elastalert.sh stop
                    stopflag=1
                    break
                fi
            done

            if [ $stopflag -eq 0 ]
            then
                if [ "x"$i = "x"$(hostname) ]
                then
                    curl -i localhost:3030 >/dev/null 2>&1
                    if [ $? -ne 0 ]
                    then
                        ${BINPATH}/elastalert.sh stop
                        ${BINPATH}/elastalert.sh start & 
                    fi

                    curl -XPOST "http://localhost:9200/elastalert_leader/_doc?pretty" >/dev/null 2>&1 -H 'Content-Type: application/json' -d'{
                        "hostname": "'$(hostname)'",
                        "date": "'$(date -u +"%FT%T.%3NZ")'",
                        "nanoseconds": '$(expr $(date +"%s%N") % 1000000000000)',
                        "vote": 0
                    }'
                fi
            fi
        fi

        sleep 60
    done
else
    exec cat
fi
