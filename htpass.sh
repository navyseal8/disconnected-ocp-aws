#!/usr/bin/bash

#
# create htpasswd 
#
for i in $(seq 1 15)
do
  if [ $i == 1 ]
  then
    # creating first user on htpass
    htpasswd -c -B -b disco.htpasswd <user>$i <change-passwd>$i
  else
    # appending
    htpasswd -B -b disco.htpasswd <user>$i <change-passwd>$i
  fi
done

