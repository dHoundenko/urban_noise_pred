-- New samples?

DELETE FROM new_data
WHERE tmsnumber = 471;

CREATE INDEX IF NOT EXISTS new_data_geom_idx 
ON new_data USING GIST (geom);

ALTER TABLE new_data 
ADD COLUMN IF NOT EXISTS vyohyke TEXT;

UPDATE new_sampled ns
SET vyohyke = mt.vyohyke
FROM melu_table mt
WHERE ST_Contains(mt.geom_3067, ns.geom);

CREATE TABLE new_sampled AS
SELECT ns.*
FROM new_data ns
WHERE NOT EXISTS (
    SELECT 1
    FROM sampled_data sd
    WHERE ST_Equals(ns.geom, sd.geom)
);

UPDATE new_data
SET vyohyke = 'alle 45 dB'
WHERE vyohyke IN ('30-35 dB', '35-40 dB', '40-45 dB');

SELECT vyohyke, COUNT(*) AS count
FROM new_data
GROUP BY vyohyke
ORDER BY count DESC;

-- old

DELETE FROM calculation_points 
WHERE tmsnumber = 471;

UPDATE sampled_points
SET vyohyke = 'alle 45 dB'
WHERE vyohyke IN ('30-35 dB', '35-40 dB', '40-45 dB');

-- Start

CREATE INDEX IF NOT EXISTS calculation_points_geom_idx 
ON calculation_points USING GIST (geom);

CREATE INDEX IF NOT EXISTS melu_shape_geom_idx 
ON melu_shape USING GIST (geom);

ALTER TABLE melu_table 
ADD COLUMN geom_3067 geometry(MultiPolygon, 3067);

UPDATE melu_table 
SET geom_3067 = ST_Transform(geom, 3067);

ALTER TABLE calculation_points 
ADD COLUMN IF NOT EXISTS vyohyke TEXT;

UPDATE calculation_points cp
SET vyohyke = mt.vyohyke
FROM melu_table mt
WHERE ST_Contains(mt.geom_3067, cp.geom);

-- Public transport to sample point distance:

ALTER TABLE calculation_points  
ADD COLUMN IF NOT EXISTS shortest_distance DOUBLE PRECISION

WITH combined_lines AS (
    SELECT geom FROM rait_hrv_tays
    UNION ALL
    SELECT geom FROM rait_lenta_puolt
    UNION ALL
    SELECT geom FROM rait_lie_ylo
)
UPDATE calculation_points cp
SET shortest_distance = (
    SELECT MIN(ST_Distance(cp.geom, cl.geom))
    FROM combined_lines cl
)

-- Waterways to sample point distance:
-- 60s to load 

CREATE INDEX IF NOT EXISTS idx_water_geom_idx
ON water USING GIST (geom);

ALTER TABLE calculation_points
ADD COLUMN IF NOT EXISTS dist_water FLOAT;

UPDATE calculation_points cp
SET dist_water = (
    SELECT MIN(ST_Distance(cp.geom, wt.geom))
    FROM water wt
);

-- Get elevation at each sample

CREATE TABLE DEM AS
SELECT * FROM m4211
UNION ALL
SELECT * FROM m4212
UNION ALL
SELECT * FROM m4213
UNION ALL
SELECT * FROM m4214;

ALTER TABLE sampled_data ADD COLUMN elevation_DEM DOUBLE PRECISION;

UPDATE sampled_data s
SET elevation_DEM = (
    SELECT ST_Value(d.rast, 1, s.geom)
    FROM DEM d
    WHERE ST_Intersects(d.rast, s.geom)
    LIMIT 1
);

-- ALTER TABLE elevation 
-- RENAME COLUMN "Korkeus" TO korkeus;

-- ALTER TABLE calculation_points
-- ADD COLUMN IF NOT EXISTS elevation FLOAT;

-- -- UPDATE calculation_points cp
-- -- SET elevation = (
-- --   SELECT el.korkeus
-- --   FROM elevation el
-- --   ORDER BY ST_Distance(cp.geom, el.geom)
-- --   LIMIT 1
-- -- );

-- CREATE INDEX idx_elevation_geom ON elevation USING GIST(geom);

-- UPDATE calculation_points cp
-- SET elevation = el.korkeus
-- FROM (
--   SELECT
--     cp.id,
--     (SELECT el.korkeus
--      FROM elevation el
--      ORDER BY el.geom <-> cp.geom
--      LIMIT 1) AS korkeus
--   FROM calculation_points cp
-- ) AS el
-- WHERE cp.id = el.id;

-- TPI 1600m radius

ALTER TABLE sampled_data 
ADD COLUMN tpi_1600m DOUBLE PRECISION;

-- syntaxis: SELECT (stats).mean FROM (...) elevation_stats

-- 1. ST_Buffer() Creates a 1600‑meter buffer around the sample point.
-- 2. ST_Intersects() Selects only those DEM tiles that overlap the buffer.

-- 3. ST_Clip(rast, ST_Buffer(..)): Exact area of the buffer from each raster tile.
-- 4. ST_Union(…): Merges the clipped rasters into a single raster so that statistics are calculated over the entire neighborhood.
-- Need to merge because buffer (1600m radius) intersects multiple raster tiles.
-- 5. ST_SummaryStats(…, 1, true): Computes statistics (including the mean) on the first band of the unioned raster.

-- 6. SET tpi_1600m = s.elevation_DEM - (stats).mean

-- 911.593s. to execute
UPDATE sampled_data s
SET tpi_1600m = s.elevation_DEM - (
  SELECT (stats).mean
  FROM (
    SELECT ST_SummaryStats(
             ST_Union(ST_Clip(rast, ST_Buffer(s.geom, 1600))),
             1, true
           ) AS stats
    FROM DEM
    WHERE ST_Intersects(rast, ST_Buffer(s.geom, 1600))
  ) elevation_stats
);

-- Roads by type to sample point distance:

-- CREATE INDEX idx_highway_tampere_geom_3067 
-- ON highway_tampere USING GIST (ST_Transform(geom, 3067));

ALTER TABLE highway_tampere 
ADD COLUMN IF NOT EXISTS geom_3067 geometry;

UPDATE highway_tampere 
-- create spatial index & convert highway_tampere to 3067
SET geom_3067 = ST_Transform(geom, 3067);

CREATE INDEX IF NOT EXISTS idx_highway_tampere_geom_3067 
ON highway_tampere USING GIST (geom_3067);

-- Change motorway to what you need

ALTER TABLE calculation_points
ADD COLUMN IF NOT EXISTS log_dist_motorway FLOAT;

UPDATE calculation_points cp
SET log_dist_motorway = subquery.log_distance
FROM (
  SELECT cp.id, LN(1 + MIN(ST_Distance(cp.geom, ht.geom_3067))) AS log_distance
  FROM calculation_points cp
  JOIN highway_tampere ht ON ht.highway = 'motorway'
  GROUP BY cp.id
) AS subquery
WHERE cp.id = subquery.id;


-- UPDATE calculation_points cp
-- SET log_dist_motorway = LN(1 + (
--   SELECT ST_Distance(cp.geom, ht.geom_3067)
--   FROM highway_tampere ht
--   WHERE ht.highway = 'motorway'
--   ORDER BY ST_Distance(cp.geom, ht.geom_3067)
--   LIMIT 1
-- ));

-- LN(1 + distance): Applies the natural logarithm to 1 + distance to smooth out large variations in distances.
-- 1 + distance: Ensures the value is never LN(0), which is undefined.
-- LN(x): Logarithm function in SQL.
-- ST_Distance(cp.geom, ht.geom_3067) calculates distance from calculation_points to highway_tampere
-- WHERE ht.highway = 'motorway'
-- ORDER BY ST_Distance(...): Sorts motorway geometries by distance to the current cp.geom.
-- LIMIT 1: Selects only the nearest motorway.

-- Cumulative road Length

ALTER TABLE calculation_points
ADD COLUMN IF NOT EXISTS motorway_length_800m FLOAT;

-- UPDATE calculation_points cp
-- SET motorway_length_800m = COALESCE(
--   (
--     SELECT SUM(ST_Length(ht.geom_3067))
--     FROM highway_tampere ht
--     WHERE 
--       ht.highway = 'motorway' AND
--       ST_Intersects(ht.geom_3067, ST_Buffer(cp.geom, 800))
--   ), 
--   0  -- Default to 0 if no motorways in buffer
-- );
-- WHERE cp.id BETWEEN 1 AND 1000; -- 46.95s to execute.

-- ht.highway = 'motorway' 
-- Filters only motorway roads.

-- ht.geom_3067 && ST_Expand(cp.geom, 800)
-- Uses a bounding box filter for performance optimization. 
-- This quickly excludes geometries that cannot possibly be within 800 meters.

-- ST_Intersects(ht.geom_3067, ST_Buffer(cp.geom, 800)) 
-- Ensures the motorway geometry actually falls within the 800-meter buffer around the sampled point.

-- SUM(ST_Length(ht.geom_3067)) 
-- Computes the total length of motorway segments that meet the criteria.

-- 705.757s to execute.
UPDATE calculation_points cp
SET motorway_length_800m = COALESCE(
  (
    SELECT SUM(ST_Length(ht.geom_3067))
    FROM highway_tampere ht
    WHERE ht.highway = 'motorway'
      AND ht.geom_3067 && ST_Expand(cp.geom, 800)  -- Bounding box filter
      AND ST_Intersects(ht.geom_3067, ST_Buffer(cp.geom, 800))
  ),
  0  -- Default to 0 if no motorways in buffer
);
-- WHERE cp.id BETWEEN 1 AND 1000; -- 41.707s to execute.

-- trunk: 709.176s
-- primary: 863.190s
-- secondary: 1259.801s
-- tertiary: 816.211s
-- residential: 1231.234s

-- Buildings Tampere

ALTER TABLE sampled_data
ADD COLUMN building_density_1600m FLOAT;

UPDATE sampled_data sd
SET building_density_1600m = COALESCE(
    (
        SELECT 
            COUNT(*) / (ST_Area(ST_Buffer(sd.geom, 1600)) / 1000000.0)  -- buildings/km2
        -- the actual area of the 800m buffer depends on the spatial reference system (SRS) used
        FROM 
            buildings_elevations be
        WHERE 
            ST_Intersects(be.geom, ST_Buffer(sd.geom, 1600))
    ),
    0
);
-- 1074.780s

-- building tpi, 15s to execute

ALTER TABLE sampled_data
ADD COLUMN local_building_height DOUBLE PRECISION,   -- Height of nearest building within 200m
ADD COLUMN avg_building_height_100m DOUBLE PRECISION, -- Average building height in 800m buffer
ADD COLUMN tpi_buildings_100m DOUBLE PRECISION;       -- TPI = local_building_height - avg_building_height_800m

WITH nearest_building AS (
  SELECT 
    sd.id,
    (SELECT be.roof_elevation 
     FROM buildings_elevations be 
     WHERE ST_DWithin(be.geom, sd.geom, 100)  -- Search within 100m
     ORDER BY be.geom <-> sd.geom  -- Find closest building
     LIMIT 1
    ) AS nearest_height
  FROM sampled_data sd
)
UPDATE sampled_data
SET local_build_height_100m = COALESCE(nearest_building.nearest_height, 0)
FROM nearest_building
WHERE sampled_data.id = nearest_building.id;

UPDATE sampled_data
SET avg_building_height_100m = COALESCE((
  SELECT AVG(be.roof_elevation)
  FROM buildings_elevations be
  WHERE ST_DWithin(be.geom, sampled_data.geom, 100)  -- 100m radius
), 0);

UPDATE sampled_data
SET building_tpi_100m = local_build_height_100m - avg_building_height_100m;

-- Check if sound is blocked

DELETE FROM sound_barrier
WHERE "MITTAUSERA" = 216235 AND NOT ( "TYYPPI" = 'aita' OR id = 1802 );

ALTER TABLE sampled_data
ADD COLUMN sound_blocked BOOLEAN;

CREATE INDEX IF NOT EXISTS idx_sound_barrier
ON sound_barrier USING GIST (geom);

ALTER TABLE sound_barrier 
ADD COLUMN IF NOT EXISTS geom_3067 geometry;

UPDATE sound_barrier 
SET geom_3067 = ST_Transform(geom, 3067);

-- Limit to first 10 samples - 171.858s

-- WITH nearest_road AS (
--   SELECT 
--     s.id AS sample_id,
--     h.id AS road_id,
--     ST_ClosestPoint(h.geom_3067, s.geom) AS closest_pt
--   FROM (SELECT * FROM sampled_data ORDER BY id LIMIT 10) s -- Limit to first 10 samples
--   JOIN highway_tampere h
--     ON ST_DWithin(s.geom, h.geom_3067, 5000)
--   ORDER BY s.id, ST_Distance(s.geom, h.geom_3067)
-- )
-- UPDATE sampled_data s
-- SET sound_blocked = sub.is_blocked
-- FROM (
--   SELECT DISTINCT ON (nr.sample_id)
--          nr.sample_id,
--          EXISTS (
--            SELECT 1
--            FROM sound_barrier sb
--            WHERE ST_Intersects(
--              ST_MakeLine(samp.geom, nr.closest_pt),
--              sb.geom_3067
--            )
--          ) AS is_blocked
--   FROM nearest_road nr
--   JOIN sampled_data samp
--     ON samp.id = nr.sample_id
--   ORDER BY nr.sample_id, ST_Distance(samp.geom, nr.closest_pt)
-- ) AS sub
-- WHERE s.id = sub.sample_id;

-- Limit to first 10 samples, w/o ST_DWithin(s.geom, h.geom_3067, 200) - 315.334s
-- Limit to first 10 samples, with ST_DWithin(s.geom, h.geom_3067, 200) - 1s

ALTER TABLE sampled_data 
ADD COLUMN IF NOT EXISTS dist_block DOUBLE PRECISION;

WITH nearest_road AS (
  SELECT 
    s.id AS sample_id,
    h.id AS road_id,
    ST_ClosestPoint(h.geom_3067, s.geom) AS closest_pt,
    ST_Distance(s.geom, h.geom_3067) AS road_distance
  FROM (SELECT * FROM sampled_data ORDER BY id) s
  JOIN highway_tampere h
    ON ST_DWithin(s.geom, h.geom_3067, 200)
    AND h.highway IN ('motorway', 'trunk')
  ORDER BY s.id, ST_Distance(s.geom, h.geom_3067)
),
sound_block_status AS (
  SELECT DISTINCT ON (nr.sample_id)
         nr.sample_id,
         nr.road_distance AS dist_to_road,
         EXISTS (
           SELECT 1
           FROM sound_barrier sb
           WHERE ST_Intersects(
             ST_MakeLine(samp.geom, nr.closest_pt),
             sb.geom_3067
           )
         ) AS is_blocked
  FROM nearest_road nr
  JOIN sampled_data samp
    ON samp.id = nr.sample_id
  ORDER BY nr.sample_id, nr.road_distance
)
UPDATE sampled_data s
SET sound_blocked = sb.is_blocked,
    dist_block = CASE 
                   WHEN sb.is_blocked THEN sb.dist_to_road
                   ELSE -sb.dist_to_road
                 END
FROM sound_block_status sb
WHERE s.id = sb.sample_id;

-- ALTER TABLE sampled_data  ADD COLUMN IF NOT EXISTS dist_block DOUBLE PRECISION;  WITH nearest_road AS (   SELECT      s.id AS sample_id,     h.id AS road_id,     ST_ClosestPoint(h.geom_3067, s.geom) AS closest_pt,     ST_Distance(s.geom, h.geom_3067) AS road_distance   FROM (SELECT * FROM sampled_data ORDER BY id) s   JOIN highway_tampere h     ON ST_DWithin(s.geom, h.geom_3067, 200)   ORDER BY s.id, ST_Distance(s.geom, h.geom_3067) ), sound_block_status AS (   SELECT DISTINCT ON (nr.sample_id)          nr.sample_id,          nr.road_distance AS dist_to_road,          EXISTS (            SELECT 1            FROM sound_barrier sb            WHERE ST_Intersects(              ST_MakeLine(samp.geom, nr.closest_pt),              sb.geom_3067            )          ) AS is_blocked   FROM nearest_road nr   JOIN sampled_data samp     ON samp.id = nr.sample_id   ORDER BY nr.sample_id, nr.road_distance ) UPDATE sampled_data s SET sound_blocked = sb.is_blocked,     dist_block = CASE                     WHEN sb.is_blocked THEN sb.dist_to_road                    ELSE -sb.dist_to_road                  END FROM sound_block_status sb WHERE s.id = sb.sample_id

-- crossings and traffic lights:

DELETE FROM traffic_light_digiroad 
WHERE NOT EXISTS (     
	SELECT 1     
	FROM highway_tampere     
	WHERE          
	highway_tampere.highway IN ('motorway', 'trunk') AND 		
	highway_tampere."tunnel:name:fi" IS NULL AND         
	ST_DWithin(             
		traffic_light_digiroad.geom,              
		highway_tampere.geom_3067,              
		20 -- 20 m
	) 
);  
	
DELETE FROM crossing_digiroad 
WHERE NOT EXISTS (     
	SELECT 1     
	FROM highway_tampere     
	WHERE          
	highway_tampere.highway IN ('motorway', 'trunk') AND 		       
	ST_DWithin(             
		crossing_digiroad.geom,              
		highway_tampere.geom_3067,              
		20 -- 20 m
	) 
); 

ALTER TABLE sampled_data  
ADD COLUMN IF NOT EXISTS lights_num_200m DOUBLE PRECISION;

ALTER TABLE sampled_data  
ADD COLUMN IF NOT EXISTS cross_num_200m DOUBLE PRECISION;

UPDATE sampled_data sd
SET lights_num_200m = (
    SELECT COUNT(*)
    FROM traffic_light_digiroad tld
    WHERE ST_DWithin(
        tld.geom, 
        sd.geom,
        200  -- 200 meters away from sample
    )
);

UPDATE sampled_data sd
SET cross_num_200m = (
    SELECT COUNT(*)
    FROM crossing_digiroad cd
    WHERE ST_DWithin(
        cd.geom,
        sd.geom,
        200  -- 200 meters away from sample
    )
);

-- Add traffic to sample data

CREATE TABLE sampled_data_traffic AS
SELECT sd.*,
t."date",
t."tmsNumber",
t.count_1,
t.count_2,
t.count_3,
t.count_4,
t.count_5,
t.count_6,
t.count_7,
t.count_9,
t.speed_1,
t.speed_2,
t.speed_3,
t.speed_4,
t.speed_5,
t.speed_6,
t.speed_7,
t.speed_9,
t.count_light,
t.count_heavy,
t.speed_light,
t.speed_heavy
FROM sampled_data sd
JOIN traffic t ON sd.tmsnumber = t."tmsNumber";

-- update data

ALTER TABLE sampled_data 
ADD COLUMN IF NOT EXISTS "date" DATE,
ADD COLUMN IF NOT EXISTS d_count_1 FLOAT,
ADD COLUMN IF NOT EXISTS d_count_2 FLOAT,
ADD COLUMN IF NOT EXISTS d_count_3 FLOAT,
ADD COLUMN IF NOT EXISTS d_count_4 FLOAT,
ADD COLUMN IF NOT EXISTS d_count_5 FLOAT,
ADD COLUMN IF NOT EXISTS d_count_6 FLOAT,
ADD COLUMN IF NOT EXISTS d_count_7 FLOAT,
ADD COLUMN IF NOT EXISTS d_count_9 FLOAT,
ADD COLUMN IF NOT EXISTS d_speed_1 FLOAT,
ADD COLUMN IF NOT EXISTS d_speed_2 FLOAT,
ADD COLUMN IF NOT EXISTS d_speed_3 FLOAT,
ADD COLUMN IF NOT EXISTS d_speed_4 FLOAT,
ADD COLUMN IF NOT EXISTS d_speed_5 FLOAT,
ADD COLUMN IF NOT EXISTS d_speed_6 FLOAT,
ADD COLUMN IF NOT EXISTS d_speed_7 FLOAT,
ADD COLUMN IF NOT EXISTS d_speed_9 FLOAT,
ADD COLUMN IF NOT EXISTS d_count_light FLOAT,
ADD COLUMN IF NOT EXISTS d_count_heavy FLOAT,
ADD COLUMN IF NOT EXISTS d_speed_light FLOAT,
ADD COLUMN IF NOT EXISTS d_speed_heavy FLOAT,
ADD COLUMN IF NOT EXISTS n_count_1 FLOAT,
ADD COLUMN IF NOT EXISTS n_count_2 FLOAT,
ADD COLUMN IF NOT EXISTS n_count_3 FLOAT,
ADD COLUMN IF NOT EXISTS n_count_4 FLOAT,
ADD COLUMN IF NOT EXISTS n_count_5 FLOAT,
ADD COLUMN IF NOT EXISTS n_count_6 FLOAT,
ADD COLUMN IF NOT EXISTS n_count_7 FLOAT,
ADD COLUMN IF NOT EXISTS n_count_9 FLOAT,
ADD COLUMN IF NOT EXISTS n_speed_1 FLOAT,
ADD COLUMN IF NOT EXISTS n_speed_2 FLOAT,
ADD COLUMN IF NOT EXISTS n_speed_3 FLOAT,
ADD COLUMN IF NOT EXISTS n_speed_4 FLOAT,
ADD COLUMN IF NOT EXISTS n_speed_5 FLOAT,
ADD COLUMN IF NOT EXISTS n_speed_6 FLOAT,
ADD COLUMN IF NOT EXISTS n_speed_7 FLOAT,
ADD COLUMN IF NOT EXISTS n_speed_9 FLOAT,
ADD COLUMN IF NOT EXISTS n_count_light FLOAT,
ADD COLUMN IF NOT EXISTS n_count_heavy FLOAT,
ADD COLUMN IF NOT EXISTS n_speed_light FLOAT,
ADD COLUMN IF NOT EXISTS n_speed_heavy FLOAT;


UPDATE sampled_data sd
SET 
	"date" = t."date",
    d_count_1 = t.count_1,
    d_count_2 = t.count_2,
    d_count_3 = t.count_3,
    d_count_4 = t.count_4,
    d_count_5 = t.count_5,
    d_count_6 = t.count_6,
    d_count_7 = t.count_7,
    d_count_9 = t.count_9,
    d_speed_1 = t.speed_1,
    d_speed_2 = t.speed_2,
    d_speed_3 = t.speed_3,
    d_speed_4 = t.speed_4,
    d_speed_5 = t.speed_5,
    d_speed_6 = t.speed_6,
    d_speed_7 = t.speed_7,
    d_speed_9 = t.speed_9,
    d_count_light = t.count_light,
    d_count_heavy = t.count_heavy,
    d_speed_light = t.speed_light,
    d_speed_heavy = t.speed_heavy,
    n_count_1 = t.count_1,
    n_count_2 = t.count_2,
    n_count_3 = t.count_3,
    n_count_4 = t.count_4,
    n_count_5 = t.count_5,
    n_count_6 = t.count_6,
    n_count_7 = t.count_7,
    n_count_9 = t.count_9,
    n_speed_1 = t.speed_1,
    n_speed_2 = t.speed_2,
    n_speed_3 = t.speed_3,
    n_speed_4 = t.speed_4,
    n_speed_5 = t.speed_5,
    n_speed_6 = t.speed_6,
    n_speed_7 = t.speed_7,
    n_speed_9 = t.speed_9,
    n_count_light = t.count_light,
    n_count_heavy = t.count_heavy,
    n_speed_light = t.speed_light,
    n_speed_heavy = t.speed_heavy
FROM sampled_data_traffic t
WHERE sd.id = t.id;