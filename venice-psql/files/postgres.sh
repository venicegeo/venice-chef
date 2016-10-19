#!/bin/bash

[ -f /etc/profile.d/runtime.sh ] && . /etc/profile.d/runtime.sh

[ -z "$ROOT_DB_HOST" ] && { echo "ROOT_DB_HOST not defined" 2>&1; exit 1; }
[ -z "$ROOT_DB_PORT" ] && { echo "ROOT_DB_PORT not defined" 2>&1; exit 1; }
[ -z "$ROOT_DB_USER" ] && { echo "ROOT_DB_USER not defined" 2>&1; exit 1; }
[ -z "$ROOT_DB_PASS" ] && { echo "ROOT_DB_PASS not defined" 2>&1; exit 1; }

[ -z "$DB_NAME" ] && { echo "DB_NAME not defined" 2>&1; exit 1; }
[ -z "$DB_USER" ] && { echo "DB_USER not defined" 2>&1; exit 1; }
[ -z "$DB_PASS" ] && { echo "DB_PASS not defined" 2>&1; exit 1; }

export PGPASSWORD=$ROOT_DB_PASS

root_psql="psql --host $ROOT_DB_HOST --port $ROOT_DB_PORT --username $ROOT_DB_USER"
user_psql="psql --host $ROOT_DB_HOST --port $ROOT_DB_PORT --username $DB_USER --dbname $DB_NAME"

# CREATE USER
$root_psql --dbname postgres <<EOF
DO
\$body$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_user WHERE usename = '$DB_USER') THEN
     RAISE INFO 'User: $DB_USER already exists';
  ELSE
    CREATE ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PASS';
  END IF;
END
\$body$;
EOF

# CREATE DATABASE
exists=$($root_psql --tuples-only --dbname postgres -c "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'")

[ "1" != "$exists" ] && $root_psql --dbname postgres -c "CREATE DATABASE $DB_NAME"

$root_psql --dbname postgres <<EOF
REVOKE CONNECT ON DATABASE $DB_NAME FROM PUBLIC;
GRANT CONNECT ON DATABASE $DB_NAME TO $DB_USER;

REVOKE ALL
ON ALL TABLES IN SCHEMA public
FROM PUBLIC;
EOF

# POSTGIS
$root_psql --dbname $DB_NAME <<EOF
CREATE EXTENSION postgis;
CREATE EXTENSION fuzzystrmatch;
CREATE EXTENSION postgis_tiger_geocoder;
CREATE EXTENSION postgis_topology;

ALTER SCHEMA tiger OWNER TO rds_superuser;
ALTER SCHEMA tiger_data OWNER TO rds_superuser;
ALTER SCHEMA topology OWNER TO rds_superuser;

ALTER VIEW geography_columns OWNER TO rds_superuser;
ALTER VIEW geometry_columns OWNER TO rds_superuser;
ALTER VIEW raster_columns OWNER TO rds_superuser;
ALTER VIEW raster_overviews OWNER TO rds_superuser;
ALTER TABLE spatial_ref_sys OWNER TO rds_superuser;

CREATE OR REPLACE FUNCTION exec(text) returns text language plpgsql volatile AS \$f$ BEGIN EXECUTE \$1; RETURN \$1; END; \$f$;
  SELECT exec('ALTER TABLE ' || quote_ident(s.nspname) || '.' || quote_ident(s.relname) || ' OWNER TO rds_superuser')
  FROM (
    SELECT nspname, relname
    FROM pg_class c JOIN pg_namespace n ON (c.relnamespace = n.oid)
    WHERE nspname in ('tiger','topology') AND
    relkind IN ('r','S','v') ORDER BY relkind = 'S')
s;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.geometry_columns TO $DB_USER;
GRANT SELECT ON public.spatial_ref_sys TO $DB_USER;
GRANT SELECT ON public.geography_columns TO $DB_USER;
GRANT SELECT ON public.raster_columns TO $DB_USER;
GRANT SELECT ON public.raster_overviews TO $DB_USER;
EOF

# GRANT ACCESS
export PGPASSWORD=$DB_PASS
$user_psql <<EOF
ALTER DEFAULT PRIVILEGES FOR ROLE $DB_USER
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO $DB_USER;

GRANT SELECT, INSERT, UPDATE, DELETE
ON ALL TABLES IN SCHEMA public
TO $DB_USER;
EOF

# GEOSERVER
$user_psql <<EOF
CREATE TABLE IF NOT EXISTS type (
  oid serial NOT NULL,
  typename text NOT NULL,
  PRIMARY KEY (OID)
);

CREATE TABLE IF NOT EXISTS object (
  oid serial NOT NULL,
  type_id int4 NOT NULL REFERENCES type (oid),
  id text NOT NULL,
  blob text NOT NULL,
  PRIMARY KEY (oid)
);

CREATE TABLE IF NOT EXISTS property_type (
  oid  serial NOT NULL,
  target_property int4,
  type_id int4 NOT NULL REFERENCES type (oid),
  name text NOT NULL,
  collection bool NOT NULL,
  text bool NOT NULL,
  PRIMARY KEY (oid),
  FOREIGN KEY (target_property) references property_type (oid)
);

CREATE TABLE IF NOT EXISTS object_property (
  oid int4 NOT NULL REFERENCES object (oid) ON DELETE CASCADE,
  property_type int4 NOT NULL REFERENCES property_type (oid),
  id text NOT NULL,
  related_oid int4,
  related_property_type int4,
  colindex int4 NOT NULL,
  value text,
  PRIMARY KEY (oid, property_type, colindex)
);

CREATE TABLE IF NOT EXISTS default_object (
  def_key text NOT NULL,
  id text NOT NULL
);


CREATE UNIQUE INDEX object_oid_idx ON object (oid);
CREATE INDEX object_type_id_idx ON object (type_id);
CREATE UNIQUE INDEX object_id_idx ON object (id);

CREATE INDEX object_property_value_upper_idx ON object_property (UPPER(value));
CREATE INDEX object_property_oid_idx ON object_property (OID);
CREATE INDEX object_property_property_type_idx ON object_property (property_type);
CREATE INDEX object_property_id_idx ON object_property (id);
CREATE INDEX object_property_related_oid_idx ON object_property (related_oid);
CREATE INDEX object_property_related_property_type_idx ON object_property (related_property_type);
CREATE INDEX object_property_colindex_idx ON object_property (colindex);
CREATE INDEX object_property_value_idx ON object_property (value);

CREATE UNIQUE INDEX type_oid_idx ON type (oid);
CREATE UNIQUE INDEX type_typename_idx ON type (typename);

CREATE UNIQUE INDEX property_type_oid_idx ON property_type (oid);
CREATE INDEX property_type_target_property_idx ON property_type (target_property);
CREATE INDEX property_type_type_id_idx ON property_type (type_id);
CREATE INDEX property_type_name_idx ON property_type (name);
CREATE INDEX property_type_collection_idx ON property_type (collection);

CREATE INDEX default_object_def_key_idx ON default_object (def_key);
CREATE INDEX default_object_id_idx ON default_object (id);

-- views
-- workspace view
CREATE OR REPLACE VIEW workspace AS
SELECT a.oid,
       a.id,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'name') as name,
       (SELECT e.value
          FROM object_property e, property_type f
         WHERE e.property_type = f.oid
           AND e.oid = (SELECT g.oid
                          FROM object_property g, property_type h
                         WHERE g.property_type = h.oid
                           AND g.value = (SELECT i.value
                                            FROM object_property i, property_type j
                                           WHERE i.oid = a.oid
                                             AND i.property_type = j.oid
                                             AND j.name = 'name')
                           AND h.name = 'prefix')
           AND f.name = 'URI') as uri
  FROM object a, type b
 WHERE a.type_id = b.oid
   AND b.typename = 'org.geoserver.catalog.WorkspaceInfo';

-- datastore view
CREATE OR REPLACE VIEW datastore AS
SELECT a.oid,
       a.id,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'name') as name,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'description') as description,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'type') as type,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'enabled') as enabled,
       (SELECT c.related_oid
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'workspace.id') workspace
  FROM object a, type b
 WHERE a.type_id = b.oid
   AND b.typename = 'org.geoserver.catalog.DataStoreInfo';

-- feature type view
CREATE OR REPLACE VIEW featuretype AS
SELECT a.oid,
       a.id,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'name') as name,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'nativeName') as native_name,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'prefixedName') as prefixed_name,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'title') as title,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'abstract') as abstract,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'SRS') as srs,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'projectionPolicy') as projection_policy,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'enabled') as enabled,
       (SELECT c.related_oid
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'store.id') store,
       (SELECT c.related_oid
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'namespace.id') namespace
  FROM object a, type b
 WHERE a.type_id = b.oid
   AND b.typename = 'org.geoserver.catalog.FeatureTypeInfo';

-- coveragestore view
CREATE OR REPLACE VIEW coveragestore AS
SELECT a.oid,
       a.id,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'name') as name,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'description') as description,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'type') as type,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'enabled') as enabled,
       (SELECT c.related_oid
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'workspace.id') workspace
  FROM object a, type b
 WHERE a.type_id = b.oid
   AND b.typename = 'org.geoserver.catalog.CoverageStoreInfo';

-- coverage view
CREATE OR REPLACE VIEW coverage AS
SELECT a.oid,
       a.id,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'name') as name,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'nativeName') as native_name,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'prefixedName') as prefixed_name,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'title') as title,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'abstract') as abstract,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'SRS') as srs,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'projectionPolicy') as projection_policy,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'enabled') as enabled,
       (SELECT c.related_oid
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'store.id') store,
       (SELECT c.related_oid
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'namespace.id') namespace
  FROM object a, type b
 WHERE a.type_id = b.oid
   AND b.typename = 'org.geoserver.catalog.CoverageInfo';

-- wmsstore view
CREATE OR REPLACE VIEW wmsstore AS
SELECT a.oid,
       a.id,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'name') as name,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'description') as description,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'capabilitiesURL') as capabilities_url,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'type') as type,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'enabled') as enabled,
       (SELECT c.related_oid
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'workspace.id') workspace
  FROM object a, type b
 WHERE a.type_id = b.oid
   AND b.typename = 'org.geoserver.catalog.WMSStoreInfo';

-- wms layer view
CREATE OR REPLACE VIEW wmslayer AS
SELECT a.oid,
       a.id,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'name') as name,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'nativeName') as native_name,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'prefixedName') as prefixed_name,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'title') as title,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'abstract') as abstract,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'SRS') as srs,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'projectionPolicy') as projection_policy,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'enabled') as enabled,
       (SELECT c.related_oid
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'store.id') store,
       (SELECT c.related_oid
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'namespace.id') namespace
  FROM object a, type b
 WHERE a.type_id = b.oid
   AND b.typename = 'org.geoserver.catalog.WMSLayerInfo';

-- style view
CREATE OR REPLACE VIEW style AS
SELECT a.oid,
       a.id,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'name') as name,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'filename') as filename,
       (SELECT c.related_oid
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'workspace.id') workspace
  FROM object a, type b
 WHERE a.type_id = b.oid
   AND b.typename = 'org.geoserver.catalog.StyleInfo';

-- layer view
CREATE OR REPLACE VIEW layer AS
SELECT a.oid,
       a.id,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'name') as name,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'title') as title,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'abstract') as abstract,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'type') as type,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'enabled') as enabled,
       (SELECT c.related_oid
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'defaultStyle.id') default_style,
       (SELECT c.related_oid
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'resource.id') resource
  FROM object a, type b
 WHERE a.type_id = b.oid
   AND b.typename = 'org.geoserver.catalog.LayerInfo';

-- layergroup styles
CREATE OR REPLACE VIEW layer_style AS
SELECT a.oid, b.related_oid as style
  FROM object a, object_property b, property_type c, type d
 WHERE a.oid = b.oid
   AND a.type_id = d.oid
   AND b.property_type = c.oid
   AND c.name = 'styles.id'
   AND d.typename = 'org.geoserver.catalog.LayerInfo';

-- layer group view
CREATE OR REPLACE VIEW layergroup AS
SELECT a.oid,
       a.id,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'name') as name,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'title') as title,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'abstract') as abstract,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'mode') as mode,
       (SELECT c.related_oid
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'workspace.id') workspace
  FROM object a, type b
 WHERE a.type_id = b.oid
   AND b.typename = 'org.geoserver.catalog.LayerGroupInfo';

-- layergroup layers
CREATE OR REPLACE VIEW layergroup_layer AS
SELECT a.oid, b.related_oid as layer
  FROM object a, object_property b, property_type c, type d
 WHERE a.oid = b.oid
   AND a.type_id = d.oid
   AND b.property_type = c.oid
   AND c.name = 'layers.id'
   AND d.typename = 'org.geoserver.catalog.LayerGroupInfo';

-- layergroup styles
CREATE OR REPLACE VIEW layergroup_style AS
SELECT a.oid, b.related_oid as style
  FROM object a, object_property b, property_type c, type d
 WHERE a.oid = b.oid
   AND a.type_id = d.oid
   AND b.property_type = c.oid
   AND c.name = 'styles.id'
   AND d.typename = 'org.geoserver.catalog.LayerGroupInfo';

-- global view
CREATE OR REPLACE VIEW global AS
SELECT a.oid,
       a.id,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'featureTypeCacheSize') as feature_type_cache_size,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'globalServices') as global_services,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'xmlPostRequestLogBufferSize') as xml_post_request_log_buffer_size,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'updateSequence') as update_sequence,
       (SELECT c.related_oid
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'settings.id') as settings
  FROM object a, type b
 WHERE a.type_id = b.oid
   AND b.typename = 'org.geoserver.config.GeoServerInfo';

-- settings view
CREATE OR REPLACE VIEW settings AS
SELECT a.oid,
       a.id,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'title') as title,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'charset') as charset,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'verbose') as verbose,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'verboseExceptions') as verbose_exceptions,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'numDecimals') as num_decimals,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'onlineResource') as online_resource,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'proxyBaseUrl') as proxy_base_url,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'schemaBaseUrl') as schema_base_url,
       (SELECT c.related_oid
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'workspace.id') as workspace
  FROM object a, type b
 WHERE a.type_id = b.oid
   AND b.typename = 'org.geoserver.config.SettingsInfo';

-- service view
CREATE OR REPLACE VIEW service AS
SELECT a.oid,
       a.id,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'name') as name,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'title') as title,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'abstract') as abstract,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'maintainer') as maintainer,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'verbose') as verbose,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'citeCompliant') as cite_compliant,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'outputStrategy') as output_strategy,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'onlineResource') as online_resource,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'schemaBaseURL') as schema_base_url,
       (SELECT c.value
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'enabled') as enabled,
       (SELECT c.related_oid
          FROM object_property c, property_type d
         WHERE c.oid = a.oid
           AND c.property_type = d.oid
           AND d.name = 'workspace.id') as workspace
  FROM object a, type b
 WHERE a.type_id = b.oid
   AND b.typename = 'org.geoserver.config.ServiceInfo';
EOF
