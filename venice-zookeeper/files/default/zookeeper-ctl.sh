#!/bin/bash

[ -f /etc/profile.d/runtime.sh ] && . /etc/profile.d/runtime.sh

: ${ZK_SNAP:=zk-data-snap.tgz}
: ${IP_CACHE:=/var/tmp/zk_ip_addrs}

# export data-dir from config dir
export ZK_DATA_DIR="$(sed -n 's/^dataDir=//p' /etc/zookeeper.d/*.cfg | tail -n 1)"
export ZK_DIR=/opt/zookeeper
export ZOO_LOG_DIR="/var/log/zookeeper"
export ZOO_LOG4J_PROP="INFO,ROLLINGFILE"

start_zk() {

  # if we're already running, bail out
  [ "$(echo ruok | nc -w 10 localhost 2181)" = 'imok' ] && return

  # don't do anything if a data directory is not defined
  [ -n "$ZK_DATA_DIR" ] || return 1

  # populate data dir if it's empty
  mkdir -p $ZK_DATA_DIR
  cd "$ZK_DATA_DIR" || return $?
  if [ ! -d "$ZK_DATA_DIR/version-2" ]; then

    if [ -n "$S3_PATH" ]; then
      # pull lastest backup
      tmpfile="$(mktemp)"
      aws s3 cp "s3://$S3_PATH/last" "$tmpfile" && \
        aws s3 ls "$(cat $tmpfile)" > /dev/null 2>&1 && \
        aws s3 cp "$(cat $tmpfile)" "$ZK_SNAP"
      rm -f $tmpfile
    fi

    [ -f "$ZK_SNAP" ] && { tar -xzf "$ZK_SNAP"; rm -f "$ZK_SNAP"; }
    mkdir -m755 -p "$ZOO_LOG_DIR"
    chown -R root:root ./
  fi

  # make sure myid is set correctly
  if [ -n "$IP_POOL" ]; then
    eth1ip=$(ifconfig eth1 | grep inet | awk '{print $2}')
    i=0
    echo -n > /etc/zookeeper.d/99-ip-mapping.cfg
    IFS=","
    for ip in $IP_POOL; do
      i=$(($i+1))
      [ "$ip" = "$eth1ip" ] && echo $i > "$ZK_DATA_DIR/myid"
      echo "server.$i=$ip:2888:3888" >> /etc/zookeeper.d/99-ip-mapping.cfg
    done
  fi

  cat /etc/zookeeper.d/*.cfg > $ZK_DIR/conf/zoo.cfg

  # set Xmx to 80% free mem and export server options
  [ "$(uname -s)" = 'Linux' ] && XMX="-Xmx$((`sed -rn 's/^MemTotal:\s+([0-9]+) kB$/\1/p' /proc/meminfo` * 8 / 10240))m"
  export SERVER_JVMFLAGS="$XMX -XX:NewRatio=5 -XX:+UseConcMarkSweepGC -XX:+UseParNewGC"

  # start-up zookeeper
  $ZK_DIR/bin/zkServer.sh start
}

stop_zk() {
  # stop zookeeper and nuke the id file
  $ZK_DIR/bin/zkServer.sh stop > /dev/null 2>&1
  rm -f "$ZK_DATA_DIR/myid"
}


case "$1" in
  start)
    start_zk
    ;;
  stop)
    stop_zk
    ;;
  restart)
    stop_zk
    sleep 1
    start_zk
    ;;
  *)
    echo "Usage: $(basename $0) <start|stop|start|check>" >&2
    exit 1
esac
