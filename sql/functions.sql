CREATE OR REPLACE FUNCTION geometry_sector(partition INTEGER, place geometry) RETURNS INTEGER
  AS $$
DECLARE
  NEWgeometry geometry;
BEGIN
--  RAISE WARNING '%',place;
  NEWgeometry := ST_PointOnSurface(place);
  RETURN (partition*1000000) + (500-ST_X(NEWgeometry)::integer)*1000 + (500-ST_Y(NEWgeometry)::integer);
END;
$$
LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION transliteration(text) RETURNS text
  AS '{modulepath}/nominatim.so', 'transliteration'
LANGUAGE c IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION gettokenstring(text) RETURNS text
  AS '{modulepath}/nominatim.so', 'gettokenstring'
LANGUAGE c IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION make_standard_name(name TEXT) RETURNS TEXT
  AS $$
DECLARE
  o TEXT;
BEGIN
  o := gettokenstring(transliteration(name));
  RETURN trim(substr(o,1,length(o)));
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE;

-- returns NULL if the word is too common
CREATE OR REPLACE FUNCTION getorcreate_word_id(lookup_word TEXT) 
  RETURNS INTEGER
  AS $$
DECLARE
  lookup_token TEXT;
  return_word_id INTEGER;
  count INTEGER;
BEGIN
  lookup_token := trim(lookup_word);
  SELECT min(word_id), max(search_name_count) FROM word WHERE word_token = lookup_token and class is null and type is null into return_word_id, count;
  IF return_word_id IS NULL THEN
    return_word_id := nextval('seq_word');
    INSERT INTO word VALUES (return_word_id, lookup_token, null, null, null, null, 0);
  ELSE
    IF count > get_maxwordfreq() THEN
      return_word_id := NULL;
    END IF;
  END IF;
  RETURN return_word_id;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION getorcreate_housenumber_id(lookup_word TEXT)
  RETURNS INTEGER
  AS $$
DECLARE
  lookup_token TEXT;
  return_word_id INTEGER;
BEGIN
  lookup_token := ' '||trim(lookup_word);
  SELECT min(word_id) FROM word WHERE word_token = lookup_token and class='place' and type='house' into return_word_id;
  IF return_word_id IS NULL THEN
    return_word_id := nextval('seq_word');
    INSERT INTO word VALUES (return_word_id, lookup_token, null, 'place', 'house', null, 0);
  END IF;
  RETURN return_word_id;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION getorcreate_country(lookup_word TEXT, lookup_country_code varchar(2))
  RETURNS INTEGER
  AS $$
DECLARE
  lookup_token TEXT;
  return_word_id INTEGER;
BEGIN
  lookup_token := ' '||trim(lookup_word);
  SELECT min(word_id) FROM word WHERE word_token = lookup_token and country_code=lookup_country_code into return_word_id;
  IF return_word_id IS NULL THEN
    return_word_id := nextval('seq_word');
    INSERT INTO word VALUES (return_word_id, lookup_token, null, null, null, lookup_country_code, 0);
  END IF;
  RETURN return_word_id;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION getorcreate_amenity(lookup_word TEXT, lookup_class text, lookup_type text)
  RETURNS INTEGER
  AS $$
DECLARE
  lookup_token TEXT;
  return_word_id INTEGER;
BEGIN
  lookup_token := ' '||trim(lookup_word);
  SELECT min(word_id) FROM word WHERE word_token = lookup_token and class=lookup_class and type = lookup_type into return_word_id;
  IF return_word_id IS NULL THEN
    return_word_id := nextval('seq_word');
    INSERT INTO word VALUES (return_word_id, lookup_token, null, lookup_class, lookup_type, null, 0);
  END IF;
  RETURN return_word_id;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION getorcreate_amenityoperator(lookup_word TEXT, lookup_class text, lookup_type text, op text)
  RETURNS INTEGER
  AS $$
DECLARE
  lookup_token TEXT;
  return_word_id INTEGER;
BEGIN
  lookup_token := ' '||trim(lookup_word);
  SELECT min(word_id) FROM word WHERE word_token = lookup_token and class=lookup_class and type = lookup_type and operator = op into return_word_id;
  IF return_word_id IS NULL THEN
    return_word_id := nextval('seq_word');
    INSERT INTO word VALUES (return_word_id, lookup_token, null, lookup_class, lookup_type, null, 0, op);
  END IF;
  RETURN return_word_id;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION getorcreate_name_id(lookup_word TEXT, src_word TEXT) 
  RETURNS INTEGER
  AS $$
DECLARE
  lookup_token TEXT;
  nospace_lookup_token TEXT;
  return_word_id INTEGER;
BEGIN
  lookup_token := ' '||trim(lookup_word);
  SELECT min(word_id) FROM word WHERE word_token = lookup_token and class is null and type is null into return_word_id;
  IF return_word_id IS NULL THEN
    return_word_id := nextval('seq_word');
    INSERT INTO word VALUES (return_word_id, lookup_token, src_word, null, null, null, 0);
--    nospace_lookup_token := replace(replace(lookup_token, '-',''), ' ','');
--    IF ' '||nospace_lookup_token != lookup_token THEN
--      INSERT INTO word VALUES (return_word_id, '-'||nospace_lookup_token, null, src_word, null, null, null, 0, null);
--    END IF;
  END IF;
  RETURN return_word_id;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION getorcreate_name_id(lookup_word TEXT) 
  RETURNS INTEGER
  AS $$
DECLARE
BEGIN
  RETURN getorcreate_name_id(lookup_word, '');
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_word_id(lookup_word TEXT) 
  RETURNS INTEGER
  AS $$
DECLARE
  lookup_token TEXT;
  return_word_id INTEGER;
BEGIN
  lookup_token := trim(lookup_word);
  SELECT min(word_id) FROM word WHERE word_token = lookup_token and class is null and type is null into return_word_id;
  RETURN return_word_id;
END;
$$
LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION get_name_id(lookup_word TEXT) 
  RETURNS INTEGER
  AS $$
DECLARE
  lookup_token TEXT;
  return_word_id INTEGER;
BEGIN
  lookup_token := ' '||trim(lookup_word);
  SELECT min(word_id) FROM word WHERE word_token = lookup_token and class is null and type is null into return_word_id;
  RETURN return_word_id;
END;
$$
LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION get_name_ids(lookup_word TEXT)
  RETURNS INTEGER[]
  AS $$
DECLARE
  lookup_token TEXT;
  return_word_ids INTEGER[];
BEGIN
  lookup_token := ' '||trim(lookup_word);
  SELECT array_agg(word_id) FROM word WHERE word_token = lookup_token and class is null and type is null into return_word_ids;
  RETURN return_word_ids;
END;
$$
LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION array_merge(a INTEGER[], b INTEGER[])
  RETURNS INTEGER[]
  AS $$
DECLARE
  i INTEGER;
  r INTEGER[];
BEGIN
  IF array_upper(a, 1) IS NULL THEN
    RETURN b;
  END IF;
  IF array_upper(b, 1) IS NULL THEN
    RETURN a;
  END IF;
  r := a;
  FOR i IN 1..array_upper(b, 1) LOOP  
    IF NOT (ARRAY[b[i]] <@ r) THEN
      r := r || b[i];
    END IF;
  END LOOP;
  RETURN r;
END;
$$
LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION create_country(src HSTORE, lookup_country_code varchar(2)) RETURNS VOID
  AS $$
DECLARE
  s TEXT;
  w INTEGER;
  words TEXT[];
  item RECORD;
  j INTEGER;
BEGIN
  FOR item IN SELECT (each(src)).* LOOP

    s := make_standard_name(item.value);
    w := getorcreate_country(s, lookup_country_code);

    words := regexp_split_to_array(item.value, E'[,;()]');
    IF array_upper(words, 1) != 1 THEN
      FOR j IN 1..array_upper(words, 1) LOOP
        s := make_standard_name(words[j]);
        IF s != '' THEN
          w := getorcreate_country(s, lookup_country_code);
        END IF;
      END LOOP;
    END IF;
  END LOOP;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION make_keywords(src HSTORE) RETURNS INTEGER[]
  AS $$
DECLARE
  result INTEGER[];
  s TEXT;
  w INTEGER;
  words TEXT[];
  item RECORD;
  j INTEGER;
BEGIN
  result := '{}'::INTEGER[];

  FOR item IN SELECT (each(src)).* LOOP

    s := make_standard_name(item.value);

    w := getorcreate_name_id(s, item.value);

    IF not(ARRAY[w] <@ result) THEN
      result := result || w;
    END IF;

    w := getorcreate_word_id(s);

    IF w IS NOT NULL AND NOT (ARRAY[w] <@ result) THEN
      result := result || w;
    END IF;

    words := string_to_array(s, ' ');
    IF array_upper(words, 1) IS NOT NULL THEN
      FOR j IN 1..array_upper(words, 1) LOOP
        IF (words[j] != '') THEN
          w = getorcreate_word_id(words[j]);
          IF w IS NOT NULL AND NOT (ARRAY[w] <@ result) THEN
            result := result || w;
          END IF;
        END IF;
      END LOOP;
    END IF;

    words := regexp_split_to_array(item.value, E'[,;()]');
    IF array_upper(words, 1) != 1 THEN
      FOR j IN 1..array_upper(words, 1) LOOP
        s := make_standard_name(words[j]);
        IF s != '' THEN
          w := getorcreate_word_id(s);
          IF w IS NOT NULL AND NOT (ARRAY[w] <@ result) THEN
            result := result || w;
          END IF;
        END IF;
      END LOOP;
    END IF;

    s := regexp_replace(item.value, '市$', '');
    IF s != item.value THEN
      s := make_standard_name(s);
      IF s != '' THEN
        w := getorcreate_name_id(s, item.value);
        IF NOT (ARRAY[w] <@ result) THEN
          result := result || w;
        END IF;
      END IF;
    END IF;

  END LOOP;

  RETURN result;
END;
$$
LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION make_keywords(src TEXT) RETURNS INTEGER[]
  AS $$
DECLARE
  result INTEGER[];
  s TEXT;
  w INTEGER;
  words TEXT[];
  i INTEGER;
  j INTEGER;
BEGIN
  result := '{}'::INTEGER[];

  s := make_standard_name(src);
  w := getorcreate_name_id(s, src);

  IF NOT (ARRAY[w] <@ result) THEN
    result := result || w;
  END IF;

  w := getorcreate_word_id(s);

  IF w IS NOT NULL AND NOT (ARRAY[w] <@ result) THEN
    result := result || w;
  END IF;

  words := string_to_array(s, ' ');
  IF array_upper(words, 1) IS NOT NULL THEN
    FOR j IN 1..array_upper(words, 1) LOOP
      IF (words[j] != '') THEN
        w = getorcreate_word_id(words[j]);
        IF w IS NOT NULL AND NOT (ARRAY[w] <@ result) THEN
          result := result || w;
        END IF;
      END IF;
    END LOOP;
  END IF;

  words := regexp_split_to_array(src, E'[,;()]');
  IF array_upper(words, 1) != 1 THEN
    FOR j IN 1..array_upper(words, 1) LOOP
      s := make_standard_name(words[j]);
      IF s != '' THEN
        w := getorcreate_word_id(s);
        IF w IS NOT NULL AND NOT (ARRAY[w] <@ result) THEN
          result := result || w;
        END IF;
      END IF;
    END LOOP;
  END IF;

  s := regexp_replace(src, '市$', '');
  IF s != src THEN
    s := make_standard_name(s);
    IF s != '' THEN
      w := getorcreate_name_id(s, src);
      IF NOT (ARRAY[w] <@ result) THEN
        result := result || w;
      END IF;
    END IF;
  END IF;

  RETURN result;
END;
$$
LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION get_country_code(place geometry) RETURNS TEXT
  AS $$
DECLARE
  place_centre GEOMETRY;
  nearcountry RECORD;
BEGIN
  place_centre := ST_PointOnSurface(place);

--DEBUG: RAISE WARNING 'get_country_code, start: %', ST_AsText(place_centre);

  -- Try for a OSM polygon
  FOR nearcountry IN select country_code from location_area_country where country_code is not null and not isguess and st_covers(geometry, place_centre) limit 1
  LOOP
    RETURN nearcountry.country_code;
  END LOOP;

--DEBUG: RAISE WARNING 'osm fallback: %', ST_AsText(place_centre);

  -- Try for OSM fallback data
  -- The order is to deal with places like HongKong that are 'states' within another polygon
  FOR nearcountry IN select country_code from country_osm_grid where st_covers(geometry, place_centre) order by area asc limit 1
  LOOP
    RETURN nearcountry.country_code;
  END LOOP;

--DEBUG: RAISE WARNING 'natural earth: %', ST_AsText(place_centre);

  -- Natural earth data
  FOR nearcountry IN select country_code from country_naturalearthdata where st_covers(geometry, place_centre) limit 1
  LOOP
    RETURN nearcountry.country_code;
  END LOOP;

--DEBUG: RAISE WARNING 'near osm fallback: %', ST_AsText(place_centre);

  -- 
  FOR nearcountry IN select country_code from country_osm_grid where st_dwithin(geometry, place_centre, 0.5) order by st_distance(geometry, place_centre) asc, area asc limit 1
  LOOP
    RETURN nearcountry.country_code;
  END LOOP;

--DEBUG: RAISE WARNING 'near natural earth: %', ST_AsText(place_centre);

  -- Natural earth data 
  FOR nearcountry IN select country_code from country_naturalearthdata where st_dwithin(geometry, place_centre, 0.5) limit 1
  LOOP
    RETURN nearcountry.country_code;
  END LOOP;

  RETURN NULL;
END;
$$
LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION get_country_language_code(search_country_code VARCHAR(2)) RETURNS TEXT
  AS $$
DECLARE
  nearcountry RECORD;
BEGIN
  FOR nearcountry IN select distinct country_default_language_code from country_name where country_code = search_country_code limit 1
  LOOP
    RETURN lower(nearcountry.country_default_language_code);
  END LOOP;
  RETURN NULL;
END;
$$
LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION get_country_language_codes(search_country_code VARCHAR(2)) RETURNS TEXT[]
  AS $$
DECLARE
  nearcountry RECORD;
BEGIN
  FOR nearcountry IN select country_default_language_codes from country_name where country_code = search_country_code limit 1
  LOOP
    RETURN lower(nearcountry.country_default_language_codes);
  END LOOP;
  RETURN NULL;
END;
$$
LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION get_partition(in_country_code VARCHAR(10)) RETURNS INTEGER
  AS $$
DECLARE
  nearcountry RECORD;
BEGIN
  FOR nearcountry IN select partition from country_name where country_code = in_country_code
  LOOP
    RETURN nearcountry.partition;
  END LOOP;
  RETURN 0;
END;
$$
LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION delete_location(OLD_place_id BIGINT) RETURNS BOOLEAN
  AS $$
DECLARE
BEGIN
  DELETE FROM location_area where place_id = OLD_place_id;
-- TODO:location_area
  RETURN true;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION add_location(
    place_id BIGINT,
    country_code varchar(2),
    partition INTEGER,
    keywords INTEGER[],
    rank_search INTEGER,
    rank_address INTEGER,
    geometry GEOMETRY
  ) 
  RETURNS BOOLEAN
  AS $$
DECLARE
  locationid INTEGER;
  isarea BOOLEAN;
  centroid GEOMETRY;
  diameter FLOAT;
  x BOOLEAN;
  splitGeom RECORD;
  secgeo GEOMETRY;
BEGIN

  IF rank_search > 25 THEN
    RAISE EXCEPTION 'Adding location with rank > 25 (% rank %)', place_id, rank_search;
  END IF;

--  RAISE WARNING 'Adding location with rank > 25 (% rank %)', place_id, rank_search;

  x := deleteLocationArea(partition, place_id, rank_search);

  isarea := false;
  IF (ST_GeometryType(geometry) in ('ST_Polygon','ST_MultiPolygon') AND ST_IsValid(geometry)) THEN

    isArea := true;
    centroid := ST_Centroid(geometry);

    FOR secgeo IN select split_geometry(geometry) AS geom LOOP
      x := insertLocationAreaLarge(partition, place_id, country_code, keywords, rank_search, rank_address, false, centroid, secgeo);
    END LOOP;

  ELSE

    diameter := 0.02;
    IF rank_address = 0 THEN
      diameter := 0.02;
    ELSEIF rank_search <= 14 THEN
      diameter := 1.2;
    ELSEIF rank_search <= 15 THEN
      diameter := 1;
    ELSEIF rank_search <= 16 THEN
      diameter := 0.5;
    ELSEIF rank_search <= 17 THEN
      diameter := 0.2;
    ELSEIF rank_search <= 21 THEN
      diameter := 0.05;
    ELSEIF rank_search = 25 THEN
      diameter := 0.005;
    END IF;

--    RAISE WARNING 'adding % diameter %', place_id, diameter;

    secgeo := ST_Buffer(geometry, diameter);
    x := insertLocationAreaLarge(partition, place_id, country_code, keywords, rank_search, rank_address, true, ST_Centroid(geometry), secgeo);

  END IF;

  RETURN true;
END;
$$
LANGUAGE plpgsql;



-- find the parant road of an interpolation
CREATE OR REPLACE FUNCTION get_interpolation_parent(wayid BIGINT, street TEXT, place TEXT,
                                                    partition INTEGER, centroid GEOMETRY, geom GEOMETRY)
RETURNS BIGINT AS $$
DECLARE
  addr_street TEXT;
  addr_place TEXT;
  parent_place_id BIGINT;
  address_street_word_ids INTEGER[];

  waynodes BIGINT[];

  location RECORD;
BEGIN
  addr_street = street;
  addr_place = place;

  IF addr_street is null and addr_place is null THEN
    select nodes from planet_osm_ways where id = wayid INTO waynodes;
    FOR location IN SELECT placex.street, placex.addr_place from placex 
                    where osm_type = 'N' and osm_id = ANY(waynodes)
                          and (placex.street is not null or placex.addr_place is not null)
                          and indexed_status < 100
                    limit 1 LOOP
      addr_street = location.street;
      addr_place = location.addr_place;
    END LOOP;
  END IF;

  IF addr_street IS NOT NULL THEN
    address_street_word_ids := get_name_ids(make_standard_name(addr_street));
    IF address_street_word_ids IS NOT NULL THEN
      FOR location IN SELECT place_id from getNearestNamedRoadFeature(partition, centroid, address_street_word_ids) LOOP
        parent_place_id := location.place_id;
      END LOOP;
    END IF;
  END IF;

  IF parent_place_id IS NULL AND addr_place IS NOT NULL THEN
    address_street_word_ids := get_name_ids(make_standard_name(addr_place));
    IF address_street_word_ids IS NOT NULL THEN
      FOR location IN SELECT place_id from getNearestNamedPlaceFeature(partition, centroid, address_street_word_ids) LOOP
        parent_place_id := location.place_id;
      END LOOP;
    END IF;
  END IF;

  IF parent_place_id is null THEN
    FOR location IN SELECT place_id FROM placex
        WHERE ST_DWithin(geom, placex.geometry, 0.001) and placex.rank_search = 26
        ORDER BY (ST_distance(placex.geometry, ST_LineInterpolatePoint(geom,0))+
                  ST_distance(placex.geometry, ST_LineInterpolatePoint(geom,0.5))+
                  ST_distance(placex.geometry, ST_LineInterpolatePoint(geom,1))) ASC limit 1
    LOOP
      parent_place_id := location.place_id;
    END LOOP;
  END IF;

  IF parent_place_id is null THEN
    RETURN 0;
  END IF;

  RETURN parent_place_id;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_interpolation(wayid BIGINT, interpolationtype TEXT,
                                                parent_id BIGINT, partition INTEGER,
                                                country_code TEXT,  geometry_sector INTEGER,
                                                defpostalcode TEXT, geom GEOMETRY) RETURNS INTEGER
  AS $$
DECLARE

  newpoints INTEGER;
  waynodes BIGINT[];
  nodeid BIGINT;
  prevnode RECORD;
  nextnode RECORD;
  startnumber INTEGER;
  endnumber INTEGER;
  stepsize INTEGER;
  orginalstartnumber INTEGER;
  originalnumberrange INTEGER;
  housenum INTEGER;
  linegeo GEOMETRY;
  splitline GEOMETRY;
  sectiongeo GEOMETRY;
  pointgeo GEOMETRY;

BEGIN
  delete from placex where osm_type = 'W' and osm_id = wayid
                                          and class = 'place' and type = 'address';

  IF interpolationtype = 'odd' OR interpolationtype = 'even' THEN
    stepsize := 2;
  ELSEIF interpolationtype = 'all' THEN
    stepsize := 1;
  ELSEIF interpolationtype ~ '^\d+$' THEN
    stepsize := interpolationtype::INTEGER;
  ELSE
    RETURN 0;
  END IF;

  select nodes from planet_osm_ways where id = wayid INTO waynodes;

  IF array_upper(waynodes, 1) IS NULL THEN
    RETURN 0;
  END IF;

  linegeo := geom;
  startnumber := NULL;
  newpoints := 0;

  FOR nodeidpos in 1..array_upper(waynodes, 1) LOOP

    -- If there is a place of a type other than place/house, use that because
    -- it is guaranteed to be the original node. For place/house types use the
    -- one with the smallest id because the original node was created first.
    -- Ignore all nodes marked for deletion. (Might happen when the type changes.)
    select * from placex where osm_type = 'N' and osm_id = waynodes[nodeidpos]::BIGINT
                               and indexed_status < 100 and housenumber is not NULL
                         order by (type = 'address'),place_id limit 1 INTO nextnode;
    IF nextnode.place_id IS NOT NULL THEN

        IF nodeidpos > 1 and nodeidpos < array_upper(waynodes, 1) THEN
          -- Make sure that the point is actually on the line. That might
          -- be a bit paranoid but ensures that the algorithm still works
          -- should osm2pgsql attempt to repair geometries.
          splitline := split_line_on_node(linegeo, nextnode.geometry);
          sectiongeo := ST_GeometryN(splitline, 1);
          linegeo := ST_GeometryN(splitline, 2);
        ELSE
          sectiongeo = linegeo;
        END IF;
        endnumber := substring(nextnode.housenumber,'[0-9]+')::integer;

        IF startnumber IS NOT NULL AND endnumber IS NOT NULL
           AND @(startnumber - endnumber) < 1000 AND startnumber != endnumber
           AND ST_GeometryType(sectiongeo) = 'ST_LineString' THEN

          IF (startnumber > endnumber) THEN
            housenum := endnumber;
            endnumber := startnumber;
            startnumber := housenum;
            sectiongeo := ST_Reverse(sectiongeo);
          END IF;
          orginalstartnumber := startnumber;
          originalnumberrange := endnumber - startnumber;

          startnumber := startnumber + stepsize;
          -- correct for odd/even
          IF (interpolationtype = 'odd' AND startnumber%2 = 0)
             OR (interpolationtype = 'even' AND startnumber%2 = 1) THEN
            startnumber := startnumber - 1;
          END IF;
          endnumber := endnumber - 1;

          -- keep for compatibility with previous versions
          delete from placex where osm_type = 'N' and osm_id = prevnode.osm_id
                               and place_id != prevnode.place_id and class = 'place'
                               and type = 'house';
          FOR housenum IN startnumber..endnumber BY stepsize LOOP
            pointgeo := ST_LineInterpolatePoint(sectiongeo, (housenum::float-orginalstartnumber::float)/originalnumberrange::float);
            insert into placex (place_id, partition, osm_type, osm_id,
                                class, type, admin_level, housenumber,
                                postcode,
                                country_code, parent_place_id, rank_address, rank_search,
                                indexed_status, indexed_date, geometry_sector,
                                calculated_country_code, centroid, geometry)
              values (nextval('seq_place'), partition, 'W', wayid,
                      'place', 'address', prevnode.admin_level, housenum,
                      coalesce(prevnode.postcode, defpostalcode),
                      prevnode.country_code, parent_id, 30, 30,
                      0, now(), geometry_sector, country_code,
                      pointgeo, pointgeo);
            newpoints := newpoints + 1;
--RAISE WARNING 'interpolation number % % ',prevnode.place_id,housenum;
          END LOOP;
        END IF;

        -- early break if we are out of line string,
        -- might happen when a line string loops back on itself
        IF ST_GeometryType(linegeo) != 'ST_LineString' THEN
            RETURN newpoints;
        END IF;

        startnumber := substring(nextnode.housenumber,'[0-9]+')::integer;
        prevnode := nextnode;
    END IF;
  END LOOP;

--RAISE WARNING 'interpolation points % ',newpoints;

  RETURN newpoints;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION placex_insert() RETURNS TRIGGER
  AS $$
DECLARE
  i INTEGER;
  postcode TEXT;
  result BOOLEAN;
  country_code VARCHAR(2);
  default_language VARCHAR(10);
  diameter FLOAT;
  classtable TEXT;
BEGIN
  --DEBUG: RAISE WARNING '% %',NEW.osm_type,NEW.osm_id;

  -- ignore interpolated addresses
  IF NEW.class = 'place' and NEW.type = 'address' THEN
    RETURN NEW;
  END IF;

  IF ST_IsEmpty(NEW.geometry) OR NOT ST_IsValid(NEW.geometry) OR ST_X(ST_Centroid(NEW.geometry))::text in ('NaN','Infinity','-Infinity') OR ST_Y(ST_Centroid(NEW.geometry))::text in ('NaN','Infinity','-Infinity') THEN  
    -- block all invalid geometary - just not worth the risk.  seg faults are causing serious problems.
    RAISE WARNING 'invalid geometry %',NEW.osm_id;
    RETURN NULL;
  END IF;

  --DEBUG: RAISE WARNING '% % % %',NEW.osm_type,NEW.osm_id,NEW.class,NEW.type;

  NEW.place_id := nextval('seq_place');
  NEW.indexed_status := 1; --STATUS_NEW

  NEW.calculated_country_code := lower(get_country_code(NEW.geometry));

  NEW.partition := get_partition(NEW.calculated_country_code);
  NEW.geometry_sector := geometry_sector(NEW.partition, NEW.geometry);

  -- copy 'name' to or from the default language (if there is a default language)
  IF NEW.name is not null AND array_upper(akeys(NEW.name),1) > 1 THEN
    default_language := get_country_language_code(NEW.calculated_country_code);
    IF default_language IS NOT NULL THEN
      IF NEW.name ? 'name' AND NOT NEW.name ? ('name:'||default_language) THEN
        NEW.name := NEW.name || hstore(('name:'||default_language), (NEW.name -> 'name'));
      ELSEIF NEW.name ? ('name:'||default_language) AND NOT NEW.name ? 'name' THEN
        NEW.name := NEW.name || hstore('name', (NEW.name -> ('name:'||default_language)));
      END IF;
    END IF;
  END IF;

  IF NEW.admin_level > 15 THEN
    NEW.admin_level := 15;
  END IF;

  IF NEW.housenumber IS NOT NULL THEN
    i := getorcreate_housenumber_id(make_standard_name(NEW.housenumber));
  END IF;

  IF NEW.osm_type = 'X' THEN
    -- E'X'ternal records should already be in the right format so do nothing
  ELSE
    NEW.rank_search := 30;
    NEW.rank_address := NEW.rank_search;

    -- By doing in postgres we have the country available to us - currently only used for postcode
    IF NEW.class in ('place','boundary') AND NEW.type in ('postcode','postal_code') THEN

        IF NEW.postcode IS NULL THEN
            -- most likely just a part of a multipolygon postcode boundary, throw it away
            RETURN NULL;
        END IF;

        NEW.name := hstore('ref', NEW.postcode);

        IF NEW.calculated_country_code = 'gb' THEN

          IF NEW.postcode ~ '^([A-Z][A-Z]?[0-9][0-9A-Z]? [0-9][A-Z][A-Z])$' THEN
            NEW.rank_search := 25;
            NEW.rank_address := 5;
          ELSEIF NEW.postcode ~ '^([A-Z][A-Z]?[0-9][0-9A-Z]? [0-9])$' THEN
            NEW.rank_search := 23;
            NEW.rank_address := 5;
          ELSEIF NEW.postcode ~ '^([A-Z][A-Z]?[0-9][0-9A-Z])$' THEN
            NEW.rank_search := 21;
            NEW.rank_address := 5;
          END IF;

        ELSEIF NEW.calculated_country_code = 'sg' THEN

          IF NEW.postcode ~ '^([0-9]{6})$' THEN
            NEW.rank_search := 25;
            NEW.rank_address := 11;
          END IF;

        ELSEIF NEW.calculated_country_code = 'de' THEN

          IF NEW.postcode ~ '^([0-9]{5})$' THEN
            NEW.rank_search := 21;
            NEW.rank_address := 11;
          END IF;

        ELSE
          -- Guess at the postcode format and coverage (!)
          IF upper(NEW.postcode) ~ '^[A-Z0-9]{1,5}$' THEN -- Probably too short to be very local
            NEW.rank_search := 21;
            NEW.rank_address := 11;
          ELSE
            -- Does it look splitable into and area and local code?
            postcode := substring(upper(NEW.postcode) from '^([- :A-Z0-9]+)([- :][A-Z0-9]+)$');

            IF postcode IS NOT NULL THEN
              NEW.rank_search := 25;
              NEW.rank_address := 11;
            ELSEIF NEW.postcode ~ '^[- :A-Z0-9]{6,}$' THEN
              NEW.rank_search := 21;
              NEW.rank_address := 11;
            END IF;
          END IF;
        END IF;

    ELSEIF NEW.class = 'place' THEN
      IF NEW.type in ('continent') THEN
        NEW.rank_search := 2;
        NEW.rank_address := NEW.rank_search;
        NEW.calculated_country_code := NULL;
      ELSEIF NEW.type in ('sea') THEN
        NEW.rank_search := 2;
        NEW.rank_address := 0;
        NEW.calculated_country_code := NULL;
      ELSEIF NEW.type in ('country') THEN
        NEW.rank_search := 4;
        NEW.rank_address := NEW.rank_search;
      ELSEIF NEW.type in ('state') THEN
        NEW.rank_search := 8;
        NEW.rank_address := NEW.rank_search;
      ELSEIF NEW.type in ('region') THEN
        NEW.rank_search := 18; -- dropped from previous value of 10
        NEW.rank_address := 0; -- So badly miss-used that better to just drop it!
      ELSEIF NEW.type in ('county') THEN
        NEW.rank_search := 12;
        NEW.rank_address := NEW.rank_search;
      ELSEIF NEW.type in ('city') THEN
        NEW.rank_search := 16;
        NEW.rank_address := NEW.rank_search;
      ELSEIF NEW.type in ('island') THEN
        NEW.rank_search := 17;
        NEW.rank_address := 0;
      ELSEIF NEW.type in ('town') THEN
        NEW.rank_search := 18;
        NEW.rank_address := 16;
      ELSEIF NEW.type in ('village','hamlet','municipality','district','unincorporated_area','borough') THEN
        NEW.rank_search := 19;
        NEW.rank_address := 16;
      ELSEIF NEW.type in ('suburb','croft','subdivision','isolated_dwelling') THEN
        NEW.rank_search := 20;
        NEW.rank_address := NEW.rank_search;
      ELSEIF NEW.type in ('farm','locality','islet','mountain_pass') THEN
        NEW.rank_search := 20;
        NEW.rank_address := 0;
        -- Irish townlands, tagged as place=locality and locality=townland
        IF (NEW.extratags -> 'locality') = 'townland' THEN
          NEW.rank_address := 20;
        END IF;
      ELSEIF NEW.type in ('neighbourhood') THEN
        NEW.rank_search := 22;
        NEW.rank_address := 22;
      ELSEIF NEW.type in ('house','building') THEN
        NEW.rank_search := 30;
        NEW.rank_address := NEW.rank_search;
      ELSEIF NEW.type in ('houses') THEN
        -- can't guarantee all required nodes loaded yet due to caching in osm2pgsql
        NEW.rank_search := 28;
        NEW.rank_address := 0;
      END IF;

    ELSEIF NEW.class = 'boundary' THEN
      IF ST_GeometryType(NEW.geometry) NOT IN ('ST_Polygon','ST_MultiPolygon') THEN
--        RAISE WARNING 'invalid boundary %',NEW.osm_id;
        return NULL;
      END IF;
      NEW.rank_search := NEW.admin_level * 2;
      IF NEW.type = 'administrative' THEN
        NEW.rank_address := NEW.rank_search;
      ELSE
        NEW.rank_address := 0;
      END IF;
    ELSEIF NEW.class = 'landuse' AND ST_GeometryType(NEW.geometry) in ('ST_Polygon','ST_MultiPolygon') THEN
      NEW.rank_search := 22;
      IF NEW.type in ('residential', 'farm', 'farmyard', 'industrial', 'commercial', 'allotments', 'retail') THEN
        NEW.rank_address := NEW.rank_search;
      ELSE
        NEW.rank_address := 0;
      END IF;
    ELSEIF NEW.class = 'natural' and NEW.type in ('peak','volcano','mountain_range') THEN
      NEW.rank_search := 18;
      NEW.rank_address := 0;
    ELSEIF NEW.class = 'natural' and NEW.type = 'sea' THEN
      NEW.rank_search := 4;
      NEW.rank_address := NEW.rank_search;
    -- any feature more than 5 square miles is probably worth indexing
    ELSEIF ST_GeometryType(NEW.geometry) in ('ST_Polygon','ST_MultiPolygon') AND ST_Area(NEW.geometry) > 0.1 THEN
      NEW.rank_search := 22;
      NEW.rank_address := 0;
    ELSEIF NEW.class = 'railway' AND NEW.type in ('rail') THEN
      RETURN NULL;
    ELSEIF NEW.class = 'waterway' THEN
      IF NEW.osm_type = 'R' THEN
        NEW.rank_search := 16;
      ELSE
        NEW.rank_search := 17;
      END IF;
      NEW.rank_address := 0;
    ELSEIF NEW.class = 'highway' AND NEW.osm_type != 'N' AND NEW.type in ('service','cycleway','path','footway','steps','bridleway','motorway_link','primary_link','trunk_link','secondary_link','tertiary_link') THEN
      NEW.rank_search := 27;
      NEW.rank_address := NEW.rank_search;
    ELSEIF NEW.class = 'highway' AND NEW.osm_type != 'N' THEN
      NEW.rank_search := 26;
      NEW.rank_address := NEW.rank_search;
    ELSEIF NEW.class = 'mountain_pass' THEN
        NEW.rank_search := 20;
        NEW.rank_address := 0;
    END IF;

  END IF;

  IF NEW.rank_search > 30 THEN
    NEW.rank_search := 30;
  END IF;

  IF NEW.rank_address > 30 THEN
    NEW.rank_address := 30;
  END IF;

  IF (NEW.extratags -> 'capital') = 'yes' THEN
    NEW.rank_search := NEW.rank_search - 1;
  END IF;

  -- a country code make no sense below rank 4 (country)
  IF NEW.rank_search < 4 THEN
    NEW.calculated_country_code := NULL;
  END IF;

-- Block import below rank 22
--  IF NEW.rank_search > 22 THEN
--    RETURN NULL;
--  END IF;

  --DEBUG: RAISE WARNING 'placex_insert:END: % % % %',NEW.osm_type,NEW.osm_id,NEW.class,NEW.type;

  RETURN NEW; -- @DIFFUPDATES@ The following is not needed until doing diff updates, and slows the main index process down

  IF NEW.rank_address > 0 THEN
    IF (ST_GeometryType(NEW.geometry) in ('ST_Polygon','ST_MultiPolygon') AND ST_IsValid(NEW.geometry)) THEN
      -- Performance: We just can't handle re-indexing for country level changes
      IF st_area(NEW.geometry) < 1 THEN
        -- mark items within the geometry for re-indexing
  --    RAISE WARNING 'placex poly insert: % % % %',NEW.osm_type,NEW.osm_id,NEW.class,NEW.type;

        -- work around bug in postgis, this may have been fixed in 2.0.0 (see http://trac.osgeo.org/postgis/ticket/547)
        update placex set indexed_status = 2 where (st_covers(NEW.geometry, placex.geometry) OR ST_Intersects(NEW.geometry, placex.geometry)) 
         AND rank_search > NEW.rank_search and indexed_status = 0 and ST_geometrytype(placex.geometry) = 'ST_Point' and (rank_search < 28 or name is not null or (NEW.rank_search >= 16 and addr_place is not null));
        update placex set indexed_status = 2 where (st_covers(NEW.geometry, placex.geometry) OR ST_Intersects(NEW.geometry, placex.geometry)) 
         AND rank_search > NEW.rank_search and indexed_status = 0 and ST_geometrytype(placex.geometry) != 'ST_Point' and (rank_search < 28 or name is not null or (NEW.rank_search >= 16 and addr_place is not null));
      END IF;
    ELSE
      -- mark nearby items for re-indexing, where 'nearby' depends on the features rank_search and is a complete guess :(
      diameter := 0;
      -- 16 = city, anything higher than city is effectively ignored (polygon required!)
      IF NEW.type='postcode' THEN
        diameter := 0.05;
      ELSEIF NEW.rank_search < 16 THEN
        diameter := 0;
      ELSEIF NEW.rank_search < 18 THEN
        diameter := 0.1;
      ELSEIF NEW.rank_search < 20 THEN
        diameter := 0.05;
      ELSEIF NEW.rank_search = 21 THEN
        diameter := 0.001;
      ELSEIF NEW.rank_search < 24 THEN
        diameter := 0.02;
      ELSEIF NEW.rank_search < 26 THEN
        diameter := 0.002; -- 100 to 200 meters
      ELSEIF NEW.rank_search < 28 THEN
        diameter := 0.001; -- 50 to 100 meters
      END IF;
      IF diameter > 0 THEN
  --      RAISE WARNING 'placex point insert: % % % % %',NEW.osm_type,NEW.osm_id,NEW.class,NEW.type,diameter;
        IF NEW.rank_search >= 26 THEN
          -- roads may cause reparenting for >27 rank places
          update placex set indexed_status = 2 where indexed_status = 0 and rank_search > NEW.rank_search and ST_DWithin(placex.geometry, NEW.geometry, diameter);
        ELSEIF NEW.rank_search >= 16 THEN
          -- up to rank 16, street-less addresses may need reparenting
          update placex set indexed_status = 2 where indexed_status = 0 and rank_search > NEW.rank_search and ST_DWithin(placex.geometry, NEW.geometry, diameter) and (rank_search < 28 or name is not null or addr_place is not null);
        ELSE
          -- for all other places the search terms may change as well
          update placex set indexed_status = 2 where indexed_status = 0 and rank_search > NEW.rank_search and ST_DWithin(placex.geometry, NEW.geometry, diameter) and (rank_search < 28 or name is not null);
        END IF;
      END IF;
    END IF;
  END IF;


   -- add to tables for special search
   -- Note: won't work on initial import because the classtype tables
   -- do not yet exist. It won't hurt either.
  classtable := 'place_classtype_' || NEW.class || '_' || NEW.type;
  SELECT count(*)>0 FROM pg_tables WHERE tablename = classtable and schemaname = current_schema() INTO result;
  IF result THEN
    EXECUTE 'INSERT INTO ' || classtable::regclass || ' (place_id, centroid) VALUES ($1,$2)' 
    USING NEW.place_id, ST_Centroid(NEW.geometry);
  END IF;

  RETURN NEW;

END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION placex_update() RETURNS 
TRIGGER
  AS $$
DECLARE

  place_centroid GEOMETRY;

  search_maxdistance FLOAT[];
  search_mindistance FLOAT[];
  address_havelevel BOOLEAN[];

  i INTEGER;
  iMax FLOAT;
  location RECORD;
  way RECORD;
  relation RECORD;
  relation_members TEXT[];
  relMember RECORD;
  linkedplacex RECORD;
  search_diameter FLOAT;
  search_prevdiameter FLOAT;
  search_maxrank INTEGER;
  address_maxrank INTEGER;
  address_street_word_id INTEGER;
  address_street_word_ids INTEGER[];
  parent_place_id_rank BIGINT;
  
  isin TEXT[];
  isin_tokens INT[];

  location_rank_search INTEGER;
  location_distance FLOAT;
  location_parent GEOMETRY;
  location_isaddress BOOLEAN;
  location_keywords INTEGER[];

  default_language TEXT;
  name_vector INTEGER[];
  nameaddress_vector INTEGER[];

  linked_node_id BIGINT;

  result BOOLEAN;
BEGIN

  -- deferred delete
  IF OLD.indexed_status = 100 THEN
    --DEBUG: RAISE WARNING 'placex_update_delete % %',NEW.osm_type,NEW.osm_id;
    delete from placex where place_id = OLD.place_id;
    RETURN NULL;
  END IF;

  IF NEW.indexed_status != 0 OR OLD.indexed_status = 0 THEN
    RETURN NEW;
  END IF;

  -- ignore interpolated addresses
  IF NEW.class = 'place' and NEW.type = 'address' THEN
    RETURN NEW;
  END IF;

  --DEBUG: RAISE WARNING 'placex_update % %',NEW.osm_type,NEW.osm_id;

--RAISE WARNING '%',NEW.place_id;
--RAISE WARNING '%', NEW;

  IF NEW.class = 'place' AND NEW.type = 'postcodearea' THEN
    -- Silently do nothing
    RETURN NEW;
  END IF;

  -- TODO: this test is now redundant?
  IF OLD.indexed_status != 0 THEN

    NEW.indexed_date = now();

    result := deleteSearchName(NEW.partition, NEW.place_id);
    DELETE FROM place_addressline WHERE place_id = NEW.place_id;
    result := deleteRoad(NEW.partition, NEW.place_id);
    result := deleteLocationArea(NEW.partition, NEW.place_id, NEW.rank_search);
    UPDATE placex set linked_place_id = null where linked_place_id = NEW.place_id;

    IF NEW.linked_place_id is not null THEN
      RETURN NEW;
    END IF;

    -- Speed up searches - just use the centroid of the feature
    -- cheaper but less acurate
    place_centroid := ST_PointOnSurface(NEW.geometry);
    NEW.centroid := null;

    -- recalculate country and partition
    IF NEW.rank_search = 4 THEN
      -- for countries, believe the mapped country code,
      -- so that we remain in the right partition if the boundaries
      -- suddenly expand.
      NEW.partition := get_partition(lower(NEW.country_code));
      IF NEW.partition = 0 THEN
        NEW.calculated_country_code := lower(get_country_code(place_centroid));
        NEW.partition := get_partition(NEW.calculated_country_code);
      ELSE
        NEW.calculated_country_code := lower(NEW.country_code);
      END IF;
    ELSE
      IF NEW.rank_search > 4 THEN
        --NEW.calculated_country_code := lower(get_country_code(NEW.geometry, NEW.country_code));
        NEW.calculated_country_code := lower(get_country_code(place_centroid));
      ELSE
        NEW.calculated_country_code := NULL;
      END IF;
      NEW.partition := get_partition(NEW.calculated_country_code);
    END IF;
    NEW.geometry_sector := geometry_sector(NEW.partition, place_centroid);

    -- interpolations
    IF NEW.class = 'place' AND NEW.type = 'houses'THEN
      IF NEW.osm_type = 'W' and ST_GeometryType(NEW.geometry) = 'ST_LineString' THEN
        NEW.parent_place_id := get_interpolation_parent(NEW.osm_id, NEW.street, NEW.addr_place,
                                                        NEW.partition, place_centroid, NEW.geometry);
        i := create_interpolation(NEW.osm_id, NEW.housenumber, NEW.parent_place_id,
                                  NEW.partition, NEW.calculated_country_code,
                                  NEW.geometry_sector, NEW.postcode, NEW.geometry);
      END IF;
      RETURN NEW;
    END IF;

    -- waterway ways are linked when they are part of a relation and have the same class/type
    IF NEW.osm_type = 'R' and NEW.class = 'waterway' THEN
        FOR relation_members IN select members from planet_osm_rels r where r.id = NEW.osm_id and r.parts != array[]::bigint[]
        LOOP
            FOR i IN 1..array_upper(relation_members, 1) BY 2 LOOP
                IF relation_members[i+1] in ('', 'main_stream', 'side_stream') AND substring(relation_members[i],1,1) = 'w' THEN
                  --DEBUG: RAISE WARNING 'waterway parent %, child %/%', NEW.osm_id, i, relation.members[i];
                  FOR linked_node_id IN SELECT place_id FROM placex
                    WHERE osm_type = 'W' and osm_id = substring(relation_members[i],2,200)::bigint
                    and class = NEW.class and type = NEW.type
                    and ( relation_members[i+1] != 'side_stream' or NEW.name->'name' = name->'name')
                  LOOP
                    UPDATE placex SET linked_place_id = NEW.place_id WHERE place_id = linked_node_id;
                  END LOOP;
                END IF;
            END LOOP;
        END LOOP;
    END IF;

    -- Adding ourselves to the list simplifies address calculations later
    INSERT INTO place_addressline VALUES (NEW.place_id, NEW.place_id, true, true, 0, NEW.rank_address); 

    -- What level are we searching from
    search_maxrank := NEW.rank_search;

    -- Thought this wasn't needed but when we add new languages to the country_name table
    -- we need to update the existing names
    IF NEW.name is not null AND array_upper(akeys(NEW.name),1) > 1 THEN
      default_language := get_country_language_code(NEW.calculated_country_code);
      IF default_language IS NOT NULL THEN
        IF NEW.name ? 'name' AND NOT NEW.name ? ('name:'||default_language) THEN
          NEW.name := NEW.name || hstore(('name:'||default_language), (NEW.name -> 'name'));
        ELSEIF NEW.name ? ('name:'||default_language) AND NOT NEW.name ? 'name' THEN
          NEW.name := NEW.name || hstore('name', (NEW.name -> ('name:'||default_language)));
        END IF;
      END IF;
    END IF;

    -- Initialise the name vector using our name
    name_vector := make_keywords(NEW.name);
    nameaddress_vector := '{}'::int[];

    FOR i IN 1..28 LOOP
      address_havelevel[i] := false;
    END LOOP;

    NEW.importance := null;
    select language||':'||title,importance from get_wikipedia_match(NEW.extratags, NEW.calculated_country_code) INTO NEW.wikipedia,NEW.importance;
    IF NEW.importance IS NULL THEN
      select language||':'||title,importance from wikipedia_article where osm_type = NEW.osm_type and osm_id = NEW.osm_id order by importance desc limit 1 INTO NEW.wikipedia,NEW.importance;
    END IF;

--RAISE WARNING 'before low level% %', NEW.place_id, NEW.rank_search;

    -- For low level elements we inherit from our parent road
    IF (NEW.rank_search > 27 OR (NEW.type = 'postcode' AND NEW.rank_search = 25)) THEN

--RAISE WARNING 'finding street for %', NEW;

      -- We won't get a better centroid, besides these places are too small to care
      NEW.centroid := place_centroid;

      NEW.parent_place_id := null;

      -- if we have a POI and there is no address information,
      -- see if we can get it from a surrounding building
      IF NEW.osm_type = 'N' AND NEW.street IS NULL AND NEW.addr_place IS NULL
         AND NEW.housenumber IS NULL THEN
        FOR location IN select * from placex where ST_Covers(geometry, place_centroid)
              and (housenumber is not null or street is not null or addr_place is not null)
              and rank_search > 28 AND ST_GeometryType(geometry) in ('ST_Polygon','ST_MultiPolygon')
              limit 1
        LOOP
          NEW.housenumber := location.housenumber;
          NEW.street := location.street;
          NEW.addr_place := location.addr_place;
        END LOOP;
      END IF;

      -- We have to find our parent road.
      -- Copy data from linked items (points on ways, addr:street links, relations)

      -- Is this object part of a relation?
        FOR relation IN select * from planet_osm_rels where parts @> ARRAY[NEW.osm_id] and members @> ARRAY[lower(NEW.osm_type)||NEW.osm_id]
        LOOP
          -- At the moment we only process one type of relation - associatedStreet
          IF relation.tags @> ARRAY['associatedStreet'] THEN
            FOR i IN 1..array_upper(relation.members, 1) BY 2 LOOP
              IF NEW.parent_place_id IS NULL AND relation.members[i+1] = 'street' THEN
--RAISE WARNING 'node in relation %',relation;
                SELECT place_id from placex where osm_type = 'W'
                  and osm_id = substring(relation.members[i],2,200)::bigint
                  and rank_search = 26 and name is not null INTO NEW.parent_place_id;
              END IF;
            END LOOP;
          END IF;
        END LOOP;


      -- Note that addr:street links can only be indexed once the street itself is indexed
       IF NEW.parent_place_id IS NULL AND NEW.street IS NOT NULL THEN
        address_street_word_ids := get_name_ids(make_standard_name(NEW.street));
        IF address_street_word_ids IS NOT NULL THEN
          FOR location IN SELECT * from getNearestNamedRoadFeature(NEW.partition, place_centroid, address_street_word_ids) LOOP
              NEW.parent_place_id := location.place_id;
          END LOOP;
        END IF;
      END IF;

      IF NEW.parent_place_id IS NULL AND NEW.addr_place IS NOT NULL THEN
        address_street_word_ids := get_name_ids(make_standard_name(NEW.addr_place));
        IF address_street_word_ids IS NOT NULL THEN
          FOR location IN SELECT * from getNearestNamedPlaceFeature(NEW.partition, place_centroid, address_street_word_ids) LOOP
            NEW.parent_place_id := location.place_id;
          END LOOP;
        END IF;
      END IF;

      IF NEW.parent_place_id IS NULL AND NEW.osm_type = 'N' THEN

--RAISE WARNING 'x1';
        -- Is this node part of a way?
        FOR location IN select p.* from placex p, planet_osm_ways w
           where p.osm_type = 'W' and p.rank_search >= 26
             and p.geometry && NEW.geometry and p.osm_id = w.id and NEW.osm_id = any(w.nodes)
        LOOP
--RAISE WARNING '%', location;
          -- Way IS a road then we are on it - that must be our road
          IF location.rank_search = 26 AND NEW.parent_place_id IS NULL THEN
--RAISE WARNING 'node in way that is a street %',location;
            NEW.parent_place_id := location.place_id;
          END IF;

          -- If this way is a street interpolation line then it is probably as good as we are going to get
          IF NEW.parent_place_id IS NULL AND location.class = 'place' and location.type='houses' THEN
            NEW.parent_place_id := location.parent_place_id;
          END IF;

          -- Is the WAY part of a relation
          IF NEW.parent_place_id IS NULL THEN
              FOR relation IN select * from planet_osm_rels where parts @> ARRAY[location.osm_id] and members @> ARRAY['w'||location.osm_id]
              LOOP
                -- At the moment we only process one type of relation - associatedStreet
                IF relation.tags @> ARRAY['associatedStreet'] AND array_upper(relation.members, 1) IS NOT NULL THEN
                  FOR i IN 1..array_upper(relation.members, 1) BY 2 LOOP
                    IF NEW.parent_place_id IS NULL AND relation.members[i+1] = 'street' THEN
    --RAISE WARNING 'node in way that is in a relation %',relation;
                      SELECT place_id from placex where osm_type='W' and osm_id = substring(relation.members[i],2,200)::bigint 
                        and rank_search = 26 and name is not null INTO NEW.parent_place_id;
                    END IF;
                  END LOOP;
                END IF;
              END LOOP;
          END IF;

          -- If the way mentions a street or place address, try that for parenting.
          IF NEW.parent_place_id IS NULL AND location.street IS NOT NULL THEN
            address_street_word_ids := get_name_ids(make_standard_name(location.street));
            IF address_street_word_ids IS NOT NULL THEN
              FOR linkedplacex IN SELECT place_id from getNearestNamedRoadFeature(NEW.partition, place_centroid, address_street_word_ids) LOOP
                  NEW.parent_place_id := linkedplacex.place_id;
              END LOOP;
            END IF;
          END IF;

          IF NEW.parent_place_id IS NULL AND location.addr_place IS NOT NULL THEN
            address_street_word_ids := get_name_ids(make_standard_name(location.addr_place));
            IF address_street_word_ids IS NOT NULL THEN
              FOR linkedplacex IN SELECT place_id from getNearestNamedPlaceFeature(NEW.partition, place_centroid, address_street_word_ids) LOOP
                NEW.parent_place_id := linkedplacex.place_id;
              END LOOP;
            END IF;
          END IF;

        END LOOP;

      END IF;

--RAISE WARNING 'x4 %',NEW.parent_place_id;
      -- Still nothing, just use the nearest road
      IF NEW.parent_place_id IS NULL THEN
        FOR location IN SELECT place_id FROM getNearestRoadFeature(NEW.partition, place_centroid) LOOP
          NEW.parent_place_id := location.place_id;
        END LOOP;
      END IF;

--return NEW;
--RAISE WARNING 'x6 %',NEW.parent_place_id;

      -- If we didn't find any road fallback to standard method
      IF NEW.parent_place_id IS NOT NULL THEN

        -- Get the details of the parent road
        select * from search_name where place_id = NEW.parent_place_id INTO location;
        NEW.calculated_country_code := location.country_code;

        -- Merge the postcode into the parent's address if necessary XXXX
        IF NEW.postcode IS NOT NULL THEN
          isin_tokens := '{}'::int[];
          address_street_word_id := getorcreate_word_id(make_standard_name(NEW.postcode));
          IF address_street_word_id is not null
             and not ARRAY[address_street_word_id] <@ location.nameaddress_vector THEN
             isin_tokens := isin_tokens || address_street_word_id;
          END IF;
          address_street_word_id := getorcreate_name_id(make_standard_name(NEW.postcode));
          IF address_street_word_id is not null
             and not ARRAY[address_street_word_id] <@ location.nameaddress_vector THEN
             isin_tokens := isin_tokens || address_street_word_id;
          END IF;
          IF isin_tokens != '{}'::int[] THEN
             UPDATE search_name
                SET nameaddress_vector = search_name.nameaddress_vector || isin_tokens
              WHERE place_id = NEW.parent_place_id;
          END IF;
        END IF;

--RAISE WARNING '%', NEW.name;
        -- If there is no name it isn't searchable, don't bother to create a search record
        IF NEW.name is NULL THEN
          return NEW;
        END IF;

        -- Merge address from parent
        nameaddress_vector := array_merge(nameaddress_vector, location.nameaddress_vector);
        nameaddress_vector := array_merge(nameaddress_vector, location.name_vector);

        -- Performance, it would be more acurate to do all the rest of the import
        -- process but it takes too long
        -- Just be happy with inheriting from parent road only

        IF NEW.rank_search <= 25 and NEW.rank_address > 0 THEN
          result := add_location(NEW.place_id, NEW.calculated_country_code, NEW.partition, name_vector, NEW.rank_search, NEW.rank_address, NEW.geometry);
        END IF;

        result := insertSearchName(NEW.partition, NEW.place_id, NEW.calculated_country_code, name_vector, nameaddress_vector, NEW.rank_search, NEW.rank_address, NEW.importance, place_centroid, NEW.geometry);

        return NEW;
      END IF;

    END IF;

-- RAISE WARNING '  INDEXING Started:';
-- RAISE WARNING '  INDEXING: %',NEW;

    IF NEW.osm_type = 'R' AND NEW.rank_search < 26 THEN

      -- see if we have any special relation members
      select members from planet_osm_rels where id = NEW.osm_id INTO relation_members;

-- RAISE WARNING 'get_osm_rel_members, label';
      IF relation_members IS NOT NULL THEN
        FOR relMember IN select get_osm_rel_members(relation_members,ARRAY['label']) as member LOOP

          FOR linkedPlacex IN select * from placex where osm_type = upper(substring(relMember.member,1,1))::char(1) 
            and osm_id = substring(relMember.member,2,10000)::bigint order by rank_search desc limit 1 LOOP

            -- If we don't already have one use this as the centre point of the geometry
            IF NEW.centroid IS NULL THEN
              NEW.centroid := coalesce(linkedPlacex.centroid,st_centroid(linkedPlacex.geometry));
            END IF;

            -- merge in the label name, re-init word vector
            IF NOT linkedPlacex.name IS NULL THEN
              NEW.name := linkedPlacex.name || NEW.name;
              name_vector := array_merge(name_vector, make_keywords(linkedPlacex.name));
            END IF;

            -- merge in extra tags
            NEW.extratags := hstore(linkedPlacex.class, linkedPlacex.type) || coalesce(linkedPlacex.extratags, ''::hstore) || coalesce(NEW.extratags, ''::hstore);

            -- mark the linked place (excludes from search results)
            UPDATE placex set linked_place_id = NEW.place_id where place_id = linkedPlacex.place_id;

            -- keep a note of the node id in case we need it for wikipedia in a bit
            linked_node_id := linkedPlacex.osm_id;
          END LOOP;

        END LOOP;

        IF NEW.centroid IS NULL THEN

          FOR relMember IN select get_osm_rel_members(relation_members,ARRAY['admin_center','admin_centre']) as member LOOP

            FOR linkedPlacex IN select * from placex where osm_type = upper(substring(relMember.member,1,1))::char(1) 
              and osm_id = substring(relMember.member,2,10000)::bigint order by rank_search desc limit 1 LOOP

              -- For an admin centre we also want a name match - still not perfect, for example 'new york, new york'
              -- But that can be fixed by explicitly setting the label in the data
              IF make_standard_name(NEW.name->'name') = make_standard_name(linkedPlacex.name->'name') 
                AND NEW.rank_address = linkedPlacex.rank_address THEN

                -- If we don't already have one use this as the centre point of the geometry
                IF NEW.centroid IS NULL THEN
                  NEW.centroid := coalesce(linkedPlacex.centroid,st_centroid(linkedPlacex.geometry));
                END IF;

                -- merge in the name, re-init word vector
                IF NOT linkedPlacex.name IS NULL THEN
                  NEW.name := linkedPlacex.name || NEW.name;
                  name_vector := make_keywords(NEW.name);
                END IF;

                -- merge in extra tags
                NEW.extratags := hstore(linkedPlacex.class, linkedPlacex.type) || coalesce(linkedPlacex.extratags, ''::hstore) || coalesce(NEW.extratags, ''::hstore);

                -- mark the linked place (excludes from search results)
                UPDATE placex set linked_place_id = NEW.place_id where place_id = linkedPlacex.place_id;

                -- keep a note of the node id in case we need it for wikipedia in a bit
                linked_node_id := linkedPlacex.osm_id;
              END IF;

            END LOOP;

          END LOOP;

        END IF;
      END IF;

    END IF;

    -- Name searches can be done for ways as well as relations
    IF NEW.osm_type in ('W','R') AND NEW.rank_search < 26 AND NEW.rank_address > 0 THEN

      -- not found one yet? how about doing a name search
      IF NEW.centroid IS NULL AND (NEW.name->'name') is not null and make_standard_name(NEW.name->'name') != '' THEN

        FOR linkedPlacex IN select placex.* from placex WHERE
          make_standard_name(name->'name') = make_standard_name(NEW.name->'name')
          AND placex.rank_address = NEW.rank_address
          AND placex.place_id != NEW.place_id
          AND placex.osm_type = 'N'::char(1) AND placex.rank_search < 26
          AND st_covers(NEW.geometry, placex.geometry)
        LOOP

          -- If we don't already have one use this as the centre point of the geometry
          IF NEW.centroid IS NULL THEN
            NEW.centroid := coalesce(linkedPlacex.centroid,st_centroid(linkedPlacex.geometry));
          END IF;

          -- merge in the name, re-init word vector
          NEW.name := linkedPlacex.name || NEW.name;
          name_vector := make_keywords(NEW.name);

          -- merge in extra tags
          NEW.extratags := hstore(linkedPlacex.class, linkedPlacex.type) || coalesce(linkedPlacex.extratags, ''::hstore) || coalesce(NEW.extratags, ''::hstore);

          -- mark the linked place (excludes from search results)
          UPDATE placex set linked_place_id = NEW.place_id where place_id = linkedPlacex.place_id;

          -- keep a note of the node id in case we need it for wikipedia in a bit
          linked_node_id := linkedPlacex.osm_id;
        END LOOP;
      END IF;

      IF NEW.centroid IS NOT NULL THEN
        place_centroid := NEW.centroid;
        -- Place might have had only a name tag before but has now received translations
        -- from the linked place. Make sure a name tag for the default language exists in
        -- this case. 
        IF NEW.name is not null AND array_upper(akeys(NEW.name),1) > 1 THEN
          default_language := get_country_language_code(NEW.calculated_country_code);
          IF default_language IS NOT NULL THEN
            IF NEW.name ? 'name' AND NOT NEW.name ? ('name:'||default_language) THEN
              NEW.name := NEW.name || hstore(('name:'||default_language), (NEW.name -> 'name'));
            ELSEIF NEW.name ? ('name:'||default_language) AND NOT NEW.name ? 'name' THEN
              NEW.name := NEW.name || hstore('name', (NEW.name -> ('name:'||default_language)));
            END IF;
          END IF;
        END IF;
      END IF;

      -- Did we gain a wikipedia tag in the process? then we need to recalculate our importance
      IF NEW.importance is null THEN
        select language||':'||title,importance from get_wikipedia_match(NEW.extratags, NEW.calculated_country_code) INTO NEW.wikipedia,NEW.importance;
      END IF;
      -- Still null? how about looking it up by the node id
      IF NEW.importance IS NULL THEN
        select language||':'||title,importance from wikipedia_article where osm_type = 'N'::char(1) and osm_id = linked_node_id order by importance desc limit 1 INTO NEW.wikipedia,NEW.importance;
      END IF;

    END IF;

    -- make sure all names are in the word table
    IF NEW.admin_level = 2 AND NEW.class = 'boundary' AND NEW.type = 'administrative' AND NEW.country_code IS NOT NULL THEN
      perform create_country(NEW.name, lower(NEW.country_code));
    END IF;

    NEW.parent_place_id = 0;
    parent_place_id_rank = 0;

    -- convert isin to array of tokenids
    isin_tokens := '{}'::int[];
    IF NEW.isin IS NOT NULL THEN
      isin := regexp_split_to_array(NEW.isin, E'[;,]');
      IF array_upper(isin, 1) IS NOT NULL THEN
        FOR i IN 1..array_upper(isin, 1) LOOP
          address_street_word_id := get_name_id(make_standard_name(isin[i]));
          IF address_street_word_id IS NOT NULL AND NOT(ARRAY[address_street_word_id] <@ isin_tokens) THEN
            nameaddress_vector := array_merge(nameaddress_vector, ARRAY[address_street_word_id]);
            isin_tokens := isin_tokens || address_street_word_id;
          END IF;

          -- merge word into address vector
          address_street_word_id := get_word_id(make_standard_name(isin[i]));
          IF address_street_word_id IS NOT NULL THEN
            nameaddress_vector := array_merge(nameaddress_vector, ARRAY[address_street_word_id]);
          END IF;
        END LOOP;
      END IF;
    END IF;
    IF NEW.postcode IS NOT NULL THEN
      isin := regexp_split_to_array(NEW.postcode, E'[;,]');
      IF array_upper(isin, 1) IS NOT NULL THEN
        FOR i IN 1..array_upper(isin, 1) LOOP
          address_street_word_id := get_name_id(make_standard_name(isin[i]));
          IF address_street_word_id IS NOT NULL AND NOT(ARRAY[address_street_word_id] <@ isin_tokens) THEN
            nameaddress_vector := array_merge(nameaddress_vector, ARRAY[address_street_word_id]);
            isin_tokens := isin_tokens || address_street_word_id;
          END IF;

          -- merge into address vector
          address_street_word_id := get_word_id(make_standard_name(isin[i]));
          IF address_street_word_id IS NOT NULL THEN
            nameaddress_vector := array_merge(nameaddress_vector, ARRAY[address_street_word_id]);
          END IF;
        END LOOP;
      END IF;
    END IF;

    -- for the USA we have an additional address table.  Merge in zip codes from there too
    IF NEW.rank_search = 26 AND NEW.calculated_country_code = 'us' THEN
      FOR location IN SELECT distinct postcode from location_property_tiger where parent_place_id = NEW.place_id LOOP
        address_street_word_id := get_name_id(make_standard_name(location.postcode));
        nameaddress_vector := array_merge(nameaddress_vector, ARRAY[address_street_word_id]);
        isin_tokens := isin_tokens || address_street_word_id;

        -- also merge in the single word version
        address_street_word_id := get_word_id(make_standard_name(location.postcode));
        nameaddress_vector := array_merge(nameaddress_vector, ARRAY[address_street_word_id]);
      END LOOP;
    END IF;

-- RAISE WARNING 'ISIN: %', isin_tokens;

    -- Process area matches
    location_rank_search := 0;
    location_distance := 0;
    location_parent := NULL;
    -- added ourself as address already
    address_havelevel[NEW.rank_address] := true;
    -- RAISE WARNING '  getNearFeatures(%,''%'',%,''%'')',NEW.partition, place_centroid, search_maxrank, isin_tokens;
    FOR location IN SELECT * from getNearFeatures(NEW.partition, place_centroid, search_maxrank, isin_tokens) LOOP

--RAISE WARNING '  AREA: %',location;

      IF location.rank_address != location_rank_search THEN
        location_rank_search := location.rank_address;
        IF location.isguess THEN
          location_distance := location.distance * 1.5;
        ELSE
          IF location.rank_address <= 12 THEN
            -- for county and above, if we have an area consider that exact
            -- (It would be nice to relax the constraint for places close to
            --  the boundary but we'd need the exact geometry for that. Too
            --  expensive.)
            location_distance = 0;
          ELSE
            -- Below county level remain slightly fuzzy.
            location_distance := location.distance * 0.5;
          END IF;
        END IF;
      ELSE
        CONTINUE WHEN location.keywords <@ location_keywords;
      END IF;

      IF location.distance < location_distance OR NOT location.isguess THEN
        location_keywords := location.keywords;

        location_isaddress := NOT address_havelevel[location.rank_address];
        IF location_isaddress AND location.isguess AND location_parent IS NOT NULL THEN
            location_isaddress := ST_Contains(location_parent,location.centroid);
        END IF;

        -- RAISE WARNING '% isaddress: %', location.place_id, location_isaddress;
        -- Add it to the list of search terms
        IF location.rank_search > 4 THEN
            nameaddress_vector := array_merge(nameaddress_vector, location.keywords::integer[]);
        END IF;
        INSERT INTO place_addressline VALUES (NEW.place_id, location.place_id, true, location_isaddress, location.distance, location.rank_address);

        IF location_isaddress THEN

          address_havelevel[location.rank_address] := true;
          IF NOT location.isguess THEN
            SELECT geometry FROM placex WHERE place_id = location.place_id INTO location_parent;
          END IF;

          IF location.rank_address > parent_place_id_rank THEN
            NEW.parent_place_id = location.place_id;
            parent_place_id_rank = location.rank_address;
          END IF;

        END IF;

--RAISE WARNING '  Terms: (%) %',location, nameaddress_vector;

      END IF;

    END LOOP;

    -- try using the isin value to find parent places
    IF array_upper(isin_tokens, 1) IS NOT NULL THEN
      FOR i IN 1..array_upper(isin_tokens, 1) LOOP
--RAISE WARNING '  getNearestNamedFeature: % % % %',NEW.partition, place_centroid, search_maxrank, isin_tokens[i];
        IF NOT ARRAY[isin_tokens[i]] <@ nameaddress_vector THEN

          FOR location IN SELECT * from getNearestNamedFeature(NEW.partition, place_centroid, search_maxrank, isin_tokens[i]) LOOP

  --RAISE WARNING '  ISIN: %',location;

            IF location.rank_search > 4 THEN
                nameaddress_vector := array_merge(nameaddress_vector, location.keywords::integer[]);
                INSERT INTO place_addressline VALUES (NEW.place_id, location.place_id, false, NOT address_havelevel[location.rank_address], location.distance, location.rank_address);
                address_havelevel[location.rank_address] := true;

                IF location.rank_address > parent_place_id_rank THEN
                  NEW.parent_place_id = location.place_id;
                  parent_place_id_rank = location.rank_address;
                END IF;
            END IF;
          END LOOP;

        END IF;

      END LOOP;
    END IF;

    -- for long ways we should add search terms for the entire length
    IF st_length(NEW.geometry) > 0.05 THEN

      location_rank_search := 0;
      location_distance := 0;

      FOR location IN SELECT * from getNearFeatures(NEW.partition, NEW.geometry, search_maxrank, isin_tokens) LOOP

        IF location.rank_address != location_rank_search THEN
          location_rank_search := location.rank_address;
          location_distance := location.distance * 1.5;
        END IF;

        IF location.rank_search > 4 AND location.distance < location_distance THEN

          -- Add it to the list of search terms
          nameaddress_vector := array_merge(nameaddress_vector, location.keywords::integer[]);
          INSERT INTO place_addressline VALUES (NEW.place_id, location.place_id, true, false, location.distance, location.rank_address); 

        END IF;

      END LOOP;

    END IF;

    -- if we have a name add this to the name search table
    IF NEW.name IS NOT NULL THEN

      IF NEW.rank_search <= 25 and NEW.rank_address > 0 THEN
        result := add_location(NEW.place_id, NEW.calculated_country_code, NEW.partition, name_vector, NEW.rank_search, NEW.rank_address, NEW.geometry);
      END IF;

      IF NEW.rank_search between 26 and 27 and NEW.class = 'highway' THEN
        result := insertLocationRoad(NEW.partition, NEW.place_id, NEW.calculated_country_code, NEW.geometry);
      END IF;

      result := insertSearchName(NEW.partition, NEW.place_id, NEW.calculated_country_code, name_vector, nameaddress_vector, NEW.rank_search, NEW.rank_address, NEW.importance, place_centroid, NEW.geometry);

    END IF;

    -- If we've not managed to pick up a better one - default centroid
    IF NEW.centroid IS NULL THEN
      NEW.centroid := place_centroid;
    END IF;

  END IF;

  RETURN NEW;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION placex_delete() RETURNS TRIGGER
  AS $$
DECLARE
  b BOOLEAN;
  classtable TEXT;
BEGIN
  -- RAISE WARNING 'placex_delete % %',OLD.osm_type,OLD.osm_id;

  update placex set linked_place_id = null, indexed_status = 2 where linked_place_id = OLD.place_id and indexed_status = 0;
  --DEBUG: RAISE WARNING 'placex_delete:01 % %',OLD.osm_type,OLD.osm_id;
  update placex set linked_place_id = null where linked_place_id = OLD.place_id;
  --DEBUG: RAISE WARNING 'placex_delete:02 % %',OLD.osm_type,OLD.osm_id;

  IF OLD.rank_address < 30 THEN

    -- mark everything linked to this place for re-indexing
    --DEBUG: RAISE WARNING 'placex_delete:03 % %',OLD.osm_type,OLD.osm_id;
    UPDATE placex set indexed_status = 2 from place_addressline where address_place_id = OLD.place_id 
      and placex.place_id = place_addressline.place_id and indexed_status = 0 and place_addressline.isaddress;

    --DEBUG: RAISE WARNING 'placex_delete:04 % %',OLD.osm_type,OLD.osm_id;
    DELETE FROM place_addressline where address_place_id = OLD.place_id;

    --DEBUG: RAISE WARNING 'placex_delete:05 % %',OLD.osm_type,OLD.osm_id;
    b := deleteRoad(OLD.partition, OLD.place_id);

    --DEBUG: RAISE WARNING 'placex_delete:06 % %',OLD.osm_type,OLD.osm_id;
    update placex set indexed_status = 2 where parent_place_id = OLD.place_id and indexed_status = 0;
    --DEBUG: RAISE WARNING 'placex_delete:07 % %',OLD.osm_type,OLD.osm_id;

  END IF;

  --DEBUG: RAISE WARNING 'placex_delete:08 % %',OLD.osm_type,OLD.osm_id;

  IF OLD.rank_address < 26 THEN
    b := deleteLocationArea(OLD.partition, OLD.place_id, OLD.rank_search);
  END IF;

  --DEBUG: RAISE WARNING 'placex_delete:09 % %',OLD.osm_type,OLD.osm_id;

  IF OLD.name is not null THEN
    b := deleteSearchName(OLD.partition, OLD.place_id);
  END IF;

  --DEBUG: RAISE WARNING 'placex_delete:10 % %',OLD.osm_type,OLD.osm_id;

  DELETE FROM place_addressline where place_id = OLD.place_id;

  --DEBUG: RAISE WARNING 'placex_delete:11 % %',OLD.osm_type,OLD.osm_id;

  -- remove from tables for special search
  classtable := 'place_classtype_' || OLD.class || '_' || OLD.type;
  SELECT count(*)>0 FROM pg_tables WHERE tablename = classtable and schemaname = current_schema() INTO b;
  IF b THEN
    EXECUTE 'DELETE FROM ' || classtable::regclass || ' WHERE place_id = $1' USING OLD.place_id;
  END IF;

  --DEBUG: RAISE WARNING 'placex_delete:12 % %',OLD.osm_type,OLD.osm_id;

  RETURN OLD;

END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION place_delete() RETURNS TRIGGER
  AS $$
DECLARE
  has_rank BOOLEAN;
BEGIN

  --DEBUG: RAISE WARNING 'delete: % % % %',OLD.osm_type,OLD.osm_id,OLD.class,OLD.type;

  -- deleting large polygons can have a massive effect on the system - require manual intervention to let them through
  IF st_area(OLD.geometry) > 2 and st_isvalid(OLD.geometry) THEN
    SELECT bool_or(not (rank_address = 0 or rank_address > 26)) as ranked FROM placex WHERE osm_type = OLD.osm_type and osm_id = OLD.osm_id and class = OLD.class and type = OLD.type INTO has_rank;
    IF has_rank THEN
      insert into import_polygon_delete values (OLD.osm_type,OLD.osm_id,OLD.class,OLD.type);
      RETURN NULL;
    END IF;
  END IF;

  -- mark for delete
  UPDATE placex set indexed_status = 100 where osm_type = OLD.osm_type and osm_id = OLD.osm_id and class = OLD.class and type = OLD.type;

  -- interpolations are special
  IF OLD.class = 'place' and OLD.type = 'houses' THEN
    UPDATE placex set indexed_status = 100 where osm_type = OLD.osm_type and osm_id = OLD.osm_id and class = 'place' and type = 'address';
  END IF;

  RETURN OLD;

END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION place_insert() RETURNS TRIGGER
  AS $$
DECLARE
  i INTEGER;
  existing RECORD;
  existingplacex RECORD;
  existinggeometry GEOMETRY;
  existingplace_id BIGINT;
  result BOOLEAN;
  partition INTEGER;
BEGIN

  --DEBUG: RAISE WARNING '-----------------------------------------------------------------------------------';
  --DEBUG: RAISE WARNING 'place_insert: % % % % %',NEW.osm_type,NEW.osm_id,NEW.class,NEW.type,st_area(NEW.geometry);

  IF FALSE and NEW.osm_type = 'R' THEN
    select * from placex where osm_type = NEW.osm_type and osm_id = NEW.osm_id and class = NEW.class and type = NEW.type INTO existingplacex;
    --DEBUG: RAISE WARNING '%', existingplacex;
  END IF;

  IF ST_IsEmpty(NEW.geometry) OR NOT ST_IsValid(NEW.geometry) OR ST_X(ST_Centroid(NEW.geometry))::text in ('NaN','Infinity','-Infinity') OR ST_Y(ST_Centroid(NEW.geometry))::text in ('NaN','Infinity','-Infinity') THEN  
    INSERT INTO import_polygon_error values (NEW.osm_type, NEW.osm_id, NEW.class, NEW.type, NEW.name, NEW.country_code, 
      now(), ST_IsValidReason(NEW.geometry), null, NEW.geometry);
--    RAISE WARNING 'Invalid Geometry: % % % %',NEW.osm_type,NEW.osm_id,NEW.class,NEW.type;
    RETURN null;
  END IF;

  -- Patch in additional country names
  IF NEW.admin_level = 2 AND NEW.type = 'administrative' AND NEW.country_code is not null THEN
    select coalesce(country_name.name || NEW.name,NEW.name) from country_name where country_name.country_code = lower(NEW.country_code) INTO NEW.name;
  END IF;
    
  -- Have we already done this place?
  select * from place where osm_type = NEW.osm_type and osm_id = NEW.osm_id and class = NEW.class and type = NEW.type INTO existing;

  -- Get the existing place_id
  select * from placex where osm_type = NEW.osm_type and osm_id = NEW.osm_id and class = NEW.class and type = NEW.type INTO existingplacex;

  -- Handle a place changing type by removing the old data
  -- My generated 'place' types are causing havok because they overlap with real keys
  -- TODO: move them to their own special purpose key/class to avoid collisions
  IF existing.osm_type IS NULL THEN
    DELETE FROM place where osm_type = NEW.osm_type and osm_id = NEW.osm_id and class = NEW.class;
  END IF;

  --DEBUG: RAISE WARNING 'Existing: %',existing.osm_id;
  --DEBUG: RAISE WARNING 'Existing PlaceX: %',existingplacex.place_id;

  -- Log and discard 
  IF existing.geometry is not null AND st_isvalid(existing.geometry) 
    AND st_area(existing.geometry) > 0.02
    AND ST_GeometryType(NEW.geometry) in ('ST_Polygon','ST_MultiPolygon')
    AND st_area(NEW.geometry) < st_area(existing.geometry)*0.5
    THEN
    INSERT INTO import_polygon_error values (NEW.osm_type, NEW.osm_id, NEW.class, NEW.type, NEW.name, NEW.country_code, now(), 
      'Area reduced from '||st_area(existing.geometry)||' to '||st_area(NEW.geometry), existing.geometry, NEW.geometry);
    RETURN null;
  END IF;

  DELETE from import_polygon_error where osm_type = NEW.osm_type and osm_id = NEW.osm_id;
  DELETE from import_polygon_delete where osm_type = NEW.osm_type and osm_id = NEW.osm_id;

  -- To paraphrase, if there isn't an existing item, OR if the admin level has changed
  IF existingplacex.osm_type IS NULL OR
    (coalesce(existingplacex.admin_level, 15) != coalesce(NEW.admin_level, 15) AND existingplacex.class = 'boundary' AND existingplacex.type = 'administrative')
  THEN

    IF existingplacex.osm_type IS NOT NULL THEN
      -- sanity check: ignore admin_level changes on places with too many active children
      -- or we end up reindexing entire countries because somebody accidentally deleted admin_level
      --LIMIT INDEXING: SELECT count(*) FROM (SELECT 'a' FROM placex , place_addressline where address_place_id = existingplacex.place_id and placex.place_id = place_addressline.place_id and indexed_status = 0 and place_addressline.isaddress LIMIT 100001) sub INTO i;
      --LIMIT INDEXING: IF i > 100000 THEN
      --LIMIT INDEXING:  RETURN null;
      --LIMIT INDEXING: END IF;
    END IF;

    IF existing.osm_type IS NOT NULL THEN
      -- pathological case caused by the triggerless copy into place during initial import
      -- force delete even for large areas, it will be reinserted later
      UPDATE place set geometry = ST_SetSRID(ST_Point(0,0), 4326) where osm_type = NEW.osm_type and osm_id = NEW.osm_id and class = NEW.class and type = NEW.type;
      DELETE from place where osm_type = NEW.osm_type and osm_id = NEW.osm_id and class = NEW.class and type = NEW.type;
    END IF;

    -- No - process it as a new insertion (hopefully of low rank or it will be slow)
    insert into placex (osm_type, osm_id, class, type, name, admin_level, housenumber, 
      street, addr_place, isin, postcode, country_code, extratags, geometry)
      values (NEW.osm_type
        ,NEW.osm_id
        ,NEW.class
        ,NEW.type
        ,NEW.name
        ,NEW.admin_level
        ,NEW.housenumber
        ,NEW.street
        ,NEW.addr_place
        ,NEW.isin
        ,NEW.postcode
        ,NEW.country_code
        ,NEW.extratags
        ,NEW.geometry
        );

    --DEBUG: RAISE WARNING 'insert done % % % % %',NEW.osm_type,NEW.osm_id,NEW.class,NEW.type,NEW.name;

    RETURN NEW;
  END IF;

  -- Various ways to do the update

  -- Debug, what's changed?
  IF FALSE THEN
    IF coalesce(existing.name::text, '') != coalesce(NEW.name::text, '') THEN
      RAISE WARNING 'update details, name: % % % %',NEW.osm_type,NEW.osm_id,existing.name::text,NEW.name::text;
    END IF;
    IF coalesce(existing.housenumber, '') != coalesce(NEW.housenumber, '') THEN
      RAISE WARNING 'update details, housenumber: % % % %',NEW.osm_type,NEW.osm_id,existing.housenumber,NEW.housenumber;
    END IF;
    IF coalesce(existing.street, '') != coalesce(NEW.street, '') THEN
      RAISE WARNING 'update details, street: % % % %',NEW.osm_type,NEW.osm_id,existing.street,NEW.street;
    END IF;
    IF coalesce(existing.addr_place, '') != coalesce(NEW.addr_place, '') THEN
      RAISE WARNING 'update details, street: % % % %',NEW.osm_type,NEW.osm_id,existing.addr_place,NEW.addr_place;
    END IF;
    IF coalesce(existing.isin, '') != coalesce(NEW.isin, '') THEN
      RAISE WARNING 'update details, isin: % % % %',NEW.osm_type,NEW.osm_id,existing.isin,NEW.isin;
    END IF;
    IF coalesce(existing.postcode, '') != coalesce(NEW.postcode, '') THEN
      RAISE WARNING 'update details, postcode: % % % %',NEW.osm_type,NEW.osm_id,existing.postcode,NEW.postcode;
    END IF;
    IF coalesce(existing.country_code, '') != coalesce(NEW.country_code, '') THEN
      RAISE WARNING 'update details, country_code: % % % %',NEW.osm_type,NEW.osm_id,existing.country_code,NEW.country_code;
    END IF;
  END IF;

  -- Special case for polygon shape changes because they tend to be large and we can be a bit clever about how we handle them
  IF existing.geometry::text != NEW.geometry::text 
     AND ST_GeometryType(existing.geometry) in ('ST_Polygon','ST_MultiPolygon')
     AND ST_GeometryType(NEW.geometry) in ('ST_Polygon','ST_MultiPolygon') 
     THEN 

    -- Get the version of the geometry actually used (in placex table)
    select geometry from placex where osm_type = NEW.osm_type and osm_id = NEW.osm_id and class = NEW.class and type = NEW.type into existinggeometry;

    -- Performance limit
    IF st_area(NEW.geometry) < 0.000000001 AND st_area(existinggeometry) < 1 THEN

      -- re-index points that have moved in / out of the polygon, could be done as a single query but postgres gets the index usage wrong
      update placex set indexed_status = 2 where indexed_status = 0 and 
          (st_covers(NEW.geometry, placex.geometry) OR ST_Intersects(NEW.geometry, placex.geometry))
          AND NOT (st_covers(existinggeometry, placex.geometry) OR ST_Intersects(existinggeometry, placex.geometry))
          AND rank_search > existingplacex.rank_search AND (rank_search < 28 or name is not null);

      update placex set indexed_status = 2 where indexed_status = 0 and 
          (st_covers(existinggeometry, placex.geometry) OR ST_Intersects(existinggeometry, placex.geometry))
          AND NOT (st_covers(NEW.geometry, placex.geometry) OR ST_Intersects(NEW.geometry, placex.geometry))
          AND rank_search > existingplacex.rank_search AND (rank_search < 28 or name is not null);

    END IF;

  END IF;


  IF coalesce(existing.name::text, '') != coalesce(NEW.name::text, '')
     OR coalesce(existing.extratags::text, '') != coalesce(NEW.extratags::text, '')
     OR coalesce(existing.housenumber, '') != coalesce(NEW.housenumber, '')
     OR coalesce(existing.street, '') != coalesce(NEW.street, '')
     OR coalesce(existing.addr_place, '') != coalesce(NEW.addr_place, '')
     OR coalesce(existing.isin, '') != coalesce(NEW.isin, '')
     OR coalesce(existing.postcode, '') != coalesce(NEW.postcode, '')
     OR coalesce(existing.country_code, '') != coalesce(NEW.country_code, '')
     OR coalesce(existing.admin_level, 15) != coalesce(NEW.admin_level, 15)
     OR existing.geometry::text != NEW.geometry::text
     THEN

    update place set 
      name = NEW.name,
      housenumber  = NEW.housenumber,
      street = NEW.street,
      addr_place = NEW.addr_place,
      isin = NEW.isin,
      postcode = NEW.postcode,
      country_code = NEW.country_code,
      extratags = NEW.extratags,
      admin_level = NEW.admin_level,
      geometry = NEW.geometry
      where osm_type = NEW.osm_type and osm_id = NEW.osm_id and class = NEW.class and type = NEW.type;

    IF NEW.class in ('place','boundary') AND NEW.type in ('postcode','postal_code') THEN
        IF NEW.postcode IS NULL THEN
            -- postcode was deleted, no longer retain in placex
            DELETE FROM placex where place_id = existingplacex.place_id;
            RETURN NULL;
        END IF;

        NEW.name := hstore('ref', NEW.postcode);
    END IF;

    update placex set 
      name = NEW.name,
      housenumber = NEW.housenumber,
      street = NEW.street,
      addr_place = NEW.addr_place,
      isin = NEW.isin,
      postcode = NEW.postcode,
      country_code = NEW.country_code,
      parent_place_id = null,
      extratags = NEW.extratags,
      admin_level = CASE WHEN NEW.admin_level > 15 THEN 15 ELSE NEW.admin_level END,
      indexed_status = 2,    
      geometry = NEW.geometry
      where place_id = existingplacex.place_id;

  END IF;

  -- for interpolations invalidate all nodes on the line
  IF NEW.class = 'place' and NEW.type = 'houses' and NEW.osm_type = 'W' THEN
    update placex p set indexed_status = 2 from planet_osm_ways w where w.id = NEW.osm_id and p.osm_type = 'N' and p.osm_id = any(w.nodes);
  END IF;

  -- Abort the add (we modified the existing place instead)
  RETURN NULL;

END; 
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_name_by_language(name hstore, languagepref TEXT[]) RETURNS TEXT
  AS $$
DECLARE
  result TEXT;
BEGIN
  IF name is null THEN
    RETURN null;
  END IF;

  FOR j IN 1..array_upper(languagepref,1) LOOP
    IF name ? languagepref[j] THEN
      result := trim(name->languagepref[j]);
      IF result != '' THEN
        return result;
      END IF;
    END IF;
  END LOOP;

  -- anything will do as a fallback - just take the first name type thing there is
  RETURN trim((avals(name))[1]);
END;
$$
LANGUAGE plpgsql IMMUTABLE;


CREATE OR REPLACE FUNCTION get_address_postcode(for_place_id BIGINT) RETURNS TEXT
  AS $$
DECLARE
  result TEXT[];
  search TEXT[];
  for_postcode TEXT;
  found INTEGER;
  location RECORD;
BEGIN

  found := 1000;
  search := ARRAY['ref'];
  result := '{}';

  select postcode from placex where place_id = for_place_id limit 1 into for_postcode;

  FOR location IN 
    select rank_address,name,distance,length(name::text) as namelength 
      from place_addressline join placex on (address_place_id = placex.place_id) 
      where place_addressline.place_id = for_place_id and rank_address in (5,11)
      order by rank_address desc,rank_search desc,fromarea desc,distance asc,namelength desc
  LOOP
    IF array_upper(search, 1) IS NOT NULL AND array_upper(location.name, 1) IS NOT NULL THEN
      FOR j IN 1..array_upper(search, 1) LOOP
        FOR k IN 1..array_upper(location.name, 1) LOOP
          IF (found > location.rank_address AND location.name[k].key = search[j] AND location.name[k].value != '') AND NOT result @> ARRAY[trim(location.name[k].value)] AND (for_postcode IS NULL OR location.name[k].value ilike for_postcode||'%') THEN
            result[(100 - location.rank_address)] := trim(location.name[k].value);
            found := location.rank_address;
          END IF;
        END LOOP;
      END LOOP;
    END IF;
  END LOOP;

  RETURN array_to_string(result,', ');
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_address_by_language(for_place_id BIGINT, languagepref TEXT[]) RETURNS TEXT
  AS $$
DECLARE
  result TEXT[];
  currresult TEXT;
  prevresult TEXT;
  location RECORD;
BEGIN

  result := '{}';
  prevresult := '';

  FOR location IN select * from get_addressdata(for_place_id) where isaddress order by rank_address desc LOOP
    currresult := trim(get_name_by_language(location.name, languagepref));
    IF currresult != prevresult AND currresult IS NOT NULL AND result[(100 - location.rank_address)] IS NULL THEN
      result[(100 - location.rank_address)] := trim(get_name_by_language(location.name, languagepref));
      prevresult := currresult;
    END IF;
  END LOOP;

  RETURN array_to_string(result,', ');
END;
$$
LANGUAGE plpgsql;

DROP TYPE IF EXISTS addressline CASCADE;
create type addressline as (
  place_id BIGINT,
  osm_type CHAR(1),
  osm_id BIGINT,
  name HSTORE,
  class TEXT,
  type TEXT,
  admin_level INTEGER,
  fromarea BOOLEAN,  
  isaddress BOOLEAN,  
  rank_address INTEGER,
  distance FLOAT
);

CREATE OR REPLACE FUNCTION get_addressdata(in_place_id BIGINT) RETURNS setof addressline 
  AS $$
DECLARE
  for_place_id BIGINT;
  result TEXT[];
  search TEXT[];
  found INTEGER;
  location RECORD;
  countrylocation RECORD;
  searchcountrycode varchar(2);
  searchhousenumber TEXT;
  searchhousename HSTORE;
  searchrankaddress INTEGER;
  searchpostcode TEXT;
  searchclass TEXT;
  searchtype TEXT;
  countryname HSTORE;
  hadcountry BOOLEAN;
BEGIN

  select parent_place_id,'us', housenumber, 30, postcode, null, 'place', 'house' from location_property_tiger 
    WHERE place_id = in_place_id 
    INTO for_place_id,searchcountrycode, searchhousenumber, searchrankaddress, searchpostcode, searchhousename, searchclass, searchtype;

  IF for_place_id IS NULL THEN
    select parent_place_id,'us', housenumber, 30, postcode, null, 'place', 'house' from location_property_aux
      WHERE place_id = in_place_id 
      INTO for_place_id,searchcountrycode, searchhousenumber, searchrankaddress, searchpostcode, searchhousename, searchclass, searchtype;
  END IF;

  IF for_place_id IS NULL THEN
    select parent_place_id, calculated_country_code, housenumber, rank_search, postcode, name, class, type from placex 
      WHERE place_id = in_place_id and rank_address = 30 
      INTO for_place_id, searchcountrycode, searchhousenumber, searchrankaddress, searchpostcode, searchhousename, searchclass, searchtype;
  END IF;

  IF for_place_id IS NULL THEN
    select coalesce(linked_place_id, place_id),  calculated_country_code,
           housenumber, rank_search, postcode, null
      from placex where place_id = in_place_id
      INTO for_place_id, searchcountrycode, searchhousenumber, searchrankaddress, searchpostcode, searchhousename;
  END IF;

--RAISE WARNING '% % % %',searchcountrycode, searchhousenumber, searchrankaddress, searchpostcode;

  found := 1000;
  hadcountry := false;
  FOR location IN 
    select placex.place_id, osm_type, osm_id,
      CASE WHEN class = 'place' and type = 'postcode' THEN hstore('name', postcode) ELSE name END as name,
      class, type, admin_level, true as fromarea, true as isaddress,
      CASE WHEN rank_address = 0 THEN 100 WHEN rank_address = 11 THEN 5 ELSE rank_address END as rank_address,
      0 as distance, calculated_country_code, postcode
      from placex
      where place_id = for_place_id 
  LOOP
--RAISE WARNING '%',location;
    IF searchcountrycode IS NULL AND location.calculated_country_code IS NOT NULL THEN
      searchcountrycode := location.calculated_country_code;
    END IF;
    IF searchpostcode IS NOT NULL and location.type = 'postcode' THEN
      location.isaddress := FALSE;
    END IF;
    IF searchpostcode IS NULL and location.postcode IS NOT NULL THEN
      searchpostcode := location.postcode;
    END IF;
    IF location.rank_address = 4 AND location.isaddress THEN
      hadcountry := true;
    END IF;
    IF location.rank_address < 4 AND NOT hadcountry THEN
      select name from country_name where country_code = searchcountrycode limit 1 INTO countryname;
      IF countryname IS NOT NULL THEN
        countrylocation := ROW(null, null, null, countryname, 'place', 'country', null, true, true, 4, 0)::addressline;
        RETURN NEXT countrylocation;
      END IF;
    END IF;
    countrylocation := ROW(location.place_id, location.osm_type, location.osm_id, location.name, location.class, 
                           location.type, location.admin_level, location.fromarea, location.isaddress, location.rank_address, 
                           location.distance)::addressline;
    RETURN NEXT countrylocation;
    found := location.rank_address;
  END LOOP;

  FOR location IN 
    select placex.place_id, osm_type, osm_id,
      CASE WHEN class = 'place' and type = 'postcode' THEN hstore('name', postcode) ELSE name END as name,
      CASE WHEN extratags ? 'place' THEN 'place' ELSE class END as class,
      CASE WHEN extratags ? 'place' THEN extratags->'place' ELSE type END as type,
      admin_level, fromarea, isaddress,
      CASE WHEN address_place_id = for_place_id AND rank_address = 0 THEN 100 WHEN rank_address = 11 THEN 5 ELSE rank_address END as rank_address,
      distance,calculated_country_code,postcode
      from place_addressline join placex on (address_place_id = placex.place_id) 
      where place_addressline.place_id = for_place_id 
      and (cached_rank_address > 0 AND cached_rank_address < searchrankaddress)
      and address_place_id != for_place_id
      and (placex.calculated_country_code IS NULL OR searchcountrycode IS NULL OR placex.calculated_country_code = searchcountrycode)
      order by rank_address desc,isaddress desc,fromarea desc,distance asc,rank_search desc
  LOOP
--RAISE WARNING '%',location;
    IF searchcountrycode IS NULL AND location.calculated_country_code IS NOT NULL THEN
      searchcountrycode := location.calculated_country_code;
    END IF;
    IF searchpostcode IS NOT NULL and location.type = 'postcode' THEN
      location.isaddress := FALSE;
    END IF;
    IF searchpostcode IS NULL and location.isaddress and location.type != 'postcode' and location.postcode IS NOT NULL THEN
      searchpostcode := location.postcode;
    END IF;
    IF location.rank_address = 4 AND location.isaddress THEN
      hadcountry := true;
    END IF;
    IF location.rank_address < 4 AND NOT hadcountry THEN
      select name from country_name where country_code = searchcountrycode limit 1 INTO countryname;
      IF countryname IS NOT NULL THEN
        countrylocation := ROW(null, null, null, countryname, 'place', 'country', null, true, true, 4, 0)::addressline;
        RETURN NEXT countrylocation;
      END IF;
    END IF;
    countrylocation := ROW(location.place_id, location.osm_type, location.osm_id, location.name, location.class, 
                           location.type, location.admin_level, location.fromarea, location.isaddress, location.rank_address, 
                           location.distance)::addressline;
    RETURN NEXT countrylocation;
    found := location.rank_address;
  END LOOP;

  IF found > 4 THEN
    select name from country_name where country_code = searchcountrycode limit 1 INTO countryname;
--RAISE WARNING '% % %',found,searchcountrycode,countryname;
    IF countryname IS NOT NULL THEN
      location := ROW(null, null, null, countryname, 'place', 'country', null, true, true, 4, 0)::addressline;
      RETURN NEXT location;
    END IF;
  END IF;

  IF searchcountrycode IS NOT NULL THEN
    location := ROW(null, null, null, hstore('ref', searchcountrycode), 'place', 'country_code', null, true, false, 4, 0)::addressline;
    RETURN NEXT location;
  END IF;

  IF searchhousename IS NOT NULL THEN
    location := ROW(in_place_id, null, null, searchhousename, searchclass, searchtype, null, true, true, 29, 0)::addressline;
--    location := ROW(in_place_id, null, null, searchhousename, 'place', 'house_name', null, true, true, 29, 0)::addressline;
    RETURN NEXT location;
  END IF;

  IF searchhousenumber IS NOT NULL THEN
    location := ROW(in_place_id, null, null, hstore('ref', searchhousenumber), 'place', 'house_number', null, true, true, 28, 0)::addressline;
    RETURN NEXT location;
  END IF;

  IF searchpostcode IS NOT NULL THEN
    location := ROW(null, null, null, hstore('ref', searchpostcode), 'place', 'postcode', null, true, true, 5, 0)::addressline;
    RETURN NEXT location;
  END IF;

  RETURN;
END;
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION update_place(search_place_id BIGINT) RETURNS BOOLEAN
  AS $$
DECLARE
  numfeatures integer;
BEGIN
  update placex set 
      name = place.name,
      housenumber = place.housenumber,
      street = place.street,
      addr_place = place.addr_place,
      isin = place.isin,
      postcode = place.postcode,
      country_code = place.country_code,
      parent_place_id = null
      from place
      where placex.place_id = search_place_id 
        and place.osm_type = placex.osm_type and place.osm_id = placex.osm_id
        and place.class = placex.class and place.type = placex.type;
  update placex set indexed_status = 2 where place_id = search_place_id;
  update placex set indexed_status = 0 where place_id = search_place_id;
  return true;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_searchrank_label(rank INTEGER) RETURNS TEXT
  AS $$
DECLARE
BEGIN
  IF rank < 2 THEN
    RETURN 'Continent';
  ELSEIF rank < 4 THEN
    RETURN 'Sea';
  ELSEIF rank < 8 THEN
    RETURN 'Country';
  ELSEIF rank < 12 THEN
    RETURN 'State';
  ELSEIF rank < 16 THEN
    RETURN 'County';
  ELSEIF rank = 16 THEN
    RETURN 'City';
  ELSEIF rank = 17 THEN
    RETURN 'Town / Island';
  ELSEIF rank = 18 THEN
    RETURN 'Village / Hamlet';
  ELSEIF rank = 20 THEN
    RETURN 'Suburb';
  ELSEIF rank = 21 THEN
    RETURN 'Postcode Area';
  ELSEIF rank = 22 THEN
    RETURN 'Croft / Farm / Locality / Islet';
  ELSEIF rank = 23 THEN
    RETURN 'Postcode Area';
  ELSEIF rank = 25 THEN
    RETURN 'Postcode Point';
  ELSEIF rank = 26 THEN
    RETURN 'Street / Major Landmark';
  ELSEIF rank = 27 THEN
    RETURN 'Minory Street / Path';
  ELSEIF rank = 28 THEN
    RETURN 'House / Building';
  ELSE
    RETURN 'Other: '||rank;
  END IF;
  
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_addressrank_label(rank INTEGER) RETURNS TEXT
  AS $$
DECLARE
BEGIN
  IF rank = 0 THEN
    RETURN 'None';
  ELSEIF rank < 2 THEN
    RETURN 'Continent';
  ELSEIF rank < 4 THEN
    RETURN 'Sea';
  ELSEIF rank = 5 THEN
    RETURN 'Postcode';
  ELSEIF rank < 8 THEN
    RETURN 'Country';
  ELSEIF rank < 12 THEN
    RETURN 'State';
  ELSEIF rank < 16 THEN
    RETURN 'County';
  ELSEIF rank = 16 THEN
    RETURN 'City';
  ELSEIF rank = 17 THEN
    RETURN 'Town / Village / Hamlet';
  ELSEIF rank = 20 THEN
    RETURN 'Suburb';
  ELSEIF rank = 21 THEN
    RETURN 'Postcode Area';
  ELSEIF rank = 22 THEN
    RETURN 'Croft / Farm / Locality / Islet';
  ELSEIF rank = 23 THEN
    RETURN 'Postcode Area';
  ELSEIF rank = 25 THEN
    RETURN 'Postcode Point';
  ELSEIF rank = 26 THEN
    RETURN 'Street / Major Landmark';
  ELSEIF rank = 27 THEN
    RETURN 'Minory Street / Path';
  ELSEIF rank = 28 THEN
    RETURN 'House / Building';
  ELSE
    RETURN 'Other: '||rank;
  END IF;
  
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION aux_create_property(pointgeo GEOMETRY, in_housenumber TEXT, 
  in_street TEXT, in_isin TEXT, in_postcode TEXT, in_countrycode char(2)) RETURNS INTEGER
  AS $$
DECLARE

  newpoints INTEGER;
  place_centroid GEOMETRY;
  out_partition INTEGER;
  out_parent_place_id BIGINT;
  location RECORD;
  address_street_word_id INTEGER;  
  out_postcode TEXT;

BEGIN

  place_centroid := ST_Centroid(pointgeo);
  out_partition := get_partition(in_countrycode);
  out_parent_place_id := null;

  address_street_word_id := get_name_id(make_standard_name(in_street));
  IF address_street_word_id IS NOT NULL THEN
    FOR location IN SELECT * from getNearestNamedRoadFeature(out_partition, place_centroid, address_street_word_id) LOOP
      out_parent_place_id := location.place_id;
    END LOOP;
  END IF;

  IF out_parent_place_id IS NULL THEN
    FOR location IN SELECT place_id FROM getNearestRoadFeature(out_partition, place_centroid) LOOP
      out_parent_place_id := location.place_id;
    END LOOP;    
  END IF;

  out_postcode := in_postcode;
  IF out_postcode IS NULL THEN
    SELECT postcode from placex where place_id = out_parent_place_id INTO out_postcode;
  END IF;
  IF out_postcode IS NULL THEN
    out_postcode := getNearestPostcode(out_partition, place_centroid);
  END IF;

  newpoints := 0;
  insert into location_property_aux (place_id, partition, parent_place_id, housenumber, postcode, centroid)
    values (nextval('seq_place'), out_partition, out_parent_place_id, in_housenumber, out_postcode, place_centroid);
  newpoints := newpoints + 1;

  RETURN newpoints;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_osm_rel_members(members TEXT[], member TEXT) RETURNS TEXT[]
  AS $$
DECLARE
  result TEXT[];
  i INTEGER;
BEGIN

  FOR i IN 1..ARRAY_UPPER(members,1) BY 2 LOOP
    IF members[i+1] = member THEN
      result := result || members[i];
    END IF;
  END LOOP;

  return result;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_osm_rel_members(members TEXT[], memberLabels TEXT[]) RETURNS SETOF TEXT
  AS $$
DECLARE
  i INTEGER;
BEGIN

  FOR i IN 1..ARRAY_UPPER(members,1) BY 2 LOOP
    IF members[i+1] = ANY(memberLabels) THEN
      RETURN NEXT members[i];
    END IF;
  END LOOP;

  RETURN;
END;
$$
LANGUAGE plpgsql;

-- See: http://stackoverflow.com/questions/6410088/how-can-i-mimic-the-php-urldecode-function-in-postgresql
CREATE OR REPLACE FUNCTION decode_url_part(p varchar) RETURNS varchar 
  AS $$
SELECT convert_from(CAST(E'\\x' || array_to_string(ARRAY(
    SELECT CASE WHEN length(r.m[1]) = 1 THEN encode(convert_to(r.m[1], 'SQL_ASCII'), 'hex') ELSE substring(r.m[1] from 2 for 2) END
    FROM regexp_matches($1, '%[0-9a-f][0-9a-f]|.', 'gi') AS r(m)
), '') AS bytea), 'UTF8');
$$ 
LANGUAGE SQL IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION catch_decode_url_part(p varchar) RETURNS varchar
  AS $$
DECLARE
BEGIN
  RETURN decode_url_part(p);
EXCEPTION
  WHEN others THEN return null;
END;
$$
LANGUAGE plpgsql IMMUTABLE;

DROP TYPE wikipedia_article_match CASCADE;
create type wikipedia_article_match as (
  language TEXT,
  title TEXT,
  importance FLOAT
);

CREATE OR REPLACE FUNCTION get_wikipedia_match(extratags HSTORE, country_code varchar(2)) RETURNS wikipedia_article_match
  AS $$
DECLARE
  langs TEXT[];
  i INT;
  wiki_article TEXT;
  wiki_article_title TEXT;
  wiki_article_language TEXT;
  result wikipedia_article_match;
BEGIN
  langs := ARRAY['english','country','ar','bg','ca','cs','da','de','en','es','eo','eu','fa','fr','ko','hi','hr','id','it','he','lt','hu','ms','nl','ja','no','pl','pt','kk','ro','ru','sk','sl','sr','fi','sv','tr','uk','vi','vo','war','zh'];
  i := 1;
  WHILE langs[i] IS NOT NULL LOOP
    wiki_article := extratags->(case when langs[i] in ('english','country') THEN 'wikipedia' ELSE 'wikipedia:'||langs[i] END);
    IF wiki_article is not null THEN
      wiki_article := regexp_replace(wiki_article,E'^(.*?)([a-z]{2,3}).wikipedia.org/wiki/',E'\\2:');
      wiki_article := regexp_replace(wiki_article,E'^(.*?)([a-z]{2,3}).wikipedia.org/w/index.php\\?title=',E'\\2:');
      wiki_article := regexp_replace(wiki_article,E'^(.*?)/([a-z]{2,3})/wiki/',E'\\2:');
      --wiki_article := regexp_replace(wiki_article,E'^(.*?)([a-z]{2,3})[=:]',E'\\2:');
      wiki_article := replace(wiki_article,' ','_');
      IF strpos(wiki_article, ':') IN (3,4) THEN
        wiki_article_language := lower(trim(split_part(wiki_article, ':', 1)));
        wiki_article_title := trim(substr(wiki_article, strpos(wiki_article, ':')+1));
      ELSE
        wiki_article_title := trim(wiki_article);
        wiki_article_language := CASE WHEN langs[i] = 'english' THEN 'en' WHEN langs[i] = 'country' THEN get_country_language_code(country_code) ELSE langs[i] END;
      END IF;

      select wikipedia_article.language,wikipedia_article.title,wikipedia_article.importance
        from wikipedia_article 
        where language = wiki_article_language and 
        (title = wiki_article_title OR title = catch_decode_url_part(wiki_article_title) OR title = replace(catch_decode_url_part(wiki_article_title),E'\\',''))
      UNION ALL
      select wikipedia_article.language,wikipedia_article.title,wikipedia_article.importance
        from wikipedia_redirect join wikipedia_article on (wikipedia_redirect.language = wikipedia_article.language and wikipedia_redirect.to_title = wikipedia_article.title)
        where wikipedia_redirect.language = wiki_article_language and 
        (from_title = wiki_article_title OR from_title = catch_decode_url_part(wiki_article_title) OR from_title = replace(catch_decode_url_part(wiki_article_title),E'\\',''))
      order by importance desc limit 1 INTO result;

      IF result.language is not null THEN
        return result;
      END IF;
    END IF;
    i := i + 1;
  END LOOP;
  RETURN NULL;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION quad_split_geometry(geometry GEOMETRY, maxarea FLOAT, maxdepth INTEGER) 
  RETURNS SETOF GEOMETRY
  AS $$
DECLARE
  xmin FLOAT;
  ymin FLOAT;
  xmax FLOAT;
  ymax FLOAT;
  xmid FLOAT;
  ymid FLOAT;
  secgeo GEOMETRY;
  secbox GEOMETRY;
  seg INTEGER;
  geo RECORD;
  area FLOAT;
  remainingdepth INTEGER;
  added INTEGER;
  
BEGIN

--  RAISE WARNING 'quad_split_geometry: maxarea=%, depth=%',maxarea,maxdepth;

  IF (ST_GeometryType(geometry) not in ('ST_Polygon','ST_MultiPolygon') OR NOT ST_IsValid(geometry)) THEN
    RETURN NEXT geometry;
    RETURN;
  END IF;

  remainingdepth := maxdepth - 1;
  area := ST_AREA(geometry);
  IF remainingdepth < 1 OR area < maxarea THEN
    RETURN NEXT geometry;
    RETURN;
  END IF;

  xmin := st_xmin(geometry);
  xmax := st_xmax(geometry);
  ymin := st_ymin(geometry);
  ymax := st_ymax(geometry);
  secbox := ST_SetSRID(ST_MakeBox2D(ST_Point(ymin,xmin),ST_Point(ymax,xmax)),4326);

  -- if the geometry completely covers the box don't bother to slice any more
  IF ST_AREA(secbox) = area THEN
    RETURN NEXT geometry;
    RETURN;
  END IF;

  xmid := (xmin+xmax)/2;
  ymid := (ymin+ymax)/2;

  added := 0;
  FOR seg IN 1..4 LOOP

    IF seg = 1 THEN
      secbox := ST_SetSRID(ST_MakeBox2D(ST_Point(xmin,ymin),ST_Point(xmid,ymid)),4326);
    END IF;
    IF seg = 2 THEN
      secbox := ST_SetSRID(ST_MakeBox2D(ST_Point(xmin,ymid),ST_Point(xmid,ymax)),4326);
    END IF;
    IF seg = 3 THEN
      secbox := ST_SetSRID(ST_MakeBox2D(ST_Point(xmid,ymin),ST_Point(xmax,ymid)),4326);
    END IF;
    IF seg = 4 THEN
      secbox := ST_SetSRID(ST_MakeBox2D(ST_Point(xmid,ymid),ST_Point(xmax,ymax)),4326);
    END IF;

    IF st_intersects(geometry, secbox) THEN
      secgeo := st_intersection(geometry, secbox);
      IF NOT ST_IsEmpty(secgeo) AND ST_GeometryType(secgeo) in ('ST_Polygon','ST_MultiPolygon') THEN
        FOR geo IN select quad_split_geometry(secgeo, maxarea, remainingdepth) as geom LOOP
          IF NOT ST_IsEmpty(geo.geom) AND ST_GeometryType(geo.geom) in ('ST_Polygon','ST_MultiPolygon') THEN
            added := added + 1;
            RETURN NEXT geo.geom;
          END IF;
        END LOOP;
      END IF;
    END IF;
  END LOOP;

  RETURN;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION split_geometry(geometry GEOMETRY) 
  RETURNS SETOF GEOMETRY
  AS $$
DECLARE
  geo RECORD;
BEGIN
  -- 10000000000 is ~~ 1x1 degree
  FOR geo IN select quad_split_geometry(geometry, 0.25, 20) as geom LOOP
    RETURN NEXT geo.geom;
  END LOOP;
  RETURN;
END;
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION place_force_delete(placeid BIGINT) RETURNS BOOLEAN
  AS $$
DECLARE
    osmid BIGINT;
    osmtype character(1);
    pclass text;
    ptype text;
BEGIN
  SELECT osm_type, osm_id, class, type FROM placex WHERE place_id = placeid INTO osmtype, osmid, pclass, ptype;
  DELETE FROM import_polygon_delete where osm_type = osmtype and osm_id = osmid and class = pclass and type = ptype;
  DELETE FROM import_polygon_error where osm_type = osmtype and osm_id = osmid and class = pclass and type = ptype;
  -- force delete from place/placex by making it a very small geometry
  UPDATE place set geometry = ST_SetSRID(ST_Point(0,0), 4326) where osm_type = osmtype and osm_id = osmid and class = pclass and type = ptype;
  DELETE FROM place where osm_type = osmtype and osm_id = osmid and class = pclass and type = ptype;

  RETURN TRUE;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION place_force_update(placeid BIGINT) RETURNS BOOLEAN
  AS $$
DECLARE
  placegeom GEOMETRY;
  geom GEOMETRY;
  diameter FLOAT;
  rank INTEGER;
BEGIN
  UPDATE placex SET indexed_status = 2 WHERE place_id = placeid;
  SELECT geometry, rank_search FROM placex WHERE place_id = placeid INTO placegeom, rank;
  IF placegeom IS NOT NULL AND ST_IsValid(placegeom) THEN
    IF ST_GeometryType(placegeom) in ('ST_Polygon','ST_MultiPolygon') THEN
      FOR geom IN select split_geometry(placegeom) FROM placex WHERE place_id = placeid LOOP
        update placex set indexed_status = 2 where (st_covers(geom, placex.geometry) OR ST_Intersects(geom, placex.geometry)) 
        AND rank_search > rank and indexed_status = 0 and ST_geometrytype(placex.geometry) = 'ST_Point' and (rank_search < 28 or name is not null or (rank >= 16 and addr_place is not null));
        update placex set indexed_status = 2 where (st_covers(geom, placex.geometry) OR ST_Intersects(geom, placex.geometry)) 
        AND rank_search > rank and indexed_status = 0 and ST_geometrytype(placex.geometry) != 'ST_Point' and (rank_search < 28 or name is not null or (rank >= 16 and addr_place is not null));
      END LOOP;
    ELSE
        diameter := 0;
        IF rank = 11 THEN
          diameter := 0.05;
        ELSEIF rank < 18 THEN
          diameter := 0.1;
        ELSEIF rank < 20 THEN
          diameter := 0.05;
        ELSEIF rank = 21 THEN
          diameter := 0.001;
        ELSEIF rank < 24 THEN
          diameter := 0.02;
        ELSEIF rank < 26 THEN
          diameter := 0.002; -- 100 to 200 meters
        ELSEIF rank < 28 THEN
          diameter := 0.001; -- 50 to 100 meters
        END IF;
        IF diameter > 0 THEN
          IF rank >= 26 THEN
            -- roads may cause reparenting for >27 rank places
            update placex set indexed_status = 2 where indexed_status = 0 and rank_search > rank and ST_DWithin(placex.geometry, placegeom, diameter);
          ELSEIF rank >= 16 THEN
            -- up to rank 16, street-less addresses may need reparenting
            update placex set indexed_status = 2 where indexed_status = 0 and rank_search > rank and ST_DWithin(placex.geometry, placegeom, diameter) and (rank_search < 28 or name is not null or addr_place is not null);
          ELSE
            -- for all other places the search terms may change as well
            update placex set indexed_status = 2 where indexed_status = 0 and rank_search > rank and ST_DWithin(placex.geometry, placegeom, diameter) and (rank_search < 28 or name is not null);
          END IF;
        END IF;
    END IF;
    RETURN TRUE;
  END IF;

  RETURN FALSE;
END;
$$
LANGUAGE plpgsql;
