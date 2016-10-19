include_recipe 'venice-base::default'
include_recipe 'venice-aws::eni'
include_recipe 'apache_kafka'

cookbook_file '/root/kafka-config-setup.sh' do
  source "kafka-config-setup.sh"
  user "root"
  group "root"
  mode 0700
end

package 'mdadm'
