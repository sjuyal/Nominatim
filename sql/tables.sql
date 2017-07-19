drop table if exists import_status;
CREATE TABLE import_status (
  lastimportdate timestamp NOT NULL
  );
GRANT SELECT ON import_status TO "{www-user}" ;

drop table if exists import_osmosis_log;
CREATE TABLE import_osmosis_log (
  batchend timestamp,
  batchsize integer,
  starttime timestamp,
  endtime timestamp,
  event text
  );

drop table if exists import_npi_log;
CREATE TABLE import_npi_log (
  npiid integer,
  batchend timestamp,
  batchsize integer,
  starttime timestamp,
  endtime timestamp,
  event text
  );

--drop table IF EXISTS query_log;
CREATE TABLE query_log (
  starttime timestamp,
  query text,
  ipaddress text,
  endtime timestamp,
  results integer
  );
CREATE INDEX idx_query_log ON query_log USING BTREE (starttime);
GRANT SELECT ON query_log TO "{www-user}" ;
GRANT INSERT ON query_log TO "{www-user}" ;
GRANT UPDATE ON query_log TO "{www-user}" ;

CREATE TABLE new_query_log (
  type text,
  starttime timestamp,
  ipaddress text,
  useragent text,
  language text,
  query text,
  endtime timestamp,
  results integer,
  format text,
  secret text
  );
CREATE INDEX idx_new_query_log_starttime ON new_query_log USING BTREE (starttime);
GRANT INSERT ON new_query_log TO "{www-user}" ;
GRANT UPDATE ON new_query_log TO "{www-user}" ;
GRANT SELECT ON new_query_log TO "{www-user}" ;

GRANT SELECT ON TABLE country_name TO "{www-user}";
GRANT SELECT ON TABLE gb_postcode TO "{www-user}";

create view vw_search_query_log as SELECT substr(query, 1, 50) AS query, starttime, endtime - starttime AS duration, substr(useragent, 1, 20) as 
useragent, language, results, ipaddress FROM new_query_log WHERE type = 'search' ORDER BY starttime DESC;

drop table IF EXISTS word;
CREATE TABLE word (
  word_id INTEGER,
  word_token text,
  word text,
  class text,
  type text,
  country_code varchar(2),
  search_name_count INTEGER,
  operator TEXT
  ) {ts:search-data};
CREATE INDEX idx_word_word_token on word USING BTREE (word_token) {ts:search-index};
GRANT SELECT ON word TO "{www-user}" ;
DROP SEQUENCE IF EXISTS seq_word;
CREATE SEQUENCE seq_word start 1;

drop table IF EXISTS location_area CASCADE;
CREATE TABLE location_area (
  partition integer,
  place_id BIGINT,
  country_code VARCHAR(2),
  keywords INTEGER[],
  rank_search INTEGER NOT NULL,
  rank_address INTEGER NOT NULL,
  isguess BOOL
  );
SELECT AddGeometryColumn('location_area', 'centroid', 4326, 'POINT', 2);
SELECT AddGeometryColumn('location_area', 'geometry', 4326, 'GEOMETRY', 2);

CREATE TABLE location_area_large () INHERITS (location_area);

drop table IF EXISTS location_property CASCADE;
CREATE TABLE location_property (
  place_id BIGINT,
  partition integer,
  parent_place_id BIGINT,
  housenumber TEXT,
  postcode TEXT
  );
SELECT AddGeometryColumn('location_property', 'centroid', 4326, 'POINT', 2);

CREATE TABLE location_property_aux () INHERITS (location_property);
CREATE INDEX idx_location_property_aux_place_id ON location_property_aux USING BTREE (place_id);
CREATE INDEX idx_location_property_aux_parent_place_id ON location_property_aux USING BTREE (parent_place_id);
CREATE INDEX idx_location_property_aux_housenumber_parent_place_id ON location_property_aux USING BTREE (parent_place_id, housenumber);
GRANT SELECT ON location_property_aux TO "{www-user}";

CREATE TABLE location_property_tiger () INHERITS (location_property) {ts:aux-data};
CREATE INDEX idx_location_property_tiger_place_id ON location_property_tiger USING BTREE (place_id) {ts:aux-index};
CREATE INDEX idx_location_property_tiger_parent_place_id ON location_property_tiger USING BTREE (parent_place_id) {ts:aux-index};
CREATE INDEX idx_location_property_tiger_housenumber_parent_place_id ON location_property_tiger USING BTREE (parent_place_id, housenumber) {ts:aux-index};
GRANT SELECT ON location_property_tiger TO "{www-user}";

drop table IF EXISTS search_name;
CREATE TABLE search_name (
  place_id BIGINT,
  search_rank integer,
  address_rank integer,
  importance FLOAT,
  country_code varchar(2),
  name_vector integer[],
  nameaddress_vector integer[]
  ) {ts:search-data};
SELECT AddGeometryColumn('search_name', 'centroid', 4326, 'GEOMETRY', 2);
CREATE INDEX idx_search_name_place_id ON search_name USING BTREE (place_id) {ts:search-index};

drop table IF EXISTS place_addressline;
CREATE TABLE place_addressline (
  place_id BIGINT,
  address_place_id BIGINT,
  fromarea boolean,
  isaddress boolean,
  distance float,
  cached_rank_address integer
  ) {ts:search-data};
CREATE INDEX idx_place_addressline_place_id on place_addressline USING BTREE (place_id) {ts:search-index};

drop table if exists placex;
CREATE TABLE placex (
  place_id BIGINT NOT NULL,
  partition integer,
  LIKE place INCLUDING CONSTRAINTS,
  parent_place_id BIGINT,
  linked_place_id BIGINT,
  rank_address INTEGER,
  rank_search INTEGER,
  importance FLOAT,
  indexed_status INTEGER,
  indexed_date TIMESTAMP,
  wikipedia TEXT, -- calculated wikipedia article name (language:title)
  geometry_sector INTEGER,
  calculated_country_code varchar(2)
  ) {ts:search-data};
SELECT AddGeometryColumn('placex', 'centroid', 4326, 'GEOMETRY', 2);
CREATE UNIQUE INDEX idx_place_id ON placex USING BTREE (place_id) {ts:search-index};
CREATE INDEX idx_placex_osmid ON placex USING BTREE (osm_type, osm_id) {ts:search-index};
CREATE INDEX idx_placex_linked_place_id ON placex USING BTREE (linked_place_id) {ts:address-index};
CREATE INDEX idx_placex_rank_search ON placex USING BTREE (rank_search, geometry_sector) {ts:address-index};
CREATE INDEX idx_placex_geometry ON placex USING GIST (geometry) {ts:search-index};
CREATE INDEX idx_placex_adminname on placex USING BTREE (make_standard_name(name->'name'),rank_search) {ts:address-index} WHERE osm_type='N' and rank_search < 26;

DROP SEQUENCE IF EXISTS seq_place;
CREATE SEQUENCE seq_place start 1;
GRANT SELECT on placex to "{www-user}" ;
GRANT SELECT ON search_name to "{www-user}" ;
GRANT SELECT on place_addressline to "{www-user}" ;
GRANT SELECT ON seq_word to "{www-user}" ;
GRANT SELECT ON planet_osm_ways to "{www-user}" ;
GRANT SELECT ON planet_osm_rels to "{www-user}" ;
GRANT SELECT on location_area to "{www-user}" ;

-- insert creates the location tagbles, creates location indexes if indexed == true
CREATE TRIGGER placex_before_insert BEFORE INSERT ON placex
    FOR EACH ROW EXECUTE PROCEDURE placex_insert();

-- update insert creates the location tables
CREATE TRIGGER placex_before_update BEFORE UPDATE ON placex
    FOR EACH ROW EXECUTE PROCEDURE placex_update();

-- diff update triggers
CREATE TRIGGER placex_before_delete AFTER DELETE ON placex
    FOR EACH ROW EXECUTE PROCEDURE placex_delete();
CREATE TRIGGER place_before_delete BEFORE DELETE ON place
    FOR EACH ROW EXECUTE PROCEDURE place_delete();
CREATE TRIGGER place_before_insert BEFORE INSERT ON place
    FOR EACH ROW EXECUTE PROCEDURE place_insert();

DROP SEQUENCE seq_postcodes;
CREATE SEQUENCE seq_postcodes start 1;

drop table import_polygon_error;
CREATE TABLE import_polygon_error (
  osm_type char(1),
  osm_id INTEGER,
  class TEXT NOT NULL,
  type TEXT NOT NULL,
  name HSTORE,
  country_code varchar(2),
  updated timestamp,
  errormessage text
  );
SELECT AddGeometryColumn('import_polygon_error', 'prevgeometry', 4326, 'GEOMETRY', 2);
SELECT AddGeometryColumn('import_polygon_error', 'newgeometry', 4326, 'GEOMETRY', 2);
CREATE INDEX idx_import_polygon_error_osmid ON import_polygon_error USING BTREE (osm_type, osm_id);
GRANT SELECT ON import_polygon_error TO "{www-user}";

drop table import_polygon_delete;
CREATE TABLE import_polygon_delete (
  osm_type char(1),
  osm_id INTEGER,
  class TEXT NOT NULL,
  type TEXT NOT NULL
  );
CREATE INDEX idx_import_polygon_delete_osmid ON import_polygon_delete USING BTREE (osm_type, osm_id);
GRANT SELECT ON import_polygon_delete TO "{www-user}";

drop sequence file;
CREATE SEQUENCE file start 1;

-- null table so it won't error
-- deliberately no drop - importing the table is expensive and static, if it is already there better to avoid removing it
CREATE TABLE wikipedia_article (
    language text NOT NULL,
    title text NOT NULL,
    langcount integer,
    othercount integer,
    totalcount integer,
    lat double precision,
    lon double precision,
    importance double precision,
    osm_type character(1),
    osm_id bigint
);
ALTER TABLE ONLY wikipedia_article ADD CONSTRAINT wikipedia_article_pkey PRIMARY KEY (language, title);
CREATE INDEX idx_wikipedia_article_osm_id ON wikipedia_article USING btree (osm_type, osm_id);

CREATE TABLE wikipedia_redirect (
    language text,
    from_title text,
    to_title text
);
ALTER TABLE ONLY wikipedia_redirect ADD CONSTRAINT wikipedia_redirect_pkey PRIMARY KEY (language, from_title);

