include_recipe "java"

tomcat_install 'geoserver' do
  version '8.0.32'
end

tomcat_service 'geoserver' do
  action :start
end

directory '/tmp/geoserver' do
  owner 'tomcat_geoserver'
  group 'tomcat_geoserver'
  mode 0755
end

remote_file "/tmp/geoserver/geoserver.war.zip" do
  source node[:geoserver][:src]
  owner 'tomcat_geoserver'
  group 'tomcat_geoserver'
  mode 0444
end

package 'unzip'

script 'unpack zipfile' do
  interpreter 'bash'
  flags '-e'
  user 'tomcat_geoserver'
  group 'tomcat_geoserver'
  cwd '/tmp'
  cwd "/opt/tomcat_geoserver"
  code <<-EOH
   unzip /tmp/geoserver/geoserver.war.zip -d /tmp/geoserver/
   mv /tmp/geoserver/geoserver.war "/opt/tomcat_geoserver/webapps/geoserver.war"
   rm -rf /tmp/geoserver
   sleep 10
  EOH
  notifies :restart, "tomcat_service[geoserver]"
end

ruby_block "let geoserver unpack" do
  block do
    sleep 180
  end
  action :run
end

execute "set geoserver permissions" do
  command "find #{node[:geoserver][:data_dir]} -type d -exec chmod 755 {} + && find #{node[:geoserver][:data_dir]} -type f -exec chmod 644 {} + && chown -R tomcat_geoserver:tomcat_geoserver #{node[:geoserver][:data_dir]}"
  action :nothing
end

template "/opt/tomcat_geoserver/webapps/geoserver/WEB-INF/web.xml" do
  owner "tomcat_geoserver"
  group "tomcat_geoserver"
  mode 0644
  source "web.xml.erb"
  notifies :restart, "tomcat_service[geoserver]"
  variables(
    jsonp_enabled: node[:geoserver][:jsonp_enabled],
    geoserver_directory: node[:geoserver][:data_dir],
    gwc_directory: node[:geoserver][:gwc_data_dir]
  )
end
