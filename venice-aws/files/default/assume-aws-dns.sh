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

instance_id=$(curl http://169.254.169.254/latest/meta-data/instance-id/)
[ -z "$instance_id" ] && echo "instance id not detected." && exit 1

[ -z "$AWS_SUBDOMAIN" ] && echo "No subdomain provided!" >&2 && exit 1
[ -z "$AWS_ZONE_ID" ] && echo "No zone id provided!" >&2 && exit 1

[ -z "$AWS_PRIVATE_NETWORK" ] && private=false || private=true


$private && recordType=A || recordType=CNAME
$private && awsQuery=PrivateIpAddress || awsQuery=PublicDnsName

address=$(aws ec2 describe-instances --instance-id $instance_id --query Reservations[].Instances[].$awsQuery --output=text)

if [ -z "$address" ]; then

  $private && netType=Private || netType=Public

  currentip=$(aws ec2 describe-instances --instance-id $instance_id --query Reservations[].Instances[].${netType}IpAddress --output=text)

  [ -z "$currentip" ] && currentip=$(curl checkip.amazonaws.com)
  [ -z "$currentip" ] && echo "Current IP not detected." && exit 1

  $private && address=$currentip || \
    address=$(echo $currentip | sed 's/^\([0-9]\+\)[.]\([0-9]\+\)[.]\([0-9]\+\)[.]\([0-9]\+\)$/ec2-\1-\2-\3-\4.compute-1.amazonaws.com/')

fi

zoneid=${AWS_ZONE_ID}
dns=`aws route53 get-hosted-zone --id $zoneid --query HostedZone.Name --output text`
fqdn=${AWS_SUBDOMAIN}.${dns}

existing=`aws route53 list-resource-record-sets --hosted-zone-id $zoneid \
  --query="ResourceRecordSets[?Name=='$fqdn'].ResourceRecords[].Value" \
  --output=text`

[ "z$existing" = "z$address" ] && echo "Nothing to do" && exit

oldset=`aws route53 list-resource-record-sets --hosted-zone-id $zoneid \
  --query="ResourceRecordSets[?Name=='$fqdn']"`
oldset="${oldset:1}"
oldset="${oldset%?}"
[ -n "$oldset" ] && oldset="{\"Action\":\"DELETE\",\"ResourceRecordSet\":$oldset},"

tmpfile=`mktemp /tmp/r53.XXXXXX`

cat > $tmpfile <<EOF
{
  "Comment": "Switching $fqdn to $address",
  "Changes": [
    $oldset
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$fqdn",
        "Type": "$recordType",
        "TTL": 60,
        "ResourceRecords": [ { "Value" : "$address" } ]
      }
    }
  ]
}
EOF

# Add new Alias
changeid=`aws route53 change-resource-record-sets --hosted-zone-id $zoneid \
  --change-batch=file://$tmpfile \
    | awk -F"[,:}]" '{for(i=1;i<=NF;i++){if($i~/Id\042/){print $(i+1)}}}' \
    | tr -d '"'`

[ -z "$changeid" ] && echo "no changes made" && exit 1


# Change status:
s=`aws route53 get-change --id $changeid --query "ChangeInfo.Status" \
  --output text`
while [ "z$s" = "zPENDING" ]; do
  echo "change status: $s" && s=`aws route53 get-change --id $changeid \
                                  --query "ChangeInfo.Status" \
                                  --output text` && sleep 15
done
echo "change status: $s"


# Report
echo && echo "after:" && echo
aws route53 list-resource-record-sets --hosted-zone-id $zoneid \
  --query="ResourceRecordSets[?Name=='$fqdn']"

rm $tmpfile
