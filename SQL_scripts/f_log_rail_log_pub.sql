-- log dist water

UPDATE all_tampere_samples ns
SET log_dist_water = (
    SELECT MIN(ST_Distance(ns.geom, wt.geom))
    FROM water wt
);

-- 105s
-- 52s

-- log dist railway

CREATE TABLE rail_geom AS
SELECT geom
FROM rail_tampere;

CREATE INDEX idx_rail_geom_geom
ON rail_geom
USING GIST (geom);

UPDATE all_tampere_samples ns
SET log_dist_pub = sub.dist
FROM (
  SELECT ns.id,
         ST_Distance(ns.geom, pt.geom) AS dist
  FROM all_tampere_samples ns
  CROSS JOIN LATERAL (
    SELECT pt.geom
    FROM rail_geom pt
    ORDER BY pt.geom <-> ns.geom
    LIMIT 1
  ) AS pt
) sub
WHERE ns.id = sub.id;

-- 212s