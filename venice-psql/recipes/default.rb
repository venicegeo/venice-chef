include_recipe "postgresql::client"

execute "rpm --import https://yum.boundlessps.com/RPM-GPG-KEY-yum.boundlessps.com"

cookbook_file "/etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-#{node.platform_version.to_i}" do
  source "RPM-GPG-KEY-CentOS-#{node.platform_version.to_i}"
  mode 0644
end

yum_repository "pgdg95" do
  description "Postgres 9.5 Community Repo"
  baseurl "https://download.postgresql.org/pub/repos/yum/9.5/redhat/rhel-$releasever-$basearch"
  gpgkey "https://yum.boundlessps.com/RPM-GPG-KEY-PGDG-95"
end

cookbook_file '/root/postgres.sh' do
  source "postgres.sh"
  user "root"
  group "root"
  mode 0700
end
