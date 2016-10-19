include_recipe 'venice-base::default'
include_recipe 'venice-aws::eni'
include_recipe 'zookeeper'

zookeeper_version=node[:zookeeper][:version]

package 'nc'

# hack for now
script "unpack zookeeper source" do
  interpreter "bash"
  flags "-e"
  user "root"
  cwd "/opt"
  code <<-EOH
  mv /opt/zookeeper/zookeeper-#{zookeeper_version} /tmp/zk
  rm -rf /opt/zookeeper
  mv /tmp/zk /opt/zookeeper
  EOH
end

cookbook_file '/usr/local/sbin/zookeeper-ctl.sh' do
  source "zookeeper-ctl.sh"
  user "root"
  group "root"
  mode 0755
end

cookbook_file '/etc/cron.daily/zk-datadir-backup.sh' do
  source "zk-datadir-backup.sh"
  user "root"
  group "root"
  mode 0755
end

cookbook_file '/etc/cron.daily/zk-purge-logs.sh' do
  source "zk-purge-logs.sh"
  user "root"
  group "root"
  mode 0755
end

directory "/etc/zookeeper.d" do
  owner "root"
  group "root"
  mode 00755
  action :create
end

cookbook_file '/etc/zookeeper.d/00-base.cfg' do
  source "config-base.cfg"
  user "root"
  group "root"
  mode 0644
end
