-- Ensure stats are fresh (optional but recommended after big loads)
ANALYZE buildings_elevations;
ANALYZE all_tampere_samples;

-- One-pass update for 8 radii: 12.5, 25, 50, 100, 200, 400, 800, 1600 (meters)
WITH s AS (
  SELECT id, geom
  FROM all_tampere_samples
),
p AS (
  SELECT
    s.id,

    -- 12.5 m
    a12_5.n / (pi() * 12.5 * 12.5 / 1000000.0)                     AS density_12_5m,
    n12_5.nearest                                                  AS nearest_12_5m,
    a12_5.avg                                                      AS avg_12_5m,

    -- 25 m
    a25.n   / (pi() * 25 * 25 / 1000000.0)                         AS density_25m,
    n25.nearest                                                    AS nearest_25m,
    a25.avg                                                        AS avg_25m,

    -- 50 m
    a50.n   / (pi() * 50 * 50 / 1000000.0)                         AS density_50m,
    n50.nearest                                                    AS nearest_50m,
    a50.avg                                                        AS avg_50m,

    -- 100 m
    a100.n  / (pi() * 100 * 100 / 1000000.0)                       AS density_100m,
    n100.nearest                                                   AS nearest_100m,
    a100.avg                                                       AS avg_100m,

    -- 200 m
    a200.n  / (pi() * 200 * 200 / 1000000.0)                       AS density_200m,
    n200.nearest                                                   AS nearest_200m,
    a200.avg                                                       AS avg_200m,

    -- 400 m
    a400.n  / (pi() * 400 * 400 / 1000000.0)                       AS density_400m,
    n400.nearest                                                   AS nearest_400m,
    a400.avg                                                       AS avg_400m,

    -- 800 m
    a800.n  / (pi() * 800 * 800 / 1000000.0)                       AS density_800m,
    n800.nearest                                                   AS nearest_800m,
    a800.avg                                                       AS avg_800m,

    -- 1600 m
    a1600.n / (pi() * 1600 * 1600 / 1000000.0)                     AS density_1600m,
    n1600.nearest                                                  AS nearest_1600m,
    a1600.avg                                                      AS avg_1600m

  FROM s
  -- 12.5
  LEFT JOIN LATERAL (
    SELECT COUNT(*)::float8 AS n, AVG(be.roof_elevation) AS avg
    FROM buildings_elevations be
    WHERE ST_DWithin(be.geom, s.geom, 12.5)
  ) a12_5 ON TRUE
  LEFT JOIN LATERAL (
    SELECT be.roof_elevation AS nearest
    FROM buildings_elevations be
    WHERE ST_DWithin(be.geom, s.geom, 12.5)
    ORDER BY be.geom <-> s.geom
    LIMIT 1
  ) n12_5 ON TRUE

  -- 25
  LEFT JOIN LATERAL (
    SELECT COUNT(*)::float8 AS n, AVG(be.roof_elevation) AS avg
    FROM buildings_elevations be
    WHERE ST_DWithin(be.geom, s.geom, 25.0)
  ) a25 ON TRUE
  LEFT JOIN LATERAL (
    SELECT be.roof_elevation AS nearest
    FROM buildings_elevations be
    WHERE ST_DWithin(be.geom, s.geom, 25.0)
    ORDER BY be.geom <-> s.geom
    LIMIT 1
  ) n25 ON TRUE

  -- 50
  LEFT JOIN LATERAL (
    SELECT COUNT(*)::float8 AS n, AVG(be.roof_elevation) AS avg
    FROM buildings_elevations be
    WHERE ST_DWithin(be.geom, s.geom, 50.0)
  ) a50 ON TRUE
  LEFT JOIN LATERAL (
    SELECT be.roof_elevation AS nearest
    FROM buildings_elevations be
    WHERE ST_DWithin(be.geom, s.geom, 50.0)
    ORDER BY be.geom <-> s.geom
    LIMIT 1
  ) n50 ON TRUE

  -- 100
  LEFT JOIN LATERAL (
    SELECT COUNT(*)::float8 AS n, AVG(be.roof_elevation) AS avg
    FROM buildings_elevations be
    WHERE ST_DWithin(be.geom, s.geom, 100.0)
  ) a100 ON TRUE
  LEFT JOIN LATERAL (
    SELECT be.roof_elevation AS nearest
    FROM buildings_elevations be
    WHERE ST_DWithin(be.geom, s.geom, 100.0)
    ORDER BY be.geom <-> s.geom
    LIMIT 1
  ) n100 ON TRUE

  -- 200
  LEFT JOIN LATERAL (
    SELECT COUNT(*)::float8 AS n, AVG(be.roof_elevation) AS avg
    FROM buildings_elevations be
    WHERE ST_DWithin(be.geom, s.geom, 200.0)
  ) a200 ON TRUE
  LEFT JOIN LATERAL (
    SELECT be.roof_elevation AS nearest
    FROM buildings_elevations be
    WHERE ST_DWithin(be.geom, s.geom, 200.0)
    ORDER BY be.geom <-> s.geom
    LIMIT 1
  ) n200 ON TRUE

  -- 400
  LEFT JOIN LATERAL (
    SELECT COUNT(*)::float8 AS n, AVG(be.roof_elevation) AS avg
    FROM buildings_elevations be
    WHERE ST_DWithin(be.geom, s.geom, 400.0)
  ) a400 ON TRUE
  LEFT JOIN LATERAL (
    SELECT be.roof_elevation AS nearest
    FROM buildings_elevations be
    WHERE ST_DWithin(be.geom, s.geom, 400.0)
    ORDER BY be.geom <-> s.geom
    LIMIT 1
  ) n400 ON TRUE

  -- 800
  LEFT JOIN LATERAL (
    SELECT COUNT(*)::float8 AS n, AVG(be.roof_elevation) AS avg
    FROM buildings_elevations be
    WHERE ST_DWithin(be.geom, s.geom, 800.0)
  ) a800 ON TRUE
  LEFT JOIN LATERAL (
    SELECT be.roof_elevation AS nearest
    FROM buildings_elevations be
    WHERE ST_DWithin(be.geom, s.geom, 800.0)
    ORDER BY be.geom <-> s.geom
    LIMIT 1
  ) n800 ON TRUE

  -- 1600
  LEFT JOIN LATERAL (
    SELECT COUNT(*)::float8 AS n, AVG(be.roof_elevation) AS avg
    FROM buildings_elevations be
    WHERE ST_DWithin(be.geom, s.geom, 1600.0)
  ) a1600 ON TRUE
  LEFT JOIN LATERAL (
    SELECT be.roof_elevation AS nearest
    FROM buildings_elevations be
    WHERE ST_DWithin(be.geom, s.geom, 1600.0)
    ORDER BY be.geom <-> s.geom
    LIMIT 1
  ) n1600 ON TRUE
)
UPDATE all_tampere_samples t
SET
  -- densities (buildings / km²)
  building_density_12_5m  = COALESCE(p.density_12_5m,  0),
  building_density_25m    = COALESCE(p.density_25m,    0),
  building_density_50m    = COALESCE(p.density_50m,    0),
  building_density_100m   = COALESCE(p.density_100m,   0),
  building_density_200m   = COALESCE(p.density_200m,   0),
  building_density_400m   = COALESCE(p.density_400m,   0),
  building_density_800m   = COALESCE(p.density_800m,   0),
  building_density_1600m  = COALESCE(p.density_1600m,  0),

  -- local (nearest) building heights
  local_build_height_12_5m = COALESCE(p.nearest_12_5m, 0),
  local_build_height_25m   = COALESCE(p.nearest_25m,   0),
  local_build_height_50m   = COALESCE(p.nearest_50m,   0),
  local_build_height_100m  = COALESCE(p.nearest_100m,  0),
  local_build_height_200m  = COALESCE(p.nearest_200m,  0),
  local_build_height_400m  = COALESCE(p.nearest_400m,  0),
  local_build_height_800m  = COALESCE(p.nearest_800m,  0),
  local_build_height_1600m = COALESCE(p.nearest_1600m, 0),

  -- average building heights
  avg_building_height_12_5m = COALESCE(p.avg_12_5m,    0),
  avg_building_height_25m   = COALESCE(p.avg_25m,      0),
  avg_building_height_50m   = COALESCE(p.avg_50m,      0),
  avg_building_height_100m  = COALESCE(p.avg_100m,     0),
  avg_building_height_200m  = COALESCE(p.avg_200m,     0),
  avg_building_height_400m  = COALESCE(p.avg_400m,     0),
  avg_building_height_800m  = COALESCE(p.avg_800m,     0),
  avg_building_height_1600m = COALESCE(p.avg_1600m,    0),

  -- TPI = nearest - average
  building_tpi_12_5m  = COALESCE(p.nearest_12_5m,  0) - COALESCE(p.avg_12_5m,   0),
  building_tpi_25m    = COALESCE(p.nearest_25m,    0) - COALESCE(p.avg_25m,     0),
  building_tpi_50m    = COALESCE(p.nearest_50m,    0) - COALESCE(p.avg_50m,     0),
  building_tpi_100m   = COALESCE(p.nearest_100m,   0) - COALESCE(p.avg_100m,    0),
  building_tpi_200m   = COALESCE(p.nearest_200m,   0) - COALESCE(p.avg_200m,    0),
  building_tpi_400m   = COALESCE(p.nearest_400m,   0) - COALESCE(p.avg_400m,    0),
  building_tpi_800m   = COALESCE(p.nearest_800m,   0) - COALESCE(p.avg_800m,    0),
  building_tpi_1600m  = COALESCE(p.nearest_1600m,  0) - COALESCE(p.avg_1600m,   0)
FROM p
WHERE t.id = p.id;

-- 180s