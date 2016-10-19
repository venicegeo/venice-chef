#!/bin/bash -e

[ -f /etc/profile.d/runtime.sh ] && . /etc/profile.d/runtime.sh

[ -z "$IP_POOL" ] && echo "IP_POOL not set" 2>&1 && exit 1

: ${IP_PREFIX:=19}

function attachmentStatus {
  [ -z "$1" ] && echo "$0: must specify ENI ID." 2>&1 && exit 1

  aws ec2 describe-network-interface-attribute --network-interface-id $1 \
        --attribute attachment --query Attachment.Status --output text
}

echo "Searching for ENI in $IP_POOL"

IFS=","
for ip in $IP_POOL; do

  # find desired ENI
  eni=$(aws ec2 describe-network-interfaces --output text \
        --query "NetworkInterfaces[?PrivateIpAddress==\`$ip\`].NetworkInterfaceId")
  eniip=$(aws ec2 describe-network-interfaces --output text \
        --query "NetworkInterfaces[?NetworkInterfaceId==\`$eni\`].PrivateIpAddress")
  enistatus=$(attachmentStatus $eni)

  [ "z$ip" != "z$eniip" ] && continue
  [ "z$enistatus" != zNone ] && continue

  # verify subnet match
  instance=$(curl http://169.254.169.254/latest/meta-data/instance-id/)
  ec2sub=$(aws ec2 describe-instances --instance-ids $instance --output text \
      --query Reservations[0].Instances[0].SubnetId)
  enisub=$(aws ec2 describe-network-interfaces --output text \
        --query "NetworkInterfaces[?NetworkInterfaceId==\`$eni\`].SubnetId")

  [ "z$ec2sub" != "z$enisub" ] && continue

  # attach ENI
  echo "attaching $eni"

  subnet=$(ipcalc --network $ip/$IP_PREFIX | sed 's/^NETWORK=//')
  netmask=$(ipcalc --netmask $ip/$IP_PREFIX | sed 's/^NETMASK=//')
  gateway=$(route -n | grep ^0\.0\.0\.0 | awk '{print $2}')


  aws ec2 attach-network-interface \
        --instance-id $instance \
        --network-interface-id $eni \
        --device-index 1 \
        --output text

  echo "waiting for attachment..."
  while [ "z$(attachmentStatus $eni)" != zattached ]; do sleep 5; done

  # configure eth1
  echo "configuring interface..."
  cat << EOF > /etc/sysconfig/network-scripts/ifcfg-eth1
DEVICE=eth1
BOOTPROTO=static
ONBOOT=yes
TYPE=Ethernet
USERCTL=yes
PEERDNS=yes
IPV6INIT=no
IPADDR=$ip
NETMASK=$netmask
EOF

  # turn it on
  echo "booting interface..."
  ifup eth1

  # add routes
  echo "configuring network..."
  ip route add $subnet dev eth1 proto kernel scope link src $ip table 1
  ip route add default via $gateway dev eth1 table 1
  ip rule add from $ip lookup 1

  eth1ip=$(ifconfig eth1 | grep inet | awk '{print $2}')
  [ "z$eth1ip"  = "z$ip" ] \
    && { echo "attachment succeded."; exit 0; } \
    || { echo "attachment failed: ip mismatch" 2>&1; exit 1; }

done

echo "attachment failed: no ENI found?" 2>&1
exit 1
