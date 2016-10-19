cookbook_file "/root/runtime.sh" do
  source "runtime.sh"
  owner "root"
  group "root"
  mode 0700
end

directory '/etc/geoserver' do
  owner 'tomcat_geoserver'
  group 'tomcat_geoserver'
  mode 0775
end

directory "/etc/geoserver/workspaces" do
  owner 'tomcat_geoserver'
  group 'tomcat_geoserver'
  mode 0755
end

directory "/etc/geoserver/workspaces/piazza" do
  owner 'tomcat_geoserver'
  group 'tomcat_geoserver'
  mode 0755
end

directory '/etc/geoserver/security' do
  owner 'tomcat_geoserver'
  group 'tomcat_geoserver'
  mode 0777
end

directory '/etc/geoserver/security/usergroup' do
  owner 'tomcat_geoserver'
  group 'tomcat_geoserver'
  mode 0775
end

directory '/etc/geoserver/security/usergroup/default' do
  owner 'tomcat_geoserver'
  group 'tomcat_geoserver'
  mode 0775
end

directory '/etc/geoserver/security/masterpw' do
  owner 'tomcat_geoserver'
  group 'tomcat_geoserver'
  mode 0775
end

directory '/etc/geoserver/security/masterpw/default' do
  owner 'tomcat_geoserver'
  group 'tomcat_geoserver'
  mode 0775
end

directory '/etc/geoserver/logs' do
  owner 'tomcat_geoserver'
  group 'tomcat_geoserver'
  mode 0775
end

cookbook_file '/etc/geoserver/initdb.postgres.sql' do
  source 'initdb.postgres.sql'
  owner 'tomcat_geoserver'
  group 'tomcat_geoserver'
  mode 0644
end

cookbook_file "/etc/geoserver/logging.xml" do
  source "logging.xml"
  mode 0644
  owner "tomcat_geoserver"
  group "tomcat_geoserver"
end

cookbook_file "/etc/geoserver/logs/log4j.properties" do
  source "log4j.properties"
  mode 0644
  owner "tomcat_geoserver"
  group "tomcat_geoserver"
end

cookbook_file "/etc/geoserver/gwc-gs.xml" do
  source "gwc-gs.xml"
  mode 0644
  owner "tomcat_geoserver"
  group "tomcat_geoserver"
end

template "/etc/geoserver/security/usergroup/default/users.xml" do
  source "gs_users.xml.erb"
  mode 0644
  owner "tomcat_geoserver"
  group "tomcat_geoserver"
  variables(password_hash: node[:geoserver][:admin_user][:password_hash])
end

file "/etc/geoserver/security/masterpw.digest" do
  content node[:geoserver][:root_user][:password_digest]
  owner "tomcat_geoserver"
  group "tomcat_geoserver"
  mode 0644
end

file "/etc/geoserver/security/masterpw/default/passwd" do
  content node[:geoserver][:root_user][:password_hash]
  owner "tomcat_geoserver"
  group "tomcat_geoserver"
  mode 0644
end

cookbook_file "/etc/geoserver/security/rest.properties" do
  source "rest.properties"
  owner "tomcat_geoserver"
  group "tomcat_geoserver"
  mode 0644
end

cookbook_file "/etc/geoserver/security/geoserver.jceks" do
  source "geoserver.jceks"
  owner "tomcat_geoserver"
  group "tomcat_geoserver"
  mode 0644
end

cookbook_file "/etc/geoserver/workspaces/piazza/namespace.xml" do
  source "workspaces/piazza/namespace.xml"
  owner "tomcat_geoserver"
  group "tomcat_geoserver"
  mode 0644
end

cookbook_file "/etc/geoserver/workspaces/piazza/settings.xml" do
  source "workspaces/piazza/settings.xml"
  owner "tomcat_geoserver"
  group "tomcat_geoserver"
  mode 0644
end

cookbook_file "/etc/geoserver/workspaces/piazza/wcs.xml" do
  source "workspaces/piazza/wcs.xml"
  owner "tomcat_geoserver"
  group "tomcat_geoserver"
  mode 0644
end

cookbook_file "/etc/geoserver/workspaces/piazza/wfs.xml" do
  source "workspaces/piazza/wfs.xml"
  owner "tomcat_geoserver"
  group "tomcat_geoserver"
  mode 0644
end

cookbook_file "/etc/geoserver/workspaces/piazza/wms.xml" do
  source "workspaces/piazza/wms.xml"
  owner "tomcat_geoserver"
  group "tomcat_geoserver"
  mode 0644
end

cookbook_file "/etc/geoserver/workspaces/piazza/workspace.xml" do
  source "workspaces/piazza/workspace.xml"
  owner "tomcat_geoserver"
  group "tomcat_geoserver"
  mode 0644
end

execute "set geoserver permissions" do
  command "find /etc/geoserver -type d -exec chmod 755 {} + && find /etc/geoserver -type f -exec chmod 644 {} + && chown -R tomcat_geoserver:tomcat_geoserver /etc/geoserver"
  action :nothing
end
