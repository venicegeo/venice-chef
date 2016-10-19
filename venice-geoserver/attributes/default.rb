default[:geoserver][:src] = 'https://s3.amazonaws.com/geoserver-mirror/geoserver-2.9.x-latest-war.zip'
default[:geoserver][:jdbcconfig][:src] = 'https://s3.amazonaws.com/geoserver-mirror/geoserver-2.9-SNAPSHOT-jdbcconfig-plugin.zip'
default[:geoserver][:jdbcconfig][:dest] = '/opt/tomcat_geoserver/webapps/geoserver/WEB-INF/lib/'

default[:geoserver][:data_dir] = "/opt/tomcat_geoserver/webapps/geoserver/data"
default[:geoserver][:gwc_data_dir] = "#{node[:geoserver][:data_dir]}/gwc"
default[:geoserver][:jsonp_enabled] = false

default[:geoserver][:root_user][:password] = "OUEJ6u1ZgQme"
default[:geoserver][:root_user][:password_hash] = "SMyGqqwmWVUqNmYvMpy/yU7pJflL/BcT"
default[:geoserver][:root_user][:password_digest] = "digest1:Oa8Fkm86HT17L840PSMTBmUBMnyho+HqSKfQhyHvDNqRZpiKxTz9GK5S1SuyQoDV"

default[:geoserver][:admin_user][:username] = "admin"
default[:geoserver][:admin_user][:password] = "OUEJ6u1ZgQme"
default[:geoserver][:admin_user][:password_hash] = "crypt1:R79GCWTjNzQgvYHOziTXhWyNfBHwzd6M"

default[:java][:jdk_version] = '8'
