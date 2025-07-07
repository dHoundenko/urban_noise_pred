-- 1. Add the column to store result
ALTER TABLE new_sampled ADD COLUMN IF NOT EXISTS build_blocks_road BOOLEAN;

-- 2. Core logic
WITH nearest_road AS (
  SELECT 
    s.id AS sample_id,
    r.id AS road_id,
    ST_ClosestPoint(r.geom, s.geom) AS closest_pt,
    ST_Distance(s.geom, r.geom) AS road_distance
  FROM new_sampled s
  JOIN relevant_osm_roads2 r
    ON ST_DWithin(s.geom, r.geom, 500)
  ORDER BY s.id, ST_Distance(s.geom, r.geom)
),
building_block_status AS (
  SELECT DISTINCT ON (nr.sample_id)
         nr.sample_id,
         EXISTS (
           SELECT 1
           FROM big_buildings b
           WHERE ST_Intersects(
             ST_MakeLine(samp.geom, nr.closest_pt),
             b.geom
           )
         ) AS build_blocks_road
  FROM nearest_road nr
  JOIN new_sampled samp ON samp.id = nr.sample_id
  ORDER BY nr.sample_id, nr.road_distance
)

-- 3. Final update
UPDATE new_sampled s
SET build_blocks_road = bbs.build_blocks_road
FROM building_block_status bbs
WHERE s.id = bbs.sample_id;