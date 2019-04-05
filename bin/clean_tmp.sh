#!/bin/bash
#
# 清理历史临时数据

DAY=+10
FILEPATH=${HOME}/$(basename "$0" | awk '{sub(/^.*_/,""); sub(/\..*$/,""); print}')
CMD_LIST=/tmp/cmd_list$$
LOG_FILE=${HOME}/log/clean.log

find ${FILEPATH} -type f -ctime ${DAY} -print | awk '{printf "rm -f %s\n", $1}' >> ${CMD_LIST}
date >> ${LOG_FILE}
cat ${CMD_LIST} >> ${LOG_FILE}
sh ${CMD_LIST}
