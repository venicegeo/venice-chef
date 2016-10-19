#!/bin/bash

[ -f /etc/profile.d/runtime.sh ] && . /etc/profile.d/runtime.sh

echo "Waiting for EBS mounts to become available"
while [ ! -e /dev/xvdf ]; do echo waiting for /dev/sdf to attach; sleep 10; done
while [ ! -e /dev/xvdg ]; do echo waiting for /dev/sdg to attach; sleep 10; done

echo "preparing EBS volumes"

mdadm --verbose --create /dev/md0 --level=mirror --raid-devices=2 --run /dev/xvdf /dev/xvdg > /tmp/mdadm.log 2>&1
mdadm --detail --scan > /etc/mdadm.conf

mkdir -p /media/p_iops_vol0
mkfs.ext4 /dev/md0
echo '/dev/md0 /media/p_iops_vol0 ext4 defaults,noatime 0 0' | tee -a /etc/fstab

echo "mounting EBS volumes"
mount /media/p_iops_vol0 > /tmp/mount_piops.log 2>&1

mkdir -p /media/p_iops_vol0/kafka-logs
chown kafka:kafka /media/p_iops_vol0/kafka-logs

echo "Specifying zookeeper nodes"
[ -z "$ZK_IP_POOL" ] && { echo "$0: ZK_IP_POOL not defined" 2>&1; exit 1; }

zk_ips=$(echo "$ZK_IP_POOL" | sed -e 's/[\[u ]//g' -e 's/]//g' -e "s/'//g")

conf=/usr/local/kafka/config/server.properties
eth1ip=$(ifconfig eth1 | grep inet | awk '{print $2}')

[ -z "$eth1ip" ] && { echo "$0: static ip not detected" 2>&1; exit 1; }

zk=
IFS=","
sep=
for ip in $zk_ips; do
  zk="${zk}${sep}${ip}:2181"
  sep=","
done

sed -i "s/zookeeper.connect=localhost:2181/zookeeper.connect=$zk/" $conf
sed -i "s/\/\/:9092/\/\/$eth1ip:9092/" $conf
sed -i 's/log.dirs=.*/log.dirs=\/media\/p_iops_vol0\/kafka-logs/' $conf

echo advertised.host=$eth1ip >> $conf
echo advertised.host.name=$eth1ip >> $conf
