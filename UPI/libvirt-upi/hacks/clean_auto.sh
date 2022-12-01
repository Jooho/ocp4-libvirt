#!/bin/bash

for i in $(ps -ef|grep custom-update.sh|awk '{print $2}')
do 
  sudo kill -9 $i
done

for i in $(ps -ef|grep clean_memory.sh|awk '{print $2}')
do 
  sudo kill -9 $i
done 