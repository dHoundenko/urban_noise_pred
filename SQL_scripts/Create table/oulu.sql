DROP TABLE IF EXISTS melu_low; 
CREATE TABLE melu_low (   
  id       SERIAL PRIMARY KEY,   
  geom     geometry(Polygon, 3067),  
  melu_db  TEXT 
);  
WITH   buffers AS 
(     
  SELECT       ST_Union(         
    ST_Buffer(           
      ST_Transform(os.geom, 3067),             2000                                   
      )       ) 
      AS geom_buf     
      FROM oulu_stations os   ),   
      paiva AS (     
    SELECT       ST_Union(geom) AS geom_paiva     FROM melu_paiva   ),   diff AS (     SELECT       ST_Difference(b.geom_buf, p.geom_paiva) AS geom_diff     FROM buffers b, paiva p   ) INSERT INTO melu_low (geom, melu_db) SELECT   dmp.geom::geometry(Polygon, 3067)  AS geom,   'alle 45 dB'                       AS melu_db FROM (   SELECT (ST_Dump(geom_diff)).geom   FROM diff ) AS dmp WHERE GeometryType(dmp.geom) = 'POLYGON'


-- Visual

CREATE TABLE melu_paiva_mod (
  id       SERIAL PRIMARY KEY,
  geom     geometry(Polygon, 3067),
  melu_db  TEXT
);

INSERT INTO melu_paiva_mod (geom, melu_db)
SELECT geom, melu_db
FROM melu_paiva
WHERE melu_db != 'alle 45 dB';

-- 1. Drop old table if exists, and create fresh melu_low
DROP TABLE IF EXISTS melu_low;
CREATE TABLE melu_low (
  id       SERIAL PRIMARY KEY,
  geom     geometry(Polygon, 3067),
  melu_db  TEXT
);

-- 2. Compute buffer-union, difference, split into patches, and insert
WITH
  buffers AS (
    SELECT
      ST_Union(
        ST_Buffer(
          ht.geom_3067,  -- Use pre-transformed column (now 3067)
          2000           -- 2000m buffer
        )
      ) AS geom_buf
    FROM highway_tampere ht
    WHERE ht.highway IN ('motorway', 'trunk')
  ),
  paiva AS (
    SELECT
      ST_Union(geom) AS geom_paiva
    FROM melu_paiva_mod
  ),
  diff AS (
    SELECT
      ST_Difference(b.geom_buf, p.geom_paiva) AS geom_diff
    FROM buffers b, paiva p
  )
INSERT INTO melu_low (geom, melu_db)
SELECT
  ST_CollectionExtract(dmp.geom, 3) AS geom,  -- Force Polygon type
  'alle 45 dB' AS melu_db
FROM (
  SELECT (ST_Dump(geom_diff)).geom
  FROM diff
) AS dmp;