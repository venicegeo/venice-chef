#!/bin/bash

[ -f /etc/profile.d/runtime.sh ] && . /etc/profile.d/runtime.sh
: ${ZK_CFG:=/opt/zookeeper/conf/zoo.cfg}

cd "$(sed -n 's/^dataDir=//p' "$ZK_CFG")/log" || exit $?
find . -mtime +28 -type f -exec 'lsof $0 || rm -f $0' {} \;
