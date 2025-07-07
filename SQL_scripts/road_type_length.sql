-- 1450s

/*
  Using precomputed buffers,
  single‑pass aggregation with CASE‑WHEN pivot, and conditional updates.
*/

-- 1) Precompute buffers for all radii and index them
CREATE TEMP TABLE buf AS
SELECT 
  id, 
  geom,
  r       AS radius,
  ST_Buffer(geom, r) AS buffer_geom
FROM new_sampled
CROSS JOIN UNNEST(ARRAY[12.5,25,50,100,200,400,800,1600]) AS r;

CREATE INDEX ON buf USING GIST (buffer_geom);
ANALYZE buf;


-- 2) Aggregate lengths per id, radius & highway
WITH road_sums AS (
  SELECT
    b.id,
    b.radius,
    ht.highway,
    SUM(
      ST_Length(
        ST_Intersection(ht.geom_3067, b.buffer_geom)
      )
      * COALESCE(ht.lanes::integer, 1)
    ) AS total
  FROM buf b
  JOIN highway_tampere ht 
    ON ht.geom_3067 && b.buffer_geom
   AND ST_Intersects(ht.geom_3067, b.buffer_geom)
  WHERE ht.highway IN (
    'motorway','trunk','primary',
    'secondary','tertiary','residential'
  )
  GROUP BY b.id, b.radius, ht.highway
),

-- 3) Pivot to one row per id with one column per (radius × highway)
pivot AS (
  SELECT
    id,
    -- 12.5 m
    MAX(CASE WHEN radius = 12.5  AND highway = 'motorway'     THEN total ELSE 0 END) AS motorway_length_12_5m,
    MAX(CASE WHEN radius = 12.5  AND highway = 'trunk'        THEN total ELSE 0 END) AS trunk_length_12_5m,
    MAX(CASE WHEN radius = 12.5  AND highway = 'primary'      THEN total ELSE 0 END) AS primary_length_12_5m,
    MAX(CASE WHEN radius = 12.5  AND highway = 'secondary'    THEN total ELSE 0 END) AS secondary_length_12_5m,
    MAX(CASE WHEN radius = 12.5  AND highway = 'tertiary'     THEN total ELSE 0 END) AS tertiary_length_12_5m,
    MAX(CASE WHEN radius = 12.5  AND highway = 'residential'  THEN total ELSE 0 END) AS residential_length_12_5m,

    -- 25 m
    MAX(CASE WHEN radius = 25    AND highway = 'motorway'     THEN total ELSE 0 END) AS motorway_length_25m,
    MAX(CASE WHEN radius = 25    AND highway = 'trunk'        THEN total ELSE 0 END) AS trunk_length_25m,
    MAX(CASE WHEN radius = 25    AND highway = 'primary'      THEN total ELSE 0 END) AS primary_length_25m,
    MAX(CASE WHEN radius = 25    AND highway = 'secondary'    THEN total ELSE 0 END) AS secondary_length_25m,
    MAX(CASE WHEN radius = 25    AND highway = 'tertiary'     THEN total ELSE 0 END) AS tertiary_length_25m,
    MAX(CASE WHEN radius = 25    AND highway = 'residential'  THEN total ELSE 0 END) AS residential_length_25m,

    -- 50 m
    MAX(CASE WHEN radius = 50    AND highway = 'motorway'     THEN total ELSE 0 END) AS motorway_length_50m,
    MAX(CASE WHEN radius = 50    AND highway = 'trunk'        THEN total ELSE 0 END) AS trunk_length_50m,
    MAX(CASE WHEN radius = 50    AND highway = 'primary'      THEN total ELSE 0 END) AS primary_length_50m,
    MAX(CASE WHEN radius = 50    AND highway = 'secondary'    THEN total ELSE 0 END) AS secondary_length_50m,
    MAX(CASE WHEN radius = 50    AND highway = 'tertiary'     THEN total ELSE 0 END) AS tertiary_length_50m,
    MAX(CASE WHEN radius = 50    AND highway = 'residential'  THEN total ELSE 0 END) AS residential_length_50m,

    -- 100 m
    MAX(CASE WHEN radius = 100   AND highway = 'motorway'     THEN total ELSE 0 END) AS motorway_length_100m,
    MAX(CASE WHEN radius = 100   AND highway = 'trunk'        THEN total ELSE 0 END) AS trunk_length_100m,
    MAX(CASE WHEN radius = 100   AND highway = 'primary'      THEN total ELSE 0 END) AS primary_length_100m,
    MAX(CASE WHEN radius = 100   AND highway = 'secondary'    THEN total ELSE 0 END) AS secondary_length_100m,
    MAX(CASE WHEN radius = 100   AND highway = 'tertiary'     THEN total ELSE 0 END) AS tertiary_length_100m,
    MAX(CASE WHEN radius = 100   AND highway = 'residential'  THEN total ELSE 0 END) AS residential_length_100m,

    -- 200 m
    MAX(CASE WHEN radius = 200   AND highway = 'motorway'     THEN total ELSE 0 END) AS motorway_length_200m,
    MAX(CASE WHEN radius = 200   AND highway = 'trunk'        THEN total ELSE 0 END) AS trunk_length_200m,
    MAX(CASE WHEN radius = 200   AND highway = 'primary'      THEN total ELSE 0 END) AS primary_length_200m,
    MAX(CASE WHEN radius = 200   AND highway = 'secondary'    THEN total ELSE 0 END) AS secondary_length_200m,
    MAX(CASE WHEN radius = 200   AND highway = 'tertiary'     THEN total ELSE 0 END) AS tertiary_length_200m,
    MAX(CASE WHEN radius = 200   AND highway = 'residential'  THEN total ELSE 0 END) AS residential_length_200m,

    -- 400 m
    MAX(CASE WHEN radius = 400   AND highway = 'motorway'     THEN total ELSE 0 END) AS motorway_length_400m,
    MAX(CASE WHEN radius = 400   AND highway = 'trunk'        THEN total ELSE 0 END) AS trunk_length_400m,
    MAX(CASE WHEN radius = 400   AND highway = 'primary'      THEN total ELSE 0 END) AS primary_length_400m,
    MAX(CASE WHEN radius = 400   AND highway = 'secondary'    THEN total ELSE 0 END) AS secondary_length_400m,
    MAX(CASE WHEN radius = 400   AND highway = 'tertiary'     THEN total ELSE 0 END) AS tertiary_length_400m,
    MAX(CASE WHEN radius = 400   AND highway = 'residential'  THEN total ELSE 0 END) AS residential_length_400m,

    -- 800 m
    MAX(CASE WHEN radius = 800   AND highway = 'motorway'     THEN total ELSE 0 END) AS motorway_length_800m,
    MAX(CASE WHEN radius = 800   AND highway = 'trunk'        THEN total ELSE 0 END) AS trunk_length_800m,
    MAX(CASE WHEN radius = 800   AND highway = 'primary'      THEN total ELSE 0 END) AS primary_length_800m,
    MAX(CASE WHEN radius = 800   AND highway = 'secondary'    THEN total ELSE 0 END) AS secondary_length_800m,
    MAX(CASE WHEN radius = 800   AND highway = 'tertiary'     THEN total ELSE 0 END) AS tertiary_length_800m,
    MAX(CASE WHEN radius = 800   AND highway = 'residential'  THEN total ELSE 0 END) AS residential_length_800m,

    -- 1600 m
    MAX(CASE WHEN radius = 1600  AND highway = 'motorway'     THEN total ELSE 0 END) AS motorway_length_1600m,
    MAX(CASE WHEN radius = 1600  AND highway = 'trunk'        THEN total ELSE 0 END) AS trunk_length_1600m,
    MAX(CASE WHEN radius = 1600  AND highway = 'primary'      THEN total ELSE 0 END) AS primary_length_1600m,
    MAX(CASE WHEN radius = 1600  AND highway = 'secondary'    THEN total ELSE 0 END) AS secondary_length_1600m,
    MAX(CASE WHEN radius = 1600  AND highway = 'tertiary'     THEN total ELSE 0 END) AS tertiary_length_1600m,
    MAX(CASE WHEN radius = 1600  AND highway = 'residential'  THEN total ELSE 0 END) AS residential_length_1600m

  FROM road_sums
  GROUP BY id
)

-- 4) Apply all of those columns back to new_sampled in a single UPDATE
UPDATE new_sampled ns
SET
  motorway_length_12_5m   = p.motorway_length_12_5m,
  trunk_length_12_5m      = p.trunk_length_12_5m,
  primary_length_12_5m    = p.primary_length_12_5m,
  secondary_length_12_5m  = p.secondary_length_12_5m,
  tertiary_length_12_5m   = p.tertiary_length_12_5m,
  residential_length_12_5m= p.residential_length_12_5m,

  motorway_length_25m     = p.motorway_length_25m,
  trunk_length_25m        = p.trunk_length_25m,
  primary_length_25m      = p.primary_length_25m,
  secondary_length_25m    = p.secondary_length_25m,
  tertiary_length_25m     = p.tertiary_length_25m,
  residential_length_25m  = p.residential_length_25m,

  motorway_length_50m     = p.motorway_length_50m,
  trunk_length_50m        = p.trunk_length_50m,
  primary_length_50m      = p.primary_length_50m,
  secondary_length_50m    = p.secondary_length_50m,
  tertiary_length_50m     = p.tertiary_length_50m,
  residential_length_50m  = p.residential_length_50m,

  motorway_length_100m    = p.motorway_length_100m,
  trunk_length_100m       = p.trunk_length_100m,
  primary_length_100m     = p.primary_length_100m,
  secondary_length_100m   = p.secondary_length_100m,
  tertiary_length_100m    = p.tertiary_length_100m,
  residential_length_100m = p.residential_length_100m,

  motorway_length_200m    = p.motorway_length_200m,
  trunk_length_200m       = p.trunk_length_200m,
  primary_length_200m     = p.primary_length_200m,
  secondary_length_200m   = p.secondary_length_200m,
  tertiary_length_200m    = p.tertiary_length_200m,
  residential_length_200m = p.residential_length_200m,

  motorway_length_400m    = p.motorway_length_400m,
  trunk_length_400m       = p.trunk_length_400m,
  primary_length_400m     = p.primary_length_400m,
  secondary_length_400m   = p.secondary_length_400m,
  tertiary_length_400m    = p.tertiary_length_400m,
  residential_length_400m = p.residential_length_400m,

  motorway_length_800m    = p.motorway_length_800m,
  trunk_length_800m       = p.trunk_length_800m,
  primary_length_800m     = p.primary_length_800m,
  secondary_length_800m   = p.secondary_length_800m,
  tertiary_length_800m    = p.tertiary_length_800m,
  residential_length_800m = p.residential_length_800m,

  motorway_length_1600m    = p.motorway_length_1600m,
  trunk_length_1600m       = p.trunk_length_1600m,
  primary_length_1600m     = p.primary_length_1600m,
  secondary_length_1600m   = p.secondary_length_1600m,
  tertiary_length_1600m    = p.tertiary_length_1600m,
  residential_length_1600m = p.residential_length_1600m
FROM pivot p
WHERE ns.id = p.id;