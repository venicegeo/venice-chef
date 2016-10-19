#!/bin/bash -e

[ -f /etc/profile.d/runtime.sh ] && . /etc/profile.d/runtime.sh

[ -z "$AWS_EFS_ID" ] && echo "AWS_EFS_ID not set" 2>&1 && exit 1

ec2az=$(curl http://169.254.169.254/latest/meta-data/placement/availability-zone)

mount -t nfs4 -o nfsvers=4.1 ${ec2az}.${AWS_EFS_ID}.efs.${AWS_DEFAULT_REGION}.amazonaws.com:/ ${EFS_MOUNT_POINT}
