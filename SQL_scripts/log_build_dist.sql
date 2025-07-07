DROP TABLE IF EXISTS big_buildings;
CREATE TABLE big_buildings AS
SELECT *
FROM buildings_elevations b
WHERE ST_Area(b.geom) > 1200;

ALTER TABLE new_sampled 
ADD COLUMN IF NOT EXISTS log_build_dist DOUBLE precision;

-- 1. Add log distance calculation
WITH nearest_building AS (
  SELECT
    ns.id,
    CASE
      WHEN be.geom IS NOT NULL THEN LN(1 + ST_Distance(ns.geom, be.geom))
      ELSE -LN(3)
    END AS log_nearest_building_dist
  FROM new_sampled ns
  LEFT JOIN LATERAL (
    SELECT be.geom
    FROM big_buildings be
    WHERE ST_DWithin(ns.geom, be.geom, 500)
    ORDER BY ns.geom <-> be.geom
    LIMIT 1
  ) be ON true
)

-- 2. Update the target table with the computed value
UPDATE new_sampled ns
SET log_build_dist = nb.log_nearest_building_dist
FROM nearest_building nb
WHERE ns.id = nb.id;