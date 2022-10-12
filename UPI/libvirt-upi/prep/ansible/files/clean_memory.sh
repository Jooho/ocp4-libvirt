#!/bin/bash

leftMem=$(free -h |grep Mem|awk '{print $4}'|sed 's/Gi//g')

while true
do
  if [ $(echo "$leftMem > 3.0"|bc) != 1 ]
  then
    echo "Free Memory is under 3G so this script will clean cache to get enough resources"
    sync; sudo echo 1 > /proc/sys/vm/drop_caches;sync; sudo echo 2 > /proc/sys/vm/drop_caches; sync; sudo echo 3 > /proc/sys/vm/drop_caches
  fi
  sleep 20
  leftMem=$(free -h |grep Mem|awk '{print $4}'|sed 's/Gi//g')
  echo "Current Memory: $leftMem Gi"

done