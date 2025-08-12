-- DROP TABLE IF EXISTS big_buildings;
-- CREATE TABLE big_buildings AS
-- SELECT *
-- FROM buildings_elevations b
-- WHERE ST_Area(b.geom) > 1200;

-- 1. Add log distance calculation
WITH nearest_building AS (
  SELECT
    ns.id,
    CASE
      WHEN be.geom IS NOT NULL THEN ST_Distance(ns.geom, be.geom)
      ELSE -1
    END AS log_nearest_building_dist
  FROM all_tampere_samples ns
  LEFT JOIN LATERAL (
    SELECT be.geom
    FROM big_buildings be
    WHERE ST_DWithin(ns.geom, be.geom, 500)
    ORDER BY ns.geom <-> be.geom
    LIMIT 1
  ) be ON true
)

-- 2. Update the target table with the computed value
UPDATE all_tampere_samples ns
SET log_build_dist = nb.log_nearest_building_dist
FROM nearest_building nb
WHERE ns.id = nb.id;

-- idk s
-- 5s