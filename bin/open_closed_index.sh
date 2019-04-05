(for i in $(seq $1)
do
    date -d "-$i days" +"%Y.%m.%d"
done;curl -XGET "http://localhost:9501/_cat/indices" 2>/dev/null) | \
    awk '
    NF == 1 {date[$1]=1;}
    NF > 1 && $1 == "close" {
        index_name=$2; gsub(/^.*-/,"",$2);
        if ($2 ~ /^[0-9]{4}\.[0-9]{2}\.[0-9]{2}$/ && $2 in date )
            printf "curl -XPOST \"http://localhost:9501/%s/_open?pretty\"\n", index_name;
    }'
