#!/bin/bash

# Copyright 2016, RadiantBlue Technologies, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


keyname="$1"

[ -z "$keyname" ] && { echo "usage: $0 <keyname>" >&2; exit 1; }

[ -f /etc/profile.d/runtime.sh ] && . /etc/profile.d/runtime.sh

: ${AWS_SSH_USER:=ec2-user}

while aws ec2 describe-key-pairs --key-names $keyname >/dev/null 2>&1 ; do
  aws ec2 delete-key-pair --key-name $keyname
done

keyfile=/home/$AWS_SSH_USER/.ssh/$keyname.pem

mkdir -p `dirname $keyfile`

[ -f $keyfile ] || ssh-keygen -q -t rsa -b 4096 -f $keyfile -P ''

chmod 400 $keyfile

aws ec2 import-key-pair --key-name $keyname --public-key-material "`cat $keyfile.pub`"

chown -R $AWS_SSH_USER:$AWS_SSH_USER /home/$AWS_SSH_USER/.ssh
