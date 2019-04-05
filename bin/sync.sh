#!/bin/bash
#
#将主节点的程序,配置同步到其他节点,从而实现自动部署,自动升级
#在ES集群同步过程中检查被同步接点的状态,在被同步节点状态正常的情况下继续后续节点的同步

sync_sdc_pipeline()
{
    for i in $(cat ${HOME}/conf/cluster.list | grep -v $(hostname))
    do
        echo "Shutdown sdc on "$i" ..."
        pssh -H $i -i "${HOME}/bin/supervisor.sh stop sdc"
        echo "Synchronizing sdc_pipeline to "$i" ..."
        pssh -H $i -i "rm -rf ${HOME}/data/sdc"
        rsync -az ${HOME}/data/sdc $i:${HOME}/data
        echo "Start sdc on "$i" ..."
        pssh -H $i -i "${HOME}/bin/supervisor.sh start sdc"
    done
}

sync_nginx()
{
    for i in $(cat ${HOME}/conf/cluster.list | grep -v $(hostname))
    do
        echo "Synchronizing nginx to "$i" ..."
        rsync -az ${HOME}/conf/nginx/authorize.lua $i:${HOME}/conf/nginx
        rsync -az ${HOME}/conf/nginx/nginx.conf $i:${HOME}/conf/nginx
        rsync -az ${HOME}/conf/nginx/es_passwords $i:${HOME}/conf/nginx
        rsync -az ${HOME}/conf/nginx/kibana_passwords $i:${HOME}/conf/nginx
        echo "Reload nginx on "$i" ..."
        pssh -H $i -i "${HOME}/bin/nginx.sh reload"
    done
}

sync_elastalert()
{
    for i in $(cat ${HOME}/conf/cluster.list | grep -v $(hostname))
    do
        echo "Shutdown elastalert on "$i" ..."
        pssh -H $i -i "${HOME}/bin/supervisor.sh stop elastalert_leader"
        echo "Synchronizing elastalert to "$i" ..."
        pssh -H $i -i "rm -rf ${HOME}/conf/elastalert"
        rsync -raz ${HOME}/conf/elastalert $i:${HOME}/conf
        pssh -H $i -i "rm -rf ${HOME}/conf/elastalert-server"
        rsync -raz ${HOME}/conf/elastalert-server $i:${HOME}/conf
        echo "Start elastalert on "$i" ..."
        pssh -H $i -i "${HOME}/bin/supervisor.sh start elastalert_leader"
    done
}

sync_curator()
{
    for i in $(cat ${HOME}/conf/cluster.list | grep -v $(hostname))
    do
        echo "Synchronizing curator to "$i" ..."
        rsync -az ${HOME}/conf/curator/curator_action.yml $i:${HOME}/conf/curator
        rsync -az ${HOME}/conf/curator/curator.yml $i:${HOME}/conf/curator
    done
}

sync_upgrade()
{
    synclist=".bashrc .vim* bin conf data/sdc install software"

    echo "Waiting for sync all services in cluster ..."
    sleep 30

    for i in $(cat ${HOME}/conf/cluster.list | grep -v $(hostname))
    do
        curl -XPUT "http://localhost:9200/_all/_settings?pretty" -H 'Content-Type: application/json' -d'
        {"settings":{"index.unassigned.node_left.delayed_timeout":"60m"}}'

        if [ "x"${flag} = "xupgrade" ]
        then
            curl -XPUT "http://localhost:9200/_cluster/settings" -H 'Content-Type: application/json' -d'
            {"persistent":{"cluster":{"routing":{"allocation.enable":"none"}}}}' >/dev/null 2>&1
        fi

        curl -XPOST "http://localhost:9200/_flush/synced" >/dev/null 2>&1

        echo "Shutdown service on "$i" ..."
        pssh -H $i -i "${HOME}/bin/supervisor.sh shutdown"

        sleep 30

	pssh -H $i -i "sudo chown $(id -un):$(id -gn) ${HOME}/software/packetbeat/packetbeat"
	pssh -H $i -i "sudo chown $(id -un):$(id -gn) ${HOME}/conf/packetbeat/*.yml"

        for j in $synclist
        do
            echo "Synchronizing "$j" to "$i" ..."
            pssh -H $i mkdir -p $(dirname $j)
            #For upgrade
            if [ "x"${flag} = "xupgrade" ]
            then
                if [ "x"$j = "xsoftware" -o "x"$j = "xdata/sdc" ]
                then
                    pssh -H $i -i "rm -rf ${HOME}/$j"
                fi
            fi
            rsync -az ${HOME}/$j $i:${HOME}/$(dirname $j)
        done

        pssh -H $i -i "sed -i -e 's/BUSELK./'$i'/g' ${HOME}/conf/heartbeat/heartbeat.yml ${HOME}/conf/kibana/kibana.yml"
        pssh -H $i -i "sudo chown root:root ${HOME}/software/packetbeat/packetbeat"
        pssh -H $i -i "sudo chmod 6755 ${HOME}/software/packetbeat/packetbeat"
        pssh -H $i -i "sudo chown root:root ${HOME}/conf/packetbeat/*.yml"
        pssh -H $i -i "mkdir -p ${HOME}/data/curator ${HOME}/log/curator"

        echo "Startup service on "$i" ..."
        pssh -H $i -i "${HOME}/bin/supervisor.sh init"

        if [ "x"${flag} = "xupgrade" ]
        then
            curl -XPUT "http://localhost:9200/_cluster/settings" -H 'Content-Type: application/json' -d'
            {"persistent":{"cluster":{"routing":{"allocation.enable":null}}}}' >/dev/null 2>&1
        fi

        curl -XPUT "http://localhost:9200/_all/_settings?pretty" -H 'Content-Type: application/json' -d'
        {"settings":{"index.unassigned.node_left.delayed_timeout":"5m"}}'

        ESSTATUS="red"
        #For upgrade
        if [ "x"${flag} = "xupgrade" ]
        then
            while [ ${ESSTATUS} = "red" ]
            do
                sleep 10
                ESSTATUS=$(pssh -H $i -i "curl -GET \"localhost:9200/_cluster/health?pretty\" 2>/dev/null" | awk -F":" 'BEGIN{status="red"} {gsub(/[\" ,]/,""); if ( $1 == "status"  ) status=$2;} END{print status}')
            done
        else
            while [ ${ESSTATUS} != "green" ]
            do
                sleep 10
                ESSTATUS=$(pssh -H $i -i "curl -GET \"localhost:9200/_cluster/health?pretty\" 2>/dev/null" | awk -F":" 'BEGIN{status="red"} {gsub(/[\" ,]/,""); if ( $1 == "status"  ) status=$2;} END{print status}')
            done
        fi

    done
}

case "$1" in
    sdc_pipeline)
        sync_sdc_pipeline
        ;;
    nginx)
        sync_nginx
        ;;
    elastalert)
        sync_elastalert
        ;;
    curator)
        sync_curator
        ;;
    upgrade)
        flag="upgrade"
        sync_upgrade
        ;;
    services)
        flag="services"
        sync_upgrade
        ;;
    *)
        echo "Usage $(basename "$0") {sdc_pipeline|nginx|elastalert|curator|upgrade|services}"
        ;;
esac
