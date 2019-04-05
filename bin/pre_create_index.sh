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
        TMP_FILE=/tmp/tmp_file$$
        CURLOG=${HOME}/log/curator/curator.log
        curl -XGET "http://localhost:9200/_cat/indices?h=index,docs.count,pri,pri.store.size&bytes=kb" 2>/dev/null | grep $(date -d "0 days" +"%Y.%m.%d") | sort -nr -k 4 |\
            awk -v DATE1=$(date +"%Y.%m.%d") -v DATE2=$(date -d "+1 days" +"%Y.%m.%d") \
            '$1 ~ /^[^\.].*/ {
                sub(DATE1, DATE2, $1);
                numshards=$4/20480000;
                ssds=20;
                #对于大索引要根据磁盘数量进行分配，尽可能平衡IO
                if ( $4 > 5120000 || $1 ~ /k-onplat/ ) {
                    numshards=(1+int(numshards/ssds))*ssds;
                }
                if ( int(numshards) == 0 ) numshards=1;
                printf "curl -XDELETE \"http://localhost:9200/%s?pretty\" -H '\''Content-Type: application/json'\'' \n", $1;
                printf "curl -XPUT \"http://localhost:9200/%s?pretty\" -H '\''Content-Type: application/json'\'' -d'\''\n", $1;
                printf "{\n\t\"settings\": {\n\t\t\"index\": {\n";
                printf "\t\t\t\"routing.allocation.require.box_type\": \"hot\",\n";
                printf "\t\t\t\"codec\": \"best_compression\",\n";
                printf "\t\t\t\"refresh_interval\": \"60s\",\n";
                printf "\t\t\t\"translog.durability\": \"async\",\n";
                printf "\t\t\t\"number_of_shards\": %d,\n", numshards;
                printf "\t\t\t\"number_of_replicas\": 1\n";
                printf "\t\t}\n\t}\n}'\''\n";
            }' | tee ${TMP_FILE} | sh
        date >> ${CURLOG}
        cat ${TMP_FILE} >> ${CURLOG}
        >${TMP_FILE}
        date >> ${CURLOG}
    fi
fi
