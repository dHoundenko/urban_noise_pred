CREATE INDEX IF NOT EXISTS hw_geom_idx ON highway_tampere USING GIST (geom_3067);
CREATE INDEX IF NOT EXISTS hw_highway_idx ON highway_tampere (highway);
CREATE INDEX IF NOT EXISTS ns_geom_idx ON all_tampere_samples USING GIST (geom);

WITH nearest AS (
  SELECT
    ns.id,
    -- motorway + link
    (
      SELECT ST_Distance(ns.geom, ht.geom_3067)
      FROM highway_tampere ht
      WHERE ht.highway IN ('motorway','motorway_link')
      ORDER BY ns.geom <-> ht.geom_3067
      LIMIT 1
    ) AS dist_motorway,
    -- trunk + link
    (
      SELECT ST_Distance(ns.geom, ht.geom_3067)
      FROM highway_tampere ht
      WHERE ht.highway IN ('trunk','trunk_link')
      ORDER BY ns.geom <-> ht.geom_3067
      LIMIT 1
    ) AS dist_trunk,
    -- primary + link
    (
      SELECT ST_Distance(ns.geom, ht.geom_3067)
      FROM highway_tampere ht
      WHERE ht.highway IN ('primary','primary_link')
      ORDER BY ns.geom <-> ht.geom_3067
      LIMIT 1
    ) AS dist_primary,
    -- secondary + link
    (
      SELECT ST_Distance(ns.geom, ht.geom_3067)
      FROM highway_tampere ht
      WHERE ht.highway IN ('secondary','secondary_link')
      ORDER BY ns.geom <-> ht.geom_3067
      LIMIT 1
    ) AS dist_secondary,
    -- tertiary + link
    (
      SELECT ST_Distance(ns.geom, ht.geom_3067)
      FROM highway_tampere ht
      WHERE ht.highway IN ('tertiary','tertiary_link')
      ORDER BY ns.geom <-> ht.geom_3067
      LIMIT 1
    ) AS dist_tertiary,
    -- residential + link
    (
      SELECT ST_Distance(ns.geom, ht.geom_3067)
      FROM highway_tampere ht
      WHERE ht.highway IN ('residential','residential_link')
      ORDER BY ns.geom <-> ht.geom_3067
      LIMIT 1
    ) AS dist_residential
  FROM all_tampere_samples ns
)
UPDATE all_tampere_samples ns
SET
  log_dist_motorway    = n.dist_motorway,
  log_dist_trunk       = n.dist_trunk,
  log_dist_primary     = n.dist_primary,
  log_dist_secondary   = n.dist_secondary,
  log_dist_tertiary    = n.dist_tertiary,
  log_dist_residential = n.dist_residential
FROM nearest n
WHERE ns.id = n.id;

-- 584 s
-- 243 s