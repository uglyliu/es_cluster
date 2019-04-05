#!/bin/bash
#
# 初始化安装本地节点，也可以用于升级操作
# 前提条件
# 1、安装好系统及基本软件，如：supervisor, jdk, pip, python2.7及相关依赖包(curator)
# 2、设置好核心参数
# 3、建立好节点间互信
# 4、准备好配置文件并放置在${HOME}/conf下，分模块目录存放
# 5、将下载好的软件包放置在${HOME}/install下
# 6、由于nginx, elastalert和elastalert-server为定制开发版，因此不能直接自动安装，需手工安装
# 7、对于SDC,kafka,zookeeper,redis集群通常会单独部署，这里仅仅作简单演示，表明同样可以采用本方法进行自动部署

BINPATH=${HOME}/bin
CONFPATH=${HOME}/conf
SOFTPATH=${HOME}/software
INSTALLPATH=${HOME}/install
BACKUPPATH=${HOME}/backup
DATE=$(date +%Y%m%d_%H%M%S)

read -p "Do you confirm to initialize the present node? (Y/N)" confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS]  ]] || exit 1
read -p "Which elasticsearch version will you use? " ESVERSION
read -p "Which elasticsearch curator version will you use? " CURATORVERSION
read -p "Which elastalert kibana plugin version will you use? " PLUGINVERSION
read -p "Which jdk version for elasticsearch will you use? " JDKVERSION
read -p "Which kafka version will you use? " KAFKAVERSION
read -p "Which streamsets data collector version will you use? " SDCVERSION

FILE_ELASTICSEARCH=${INSTALLPATH}/elasticsearch-${ESVERSION}.tar.gz
FILE_KIBANA=${INSTALLPATH}/kibana-${ESVERSION}-linux-x86_64.tar.gz
FILE_METRICBEAT=${INSTALLPATH}/metricbeat-${ESVERSION}-linux-x86_64.tar.gz
FILE_FILEBEAT=${INSTALLPATH}/filebeat-${ESVERSION}-linux-x86_64.tar.gz
FILE_PACKETBEAT=${INSTALLPATH}/packetbeat-${ESVERSION}-linux-x86_64.tar.gz
FILE_HEARTBEAT=${INSTALLPATH}/heartbeat-${ESVERSION}-linux-x86_64.tar.gz
FILE_PLUGIN_IK=${INSTALLPATH}/elasticsearch-analysis-ik-${ESVERSION}.zip
FILE_PLUGIN_KIBANA=${INSTALLPATH}/elastalert-kibana-plugin-${PLUGINVERSION}-${ESVERSION}.zip
FILE_CURATOR=${INSTALLPATH}/v${CURATORVERSION}.tar.gz
FILE_JDK=${INSTALLPATH}/jdk-${JDKVERSION}_linux-x64_bin.tar.gz
FILE_KAFKA=${INSTALLPATH}/kafka_2.11-${KAFKAVERSION}.tgz
FILE_SDC=${INSTALLPATH}/streamsets-datacollector-core-${SDCVERSION}.tgz

[ ${ESVERSION}"x" != "x" ] && [ ! -s ${FILE_ELASTICSEARCH} ] && echo "${FILE_ELASTICSEARCH} is not exist!" && exit 1
[ ${ESVERSION}"x" != "x" ] && [ ! -s ${FILE_KIBANA} ] && echo "${FILE_KIBANA} is not exist!" && exit 1
[ ${ESVERSION}"x" != "x" ] && [ ! -s ${FILE_METRICBEAT} ] && echo "${FILE_METRICBEAT} is not exist!" && exit 1
[ ${ESVERSION}"x" != "x" ] && [ ! -s ${FILE_FILEBEAT} ] && echo "${FILE_FILEBEAT} is not exist!" && exit 1
[ ${ESVERSION}"x" != "x" ] && [ ! -s ${FILE_PACKETBEAT} ] && echo "${FILE_PACKETBEAT} is not exist!" && exit 1
[ ${ESVERSION}"x" != "x" ] && [ ! -s ${FILE_HEARTBEAT} ] && echo "${FILE_HEARTBEAT} is not exist!" && exit 1
[ ${ESVERSION}"x" != "x" ] && [ ! -s ${FILE_PLUGIN_IK} ] && echo "${FILE_PLUGIN_IK} is not exist!" && exit 1
[ ${ESVERSION}"x" != "x" -a ${PLUGINVERSION} != "x" ] && [ ! -s ${FILE_PLUGIN_KIBANA} ] && echo "${FILE_PLUGIN_KIBANA} is not exist!" && exit 1
[ ${CURATORVERSION}"x" != "x" ] && [ ! -s ${FILE_CURATOR} ] && echo "${FILE_CURATOR} is not exist!" && exit 1
[ ${JDKVERSION}"x" != "x" ] && [ ! -s ${FILE_JDK} ] && echo "${FILE_JDK} is not exist!" && exit 1
[ ${KAFKAVERSION}"x" != "x" ] && [ ! -s ${FILE_KAFKA} ] && echo "${FILE_KAFKA} is not exist!" && exit 1
[ ${SDCVERSION}"x" != "x" ] && [ ! -s ${FILE_SDC} ] && echo "${FILE_SDC} is not exist!" && exit 1

if [ $(lsof -nPi :9200 | grep LISTEN | wc -l) -gt 0 ]
then
    curl -XPUT "http://localhost:9200/_all/_settings?pretty" -H 'Content-Type: application/json' -d'
    {"settings":{"index.unassigned.node_left.delayed_timeout":"60m"}}'

    curl -XPUT "http://localhost:9200/_cluster/settings?pretty" -H 'Content-Type: application/json' -d'
    {"persistent":{"cluster":{"routing":{"allocation.enable":"none"}}}}' 

    curl -XPOST "http://localhost:9200/_flush/synced?pretty" 
fi

${BINPATH}/supervisor.sh shutdown
sleep 10

[ -d ${BACKUPPATH}/${DATE} ] && rm -rf ${BACKUPPATH}/${DATE}
mkdir -p ${BACKUPPATH}/${DATE}/conf

cd ${SOFTPATH}

if [ ${ESVERSION}"x" != "x"  ]
then
    mv elasticsearch ${BACKUPPATH}/${DATE}
    tar xvfz ${INSTALLPATH}/elasticsearch-${ESVERSION}.tar.gz
    mv elasticsearch-${ESVERSION} elasticsearch

    mv kibana ${BACKUPPATH}/${DATE}
    tar xvfz ${INSTALLPATH}/kibana-${ESVERSION}-linux-x86_64.tar.gz
    mv kibana-${ESVERSION}-linux-x86_64 kibana

    mv metricbeat ${BACKUPPATH}/${DATE}
    tar xvfz ${INSTALLPATH}/metricbeat-${ESVERSION}-linux-x86_64.tar.gz
    mv metricbeat-${ESVERSION}-linux-x86_64 metricbeat

    cp -r ${CONFPATH}/metricbeat ${BACKUPPATH}/${DATE}/conf
    cp ${SOFTPATH}/metricbeat/fields.yml ${CONFPATH}/metricbeat
    cp -r ${SOFTPATH}/metricbeat/modules.d/ ${CONFPATH}/metricbeat

    mv filebeat ${BACKUPPATH}/${DATE}
    tar xvfz ${INSTALLPATH}/filebeat-${ESVERSION}-linux-x86_64.tar.gz
    mv filebeat-${ESVERSION}-linux-x86_64 filebeat

    cp -r ${CONFPATH}/filebeat ${BACKUPPATH}/${DATE}/conf
    cp ${SOFTPATH}/filebeat/fields.yml ${CONFPATH}/filebeat
    cp -r ${SOFTPATH}/filebeat/modules.d/ ${CONFPATH}/filebeat

    mv packetbeat ${BACKUPPATH}/${DATE}
    tar xvfz ${INSTALLPATH}/packetbeat-${ESVERSION}-linux-x86_64.tar.gz
    mv packetbeat-${ESVERSION}-linux-x86_64 packetbeat

    sudo chown root:root ${SOFTPATH}/packetbeat/packetbeat
    sudo chmod 6755 ${SOFTPATH}/packetbeat/packetbeat
    sudo chown root:root ${CONFPATH}/packetbeat/*.yml
    cp -r ${CONFPATH}/packetbeat ${BACKUPPATH}/${DATE}/conf
    sudo cp ${SOFTPATH}/packetbeat/fields.yml ${CONFPATH}/packetbeat

    mv heartbeat ${BACKUPPATH}/${DATE}
    tar xvfz ${INSTALLPATH}/heartbeat-${ESVERSION}-linux-x86_64.tar.gz
    mv heartbeat-${ESVERSION}-linux-x86_64 heartbeat

    cp -r ${CONFPATH}/heartbeat ${BACKUPPATH}/${DATE}/conf
    cp ${SOFTPATH}/heartbeat/fields.yml ${CONFPATH}/heartbeat
fi

if [ ${CURATORVERSION}"x" != "x" ]
then
    mv curator ${BACKUPPATH}/${DATE}
    tar xvfz ${INSTALLPATH}/v${CURATORVERSION}.tar.gz
    mv curator-${CURATORVERSION} curator
    mkdir -p ${HOME}/data/curator
    mkdir -p ${HOME}/log/curator
fi

if [ ${JDKVERSION}"x" != "x" ]
then
    mv jdk ${BACKUPPATH}/${DATE}
    tar xvfz ${INSTALLPATH}/jdk-${JDKVERSION}_linux-x64_bin.tar.gz
    mv jdk-${JDKVERSION} jdk
fi

if [ ${KAFKAVERSION}"x" != "x" ]
then
    mv kafka ${BACKUPPATH}/${DATE}
    tar xvfz ${INSTALLPATH}/kafka_2.11-${KAFKAVERSION}.tgz
    mv kafka_2.11-${KAFKAVERSION} kafka
fi

if [ ${SDCVERSION}"x" != "x" ]
then
    mv streamsets-datacollector ${BACKUPPATH}/${DATE}
    tar xvfz ${INSTALLPATH}/streamsets-datacollector-core-${SDCVERSION}.tgz
    mv streamsets-datacollector-${SDCVERSION} streamsets-datacollector
fi

if [ ${ESVERSION}"x" != "x"  ]
then
    export ES_TYPE=hot
    export ES_PATH_CONF=${CONFPATH}/elasticsearch/${ES_TYPE}
    ${SOFTPATH}/elasticsearch/bin/elasticsearch-plugin install file://${INSTALLPATH}/elasticsearch-analysis-ik-${ESVERSION}.zip

    if [ ${PLUGINVERSION}"x" != "x"  ]
    then
        ${SOFTPATH}/kibana/bin/kibana-plugin install file://${INSTALLPATH}/elastalert-kibana-plugin-${PLUGINVERSION}-${ESVERSION}.zip
    fi
fi

read -p "Switch to another terminal and to confirm the configuration, then press [y|Y] to continue ... (Y/N)" confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS]  ]] || exit 1

${BINPATH}/supervisor.sh init

while [ $(lsof -nPi :9200 | grep LISTEN | wc -l) -eq 0 ]
do
    sleep 10
done

curl -XPUT "http://localhost:9200/_cluster/settings?pretty" -H 'Content-Type: application/json' -d'
{"persistent":{"cluster":{"routing":{"allocation.enable":null}}}}'          
    
curl -XPUT "http://localhost:9200/_all/_settings?pretty" -H 'Content-Type: application/json' -d'
{"settings":{"index.unassigned.node_left.delayed_timeout":"5m"}}'
