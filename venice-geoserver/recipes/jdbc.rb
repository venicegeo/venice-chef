directory '/tmp/geoserverjdbc' do
  owner 'tomcat_geoserver'
  group 'tomcat_geoserver'
  mode 0755
end

remote_file '/tmp/geoserverjdbc/geoserver.jdbc.zip' do
  source node[:geoserver][:jdbcconfig][:src]
  owner 'tomcat_geoserver'
  group 'tomcat_geoserver'
  mode 0444
end

script 'unpack jars' do
  interpreter 'bash'
  flags '-e'
  user 'tomcat_geoserver'
  group 'tomcat_geoserver'
  cwd '/tmp'
  cwd '/opt/tomcat_geoserver'
  code <<-EOH
   unzip /tmp/geoserverjdbc/geoserver.jdbc.zip -d #{node[:geoserver][:jdbcconfig][:dest]}
   rm -rf /tmp/geoserverjdbc
  EOH
end
