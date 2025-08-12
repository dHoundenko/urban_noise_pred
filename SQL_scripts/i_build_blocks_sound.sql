CREATE TABLE all_roads_tampere AS
SELECT
    ht.highway,
    ht.geom,
    ht.geom_3067,
    ns.geom AS sample_geom,
FROM highway_tampere ht
JOIN all_tampere_samples ns
  ON ST_DWithin(ht.geom_3067, ns.geom, 10)
WHERE ht.highway IN (
    'motorway', 'motorway_link',
    'trunk', 'trunk_link',
    'primary', 'primary_link',
    'secondary', 'secondary_link', 
    'tertiary', 'tertiary_link', 
    'residential', 'residential_link'
);

CREATE INDEX ON all_roads_tampere     USING GIST (geom_3067);

CREATE TABLE all_buildings_tampere AS
SELECT
    be.geom,
    ns.geom AS sample_geom,
FROM buildings_elevations be
JOIN all_tampere_samples ns
  ON ST_DWithin(be.geom, ns.geom, 10)

-- 1. Ensure your two columns exist
ALTER TABLE all_tampere_samples 
  ADD COLUMN IF NOT EXISTS block_build_num DOUBLE PRECISION DEFAULT 0,
  ADD COLUMN IF NOT EXISTS log_block_dist   DOUBLE PRECISION DEFAULT -1;

-- 2. Find the closest point on the nearest road (within 500 m) for each sample
WITH nearest_road AS (
  SELECT 
    sample_id,
    closest_pt,
    road_distance
  FROM (
    SELECT
      s.id                                          AS sample_id,
      ST_ClosestPoint(r.geom_3067, s.geom)          AS closest_pt,
      ST_Distance(s.geom, r.geom_3067)              AS road_distance,
      ROW_NUMBER() OVER (
        PARTITION BY s.id 
        ORDER BY ST_Distance(s.geom, r.geom_3067)
      )                                             AS rn
    FROM all_tampere_samples s
    JOIN all_roads_tampere r
      ON ST_DWithin(s.geom, r.geom_3067, 500)
  ) t
  WHERE rn = 1
),

-- 3. Count & measure buildings intersecting that line
building_stats AS (
  SELECT
    nr.sample_id,
    COUNT(b.*)                                       AS block_build_num,
    COALESCE(
      MIN(ST_Distance(s.geom, b.geom)), 
      -1
    )                                                AS log_block_dist
  FROM nearest_road nr
  JOIN all_tampere_samples    s ON s.id = nr.sample_id
  LEFT JOIN all_buildings_tampere b
    ON ST_Intersects(
         ST_MakeLine(s.geom, nr.closest_pt),
         b.geom
       )
  GROUP BY nr.sample_id
)

-- 4. Write back into your table
UPDATE all_tampere_samples s
SET
  block_build_num = bs.block_build_num,
  log_block_dist   = bs.log_block_dist
FROM building_stats bs
WHERE s.id = bs.sample_id;

-- idk s
-- 38s