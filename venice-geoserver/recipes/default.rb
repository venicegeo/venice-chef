include_recipe 'venice-base::default'
include_recipe "venice-geoserver::install"
#include_recipe "venice-geoserver::jdbc"
include_recipe "venice-geoserver::runtime"
include_recipe "venice-aws::efs"

tomcat_service 'geoserver' do
  action :restart
end

ruby_block "let geoserver initialize extensions" do
  block do
      sleep 180
  end
  action :run
end

tomcat_service 'geoserver' do
  action :stop
end

tomcat_service 'geoserver' do
  action :disable
end
