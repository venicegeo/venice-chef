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


[ -f /etc/profile.d/runtime.sh ] && . /etc/profile.d/runtime.sh

[ -z "$AWS_EIP" ] && echo "No elastic IP to assume!" >&2 && exit 1
[ -z "$AWS_EIP_ID" ] && echo "No elastic IP ID to assume!" >&2 && exit 1

instance_id=$(curl http://169.254.169.254/latest/meta-data/instance-id/)
currentip=$(curl checkip.amazonaws.com)

if [ "$AWS_EIP" != "$current_ip" ]; then
  aws ec2 associate-address --allocation-id $EIP_ID instance-id $instance_id
fi
