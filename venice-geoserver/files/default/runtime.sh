#!/bin/bash


[ -f /etc/profile.d/runtime.sh ] && source /etc/profile.d/runtime.sh

[ -f $GEOSERVER_DATA_DIR/init ] && exit 0

# Base config files
echo "STARTING GEOSERVER"
systemctl start tomcat_geoserver
echo "SLEEPING"
sleep 180
echo "STOPPING GEOSERVER"
systemctl stop tomcat_geoserver
sleep 30

cp -Rf /etc/geoserver/* $GEOSERVER_DATA_DIR
mkdir -p $GEOSERVER_DATA_DIR/workspaces/piazza/piazza
mkdir -p $GEOSERVER_DATA_DIR/jdbcconfig

touch $GEOSERVER_DATA_DIR/workspaces/piazza/piazza/datastore.xml
cat <<- EOF > $GEOSERVER_DATA_DIR/workspaces/piazza/piazza/datastore.xml
<dataStore>
  <id>DataStoreInfoImpl-37799a2:152c664e321:-7ffb</id>
  <name>piazza</name>
  <description>piazza</description>
  <type>PostGIS</type>
  <enabled>true</enabled>
  <workspace>
    <id>WorkspaceInfoImpl--6e9d1a49:150d2d8b42d:-7fec</id>
  </workspace>
  <connectionParameters>
    <entry key="user">$DB_USER</entry>
    <entry key="passwd">$DB_PASSWORD</entry>
    <entry key="port">$DB_PORT</entry>
    <entry key="database">$DB_NAME</entry>
    <entry key="host">$DB_HOST</entry>
    <entry key="schema">public</entry>
    <entry key="Evictor run periodicity">300</entry>
    <entry key="Max open prepared statements">50</entry>
    <entry key="encode functions">false</entry>
    <entry key="preparedStatements">false</entry>
    <entry key="Loose bbox">true</entry>
    <entry key="Estimated extends">true</entry>
    <entry key="fetch size">1000</entry>
    <entry key="Expose primary keys">false</entry>
    <entry key="validate connections">true</entry>
    <entry key="Support on the fly geometry simplification">true</entry>
    <entry key="Connection timeout">20</entry>
    <entry key="create database">false</entry>
    <entry key="min connections">1</entry>
    <entry key="dbtype">postgis</entry>
    <entry key="namespace">http://radiantblue.com/piazza/</entry>
    <entry key="max connections">10</entry>
    <entry key="Evictor tests per run">3</entry>
    <entry key="Test while idle">true</entry>
    <entry key="Max connection idle time">300</entry>
  </connectionParameters>
  <__default>false</__default>
</dataStore>
EOF

# cat <<- EOF > $GEOSERVER_DATA_DIR/jdbcconfig/jdbcconfig.properties
#  enabled=true
#  initdb=false
#  import=false
#  jdbcUrl=jdbc:postgresql://$DB_HOST:$DB_PORT/$DB_NAME
#  initScript=/etc/geoserver/initdb.postgres.sql
#  driverClassName=org.postgresql.Driver
#  username=$DB_USER
#  password=$DB_PASSWORD
#  pool.minIdle=4
#  pool.maxActive=10
#  pool.poolPreparedStatements=true
#  pool.maxOpenPreparedStatements=50
#  pool.testOnBorrow=true
#  pool.validationQuery=SELECT 1 LIMIT 1
# EOF

touch $GEOSERVER_DATA_DIR/init

chown -R tomcat_geoserver:tomcat_geoserver $GEOSERVER_DATA_DIR
