#!/bin/bash
# If necessary
# while read line; do echo ${TIMESTYLE} ":" ${line}; done;
# No centos killall n funfa, pkill -f deve ser usado
LOG="/var/log/memmanager"
TIMESTYLE="$(date +'%Y-%m-%d %H:%M:%S')"

while true; do

  MEMAV=$(free | awk 'FNR == 2 {print $7}' | grep -E [[:digit:]])
  
  if [[ ${MEMAV} -lt 400000 ]]; then

    killall chrome
    echo "${TIMESTYLE} : There is no free memory available for continue to working."
    echo "${TIMESTYLE} : The available amount of memory is ${MEMAV}"
    echo "${TIMESTYLE} : The chrome process will now be closed" >> ${LOG} 2>&1

    # To free pagecache:
    echo 1 > /proc/sys/vm/drop_caches
    # To free dentries and inodes:
    echo 2 > /proc/sys/vm/drop_caches
    # To free pagecache, dentries and inodes:
    echo 3 > /proc/sys/vm/drop_caches

 fi

 sleep 3

done
