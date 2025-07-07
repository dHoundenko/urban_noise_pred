-- 22s

CREATE INDEX IF NOT EXISTS hw_geom_idx ON highway_tampere USING GIST (geom_3067);
CREATE INDEX IF NOT EXISTS hw_highway_idx ON highway_tampere (highway);
CREATE INDEX IF NOT EXISTS ns_geom_idx ON new_sampled USING GIST (geom);

WITH road_distances AS (
  SELECT
    ns.id,
    ht.highway,
    MIN(ST_Distance(ns.geom, ht.geom_3067)) AS min_distance
  FROM new_sampled ns
  JOIN highway_tampere ht
    ON ht.geom_3067
  GROUP BY ns.id, ht.highway
),
pivoted AS (
  SELECT
    id,
    MIN(CASE WHEN highway = 'motorway' THEN min_distance END) AS dist_motorway,
    MIN(CASE WHEN highway = 'trunk' THEN min_distance END) AS dist_trunk,
    MIN(CASE WHEN highway = 'primary' THEN min_distance END) AS dist_primary,
    MIN(CASE WHEN highway = 'secondary' THEN min_distance END) AS dist_secondary,
    MIN(CASE WHEN highway = 'tertiary' THEN min_distance END) AS dist_tertiary,
    MIN(CASE WHEN highway = 'residential' THEN min_distance END) AS dist_residential
  FROM road_distances
  GROUP BY id
)
UPDATE new_sampled ns
SET
  log_dist_motorway = LN(1 + p.dist_motorway),
  log_dist_trunk = LN(1 + p.dist_trunk),
  log_dist_primary = LN(1 + p.dist_primary),
  log_dist_secondary = LN(1 + p.dist_secondary),
  log_dist_tertiary = LN(1 + p.dist_tertiary)),
  log_dist_residential = LN(1 + p.dist_residential)
FROM pivoted p
WHERE ns.id = p.id;