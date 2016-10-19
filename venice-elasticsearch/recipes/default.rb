include_recipe 'elasticsearch'
include_recipe 'java'
include_recipe 'venice-base::default'
include_recipe 'venice-aws::eni'

package 'mdadm'

elasticsearch_user 'elasticsearch'
elasticsearch_install 'elasticsearch'

elasticsearch_configure 'elasticsearch' do
  configuration ({
                   'cluster.name' => 'venice',
                   'node.name' => '${HOSTNAME}',
                   'bootstrap.mlockall' => true,
                   'network.host' => '0.0.0.0',
                   'discovery.type' => 'ec2',
                   'plugin.mandatory' => 'cloud-aws',
                   'action.auto_create_index' => true,
                   'discovery.zen.ping.multicast.enabled' => false,
                   'index.mapper.dynamic' => true,
                   'index.auto_expand_replicas' => '0-all',
                   'index.number_of_shards' => 10,
                   'index.number_of_replicas' => 0,
                   'action.disable_delete_all_indices' => true,
                   'cluster.routing.allocation.node_initial_primaries_recoveries' => 8,
                   'cluster.routing.allocation.node_concurrent_recoveries' => 30,
                   'indices.recovery.max_bytes_per_sec' => '100mb',
                   'indices.recovery.concurrent_streams' => 10
                 })
end

elasticsearch_service 'elasticsearch'

elasticsearch_plugin 'cloud-aws' do
  action :install
end

elasticsearch_plugin 'kopf' do
  url 'lmenezes/elasticsearch-kopf'
  action :install
end

elasticsearch_plugin 'head' do
  url 'mobz/elasticsearch-head'
  action :install
end

elasticsearch_plugin 'elasticsearch-hq' do
  url 'royrusso/elasticsearch-HQ'
  action :install
end
