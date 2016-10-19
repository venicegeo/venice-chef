#!/bin/bash

[ -f /etc/profile.d/runtime.sh ] && . /etc/profile.d/runtime.sh

# Backups enabled?
[ $ENABLE_ZK_BACKUP = 'true' ] || exit 0

# if S3_PATH isn't defined in venice.sh, then bail out
[ -z "$S3_PATH" ] && exit

ZK_CFG='/opt/zookeeper/conf/zoo.cfg'
TAR_EXCLUDES='--exclude lost+found --exclude myid --exclude log --exclude zk-data-snap.*'

# make sure we're the leader or standalone
zk_mode="$(echo stat | nc localhost 2181 | sed -n 's/^Mode: //p')"
if [ -z "$zk_mode" ]; then
  echo "$(date) - Fatal: unable to determine mode of local ZK instance" >&2
  exit 1
elif ! [ "$zk_mode" = 'standalone' -o "$zk_mode" = 'leader' ]; then
  # quietly exit if we're neither standalone nor a leader
  exit
fi

# if the dataDir isn't defined in the config, then bail (defaults to /tmp)
DATA_DIR="$(sed -n 's/^dataDir=//p' "$ZK_CFG")"
[ -z "$DATA_DIR" ] && exit
BACKUP_DIR=$DATA_DIR/backup
mkdir -p $BACKUP_DIR

instance_id=$(curl http://169.254.169.254/latest/meta-data/instance-id/)
dest_file="$(date +%F-%H-%M-%S)-$instance_id.tgz"
s3_dest="s3://$S3_PATH/$dest_file"
s3_last="s3://$S3_PATH/last"

TMPFILE="$(mktemp)"
if [ $? -ne 0 ]; then
  echo "$(date) - Fatal: failed to create tempfile" >&2
  exit 1
fi

if ! rsync -azv --exclude backup $DATA_DIR/ $BACKUP_DIR; then
  echo "$(date) - Fatal: rsync backup (1) failed." >&2
fi
if ! rsync -azv --exclude backup $DATA_DIR/ $BACKUP_DIR; then
  echo "$(date) - Fatal: rsync backup (2) failed." >&2
fi

if ! nice -n 19 tar -czf "$TMPFILE" -C $BACKUP_DIR $TAR_EXCLUDES .; then
  rm -rf "$TMPFILE"
  echo "$(date) - Fatal: 'tar czf \"$TMPFILE\" . $TAR_EXCLUDES' failed." >&2
  exit 1
fi
if ! aws s3 cp "$TMPFILE" "$s3_dest"; then
  rm -rf "$TMPFILE"
  echo "$(date) - Fatal: 'aws s3 cp \"$TMPFILE\" \"$s3_dest\" failed." >&2
  exit 1
fi
echo "$s3_dest" > "$TMPFILE"
if ! aws s3 cp "$TMPFILE" "$s3_last"; then
  rm -f "$TMPFILE"
  echo "$(date) - Fatal: 'aws s3 cp \"$TMPFILE\" \"$s3_last\"' failed." >&2
  exit 1
fi
rm -f "$TMPFILE"
