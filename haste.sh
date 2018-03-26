#!/bin/bash
# If necessary
# while read line; do echo ${TIMESTYLE} ":" ${line}; done;
# No centos killall n funfa, pkill -f deve ser usado
LOG="/var/log/memmanager"
TIMESTYLE="$(date +'%Y-%m-%d %H:%M:%S')"

while true; do

  # Get available memory with free in standart kilobytes
  MEMAV=$(free | awk 'FNR == 2 {print $7}' | grep -E [[:digit:]])
  # Convert output to megabytes
  MEMAVMB=$(( ${MEMAV} / 1024 ))

  if [[ ${MEMAV} -lt 250000 ]]; then

    # For future, add check if chrome exists, after, add check to close another mem suckers
    killall chrome
    echo "${TIMESTYLE} : There is no free memory available for continue to working." >> ${LOG} 2>&1
    echo "${TIMESTYLE} : The available amount of memory is ${MEMAVMB}MB" >> ${LOG} 2>&1
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
