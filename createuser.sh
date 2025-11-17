#!/usr/bin/bash

#
# create unix account with passwd
#
for i in $(seq 1 15)
do
  echo creating <user>$i
  sudo useradd -m <user>$i && echo "<user>$i:<change-passwd>$i" | sudo chpasswd
done

#
# create vncpasswd
#
for i in $(seq 1 15)
do
  echo setting vncpasswd for labuser$i
  mkdir /home/labuser$i/.vnc
  echo <user>$i | vncpasswd -f > /home/<user>$i/.vnc/passwd
  chown -R <user>$i:<user>$i /home/<user>$i/.vnc
  chmod 0600 /home/<user>$i/.vnc/passwd
done

#
# enable systemd
#
for i in $(seq 1 15)
do
  echo enabling systemd $ID
  sudo cp /lib/systemd/system/vncserver@.service /etc/systemd/system/vncserver@:$i.service
done

sudo systemctl daemon-reload

for i in $(seq 1 15)
do
  echo starting systemd $i
  sudo systemctl start vncserver@:$i.service
done

