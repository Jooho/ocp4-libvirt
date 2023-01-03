#!/bin/bash

leftMem=$(free |grep Mem|awk '{print $4}')

while true
do
  if [ $(echo "$leftMem < 3000000"|bc) == 1 ]  # If current memory is under 3G
  then
    echo "Free Memory is under 3G so this script will clean cache to get enough resources"
    sync; sudo echo 1 > /proc/sys/vm/drop_caches;sync; sudo echo 2 > /proc/sys/vm/drop_caches; sync; sudo echo 3 > /proc/sys/vm/drop_caches
  fi
  sleep 20
  leftMem=$(free |grep Mem|awk '{print $4}')
  leftMem_readable=$(free -h |grep Mem|awk '{print $4}')
  echo "Current Memory: $leftMem_readable"

done
