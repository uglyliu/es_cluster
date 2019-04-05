#!/bin/bash
# 预生成ES index工具，动态设置shard，设置shard allocation filter
# 仅在唯一胜出的节点执行之

# 初始化相关index
curl -XPUT "http://localhost:9200/leader" >/dev/null 2>&1 -H 'Content-Type: application/json' -d'
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

# 30秒为一轮选举周期
num=$(curl -XGET "http://localhost:9200/leader/_count?pretty" 2>/dev/null -H 'Content-Type: application/json' -d'             
{
    "query": {                  
        "range": {                        
            "date": {
                "gte": "now-30s"
            }
        }
    }
}' | awk '/count/ {gsub(/\"/,""); gsub(/,/,""); print $3}')

#未进行本轮选举，可以进行选举并投票
if [ $num -eq 0 ]
then
    #投票
    curl -XPOST "http://localhost:9200/leader/_doc?pretty" >/dev/null 2>&1 -H 'Content-Type: application/json' -d'{
        "hostname": "'$(hostname)'",
        "date": "'$(date -u +"%FT%T.%3NZ")'",
        "nanoseconds": '$(expr $(date +"%s%N") % 1000000000000)'
    }'

    sleep 10

    #检查投票结果，最早者胜出
    leader=$(curl -XGET "http://localhost:9200/leader/_search?pretty" 2>/dev/null -H 'Content-Type: application/json' -d'                                  
    {
        "query": {
            "range": {
                "date": {
                    "gte": "now-15s"      
                }    
            }  
        },
        "sort": [
            {
                "date": {
                    "order": "desc"
                },
                "nanoseconds": {
                    "order": "desc"
                }
            }
        ],
        "size": 3,
        "_source": "hostname"
    }' | awk '/hostname/ {gsub(/\"/,""); host=$3;} END{print host}')

    #如果获胜，开始发号施令
    if [ "x"${leader} = "x"$(hostname) ]
    then
        for i in $(seq $1 $2)
        do
            curl -XGET "http://localhost:9501/_cat/indices" 2>/dev/null | \
                awk -v date=$(date -d "-${i} days" +"%Y.%m.%d") '
                {
                    if ($1 == "green") {
                        index_name=$3; gsub(/^.*-/,"",$3); sub_date=$3;
                    }
                    if ($1 == "close") {
                        index_name=$2; gsub(/^.*-/,"",$2); sub_date=$2;
                    }
                    if (sub_date ~ /^[0-9]{4}\.[0-9]{2}\.[0-9]{2}$/ && sub_date == date ) {
                        printf "curl -XPUT \"http://localhost:9200/%s/_settings?timeout=5m&pretty\" -H '\''Content-Type: application/json'\'' -d'\''\n", index_name;
                        printf "{\n";
                        printf "\t\"index.routing.allocation.require.box_type\": \"warm\"\n";
                        printf "}'\''\n";
                    }
                }' | sh >> ${HOME}/log/curator/curator.log 2>/dev/null
        done
    fi
fi
