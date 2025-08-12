-- raster2pgsql -s 3067 -I -C -M M4211.tif public.m4211 | psql -U postgres -d your_database
-- raster2pgsql -s 3067 -I -C -M M4212.tif public.m4212 | psql -U postgres -d your_database
-- raster2pgsql -s 3067 -I -C -M M4213.tif public.m4213 | psql -U postgres -d your_database
-- raster2pgsql -s 3067 -I -C -M M4214.tif public.m4214 | psql -U postgres -d your_database

-- raster2pgsql -s 3067 -I -C -M R4411.tif public.r4411 | psql -U postgres -d your_database
-- raster2pgsql -s 3067 -I -C -M R4412.tif public.r4412 | psql -U postgres -d your_database
-- raster2pgsql -s 3067 -I -C -M R4413.tif public.r4413 | psql -U postgres -d your_database
-- raster2pgsql -s 3067 -I -C -M R4414.tif public.r4414 | psql -U postgres -d your_database

-- CREATE TABLE DEM AS
-- SELECT ST_Union(rast) AS rast
-- FROM (
--     SELECT rast FROM r4411
--     UNION ALL
-- 	SELECT rast FROM r4412
--     UNION ALL
--     SELECT rast FROM r4413
--     UNION ALL
--     SELECT rast FROM r4414
-- ) AS combined_rasters;

-- elevation_DEM
UPDATE all_tampere_samples ns
SET elevation_DEM = (
    SELECT ST_Value(d.rast, 1, ns.geom)
    FROM DEM d
    WHERE ST_Intersects(d.rast, ns.geom)
    LIMIT 1
);

-- 196s
-- 102s

-- One CTE to build all buffers once, using a low quad_segs to keep polygons light
WITH s AS (
  SELECT
      ns.id,
      ns.geom,
      ns.elevation_dem,
      ST_Buffer(ns.geom,  12.5, 'quad_segs=4')  AS b12_5,
      ST_Buffer(ns.geom,  25.0, 'quad_segs=4')  AS b25,
      ST_Buffer(ns.geom,  50.0, 'quad_segs=4')  AS b50,
      ST_Buffer(ns.geom, 100.0, 'quad_segs=4')  AS b100,
      ST_Buffer(ns.geom, 200.0, 'quad_segs=4')  AS b200,
      ST_Buffer(ns.geom, 400.0, 'quad_segs=4')  AS b400,
      ST_Buffer(ns.geom, 800.0, 'quad_segs=4')  AS b800,
      ST_Buffer(ns.geom, 1600.0,'quad_segs=4')  AS b1600
  FROM all_tampere_samples ns
),
m AS (
  SELECT
    s.id,

    -- For each radius, clip tiles to the buffer, aggregate stats across intersecting tiles
    -- (just as a good rule) exclude_nodata=true so nodata is ignored 
    (SELECT (ST_SummaryStatsAgg(ST_Clip(d.rast, s.b12_5,  true), 1, true)).mean
     FROM dem d
     WHERE ST_Intersects(d.rast, s.b12_5))  AS mean_12_5,

    (SELECT (ST_SummaryStatsAgg(ST_Clip(d.rast, s.b25,    true), 1, true)).mean
     FROM dem d
     WHERE ST_Intersects(d.rast, s.b25))    AS mean_25,

    (SELECT (ST_SummaryStatsAgg(ST_Clip(d.rast, s.b50,    true), 1, true)).mean
     FROM dem d
     WHERE ST_Intersects(d.rast, s.b50))    AS mean_50,

    (SELECT (ST_SummaryStatsAgg(ST_Clip(d.rast, s.b100,   true), 1, true)).mean
     FROM dem d
     WHERE ST_Intersects(d.rast, s.b100))   AS mean_100,

    (SELECT (ST_SummaryStatsAgg(ST_Clip(d.rast, s.b200,   true), 1, true)).mean
     FROM dem d
     WHERE ST_Intersects(d.rast, s.b200))   AS mean_200,

    (SELECT (ST_SummaryStatsAgg(ST_Clip(d.rast, s.b400,   true), 1, true)).mean
     FROM dem d
     WHERE ST_Intersects(d.rast, s.b400))   AS mean_400,

    (SELECT (ST_SummaryStatsAgg(ST_Clip(d.rast, s.b800,   true), 1, true)).mean
     FROM dem d
     WHERE ST_Intersects(d.rast, s.b800))   AS mean_800,

    (SELECT (ST_SummaryStatsAgg(ST_Clip(d.rast, s.b1600,  true), 1, true)).mean
     FROM dem d
     WHERE ST_Intersects(d.rast, s.b1600))  AS mean_1600

  FROM s
)
UPDATE all_tampere_samples ns
SET
  elevation_tpi_12_5m = ns.elevation_dem - m.mean_12_5,
  elevation_tpi_25m   = ns.elevation_dem - m.mean_25,
  elevation_tpi_50m   = ns.elevation_dem - m.mean_50,
  elevation_tpi_100m  = ns.elevation_dem - m.mean_100,
  elevation_tpi_200m  = ns.elevation_dem - m.mean_200,
  elevation_tpi_400m  = ns.elevation_dem - m.mean_400,
  elevation_tpi_800m  = ns.elevation_dem - m.mean_800,
  elevation_tpi_1600m = ns.elevation_dem - m.mean_1600
FROM m
WHERE ns.id = m.id;

-- idk
-- 1095s





























UPDATE all_tampere_samples s
SET elevation_tpi_50m = s.elevation_DEM - (
  SELECT (stats).mean
  FROM (
    SELECT ST_SummaryStats(
             ST_Union(ST_Clip(rast, ST_Buffer(s.geom, 50))),
             1, true
           ) AS stats
    FROM DEM
    WHERE ST_Intersects(rast, ST_Buffer(s.geom, 50))
  ) elevation_stats
);

-- -- elevation_TPI, 3856s
-- -- 1) Precompute buffers
-- CREATE TEMP TABLE buf AS
-- SELECT 
--   ns.id,
--   ns.geom,
--   r.radius,
--   ST_Buffer(ns.geom, r.radius) AS buffer_geom
-- FROM all_tampere_samples AS ns
-- CROSS JOIN UNNEST(ARRAY[12.5,25,50,100,200,400,800,1600]) AS r(radius);

-- CREATE INDEX ON buf USING GIST(buffer_geom);
-- ANALYZE buf;

-- -- 2) Compute aggregated mean elevation for each buffer
-- WITH elevation_means AS (
--   SELECT 
--     b.id,
--     b.radius,
--     (ST_SummaryStatsAgg(
--        ST_Clip(d.rast, b.buffer_geom)
--      , 1
--      , true
--      )).mean AS mean_elevation
--   FROM buf AS b
--   JOIN DEM AS d
--     ON d.rast && b.buffer_geom
--    AND ST_Intersects(d.rast, b.buffer_geom)
--   GROUP BY b.id, b.radius
-- ),

-- -- 3) Pivot into columns
-- pivot AS (
--   SELECT
--     id,
--     MAX(CASE WHEN radius = 12.5  THEN mean_elevation END) AS mean_12_5m,
--     MAX(CASE WHEN radius = 25    THEN mean_elevation END) AS mean_25m,
--     MAX(CASE WHEN radius = 50    THEN mean_elevation END) AS mean_50m,
--     MAX(CASE WHEN radius = 100   THEN mean_elevation END) AS mean_100m,
--     MAX(CASE WHEN radius = 200   THEN mean_elevation END) AS mean_200m,
--     MAX(CASE WHEN radius = 400   THEN mean_elevation END) AS mean_400m,
--     MAX(CASE WHEN radius = 800   THEN mean_elevation END) AS mean_800m,
--     MAX(CASE WHEN radius = 1600  THEN mean_elevation END) AS mean_1600m
--   FROM elevation_means
--   GROUP BY id
-- )

-- -- 4) One‐shot update
-- UPDATE all_tampere_samples AS ns
-- SET
--   elevation_tpi_12_5m  = ns.elevation_DEM - p.mean_12_5m,
--   elevation_tpi_25m    = ns.elevation_DEM - p.mean_25m,
--   elevation_tpi_50m    = ns.elevation_DEM - p.mean_50m,
--   elevation_tpi_100m   = ns.elevation_DEM - p.mean_100m,
--   elevation_tpi_200m   = ns.elevation_DEM - p.mean_200m,
--   elevation_tpi_400m   = ns.elevation_DEM - p.mean_400m,
--   elevation_tpi_800m   = ns.elevation_DEM - p.mean_800m,
--   elevation_tpi_1600m  = ns.elevation_DEM - p.mean_1600m
-- FROM pivot AS p
-- WHERE ns.id = p.id;




-- -- -- elevation
-- -- CREATE INDEX ON DEM USING GIST (ST_ConvexHull(rast));
-- -- CREATE INDEX ON all_tampere_samples USING GIST (geom);

-- -- CREATE INDEX dem_rast_gix ON dem USING GIST (ST_Envelope(rast));
-- -- ANALYZE dem;
-- -- CLUSTER all_tampere_samples USING idx_all_tampere_samples_geom_gist;
-- -- ANALYZE all_tampere_samples;


-- -- -- 1. point elevations
-- -- WITH point_dem AS (
-- --   SELECT DISTINCT ON (ns.id)
-- --     ns.id,
-- --     ST_Value(d.rast, 1, ns.geom) AS elevation
-- --   FROM all_tampere_samples ns
-- --   JOIN dem d
-- --     ON ST_Intersects(d.rast, ns.geom)
-- --   ORDER BY ns.id, ST_Value(d.rast, 1, ns.geom) DESC
-- -- ),

-- -- -- 2. all buffers
-- -- buffers AS (
-- --   SELECT
-- --     ns.id,
-- --     r.radius,
-- --     ST_Buffer(ns.geom, r.radius) AS geom
-- --   FROM all_tampere_samples ns
-- --   CROSS JOIN (VALUES (12.5),(25),(50),(100),(200),(400),(800),(1600)) AS r(radius)
-- -- ),

-- -- -- 3. mean elevation per buffer
-- -- buffer_stats AS (
-- --   SELECT
-- --     b.id,
-- --     b.radius,
-- --     (ST_SummaryStatsAgg(d.rast, 1, TRUE)).mean AS mean_elev
-- --   FROM buffers b
-- --   JOIN dem d
-- --     ON d.rast && b.geom              -- fast BBOX filter
-- --    AND ST_Intersects(d.rast, b.geom) -- exact
-- --   GROUP BY b.id, b.radius
-- -- ),

-- -- -- 4. pivot into columns
-- -- pivot_stats AS (
-- --   SELECT
-- --     id,
-- --     MAX(mean_elev) FILTER (WHERE radius = 12.5)  AS mean_12_5m,
-- --     MAX(mean_elev) FILTER (WHERE radius =   25)  AS mean_25m,
-- --     MAX(mean_elev) FILTER (WHERE radius =   50)  AS mean_50m,
-- --     MAX(mean_elev) FILTER (WHERE radius =  100)  AS mean_100m,
-- --     MAX(mean_elev) FILTER (WHERE radius =  200)  AS mean_200m,
-- --     MAX(mean_elev) FILTER (WHERE radius =  400)  AS mean_400m,
-- --     MAX(mean_elev) FILTER (WHERE radius =  800)  AS mean_800m,
-- --     MAX(mean_elev) FILTER (WHERE radius = 1600)  AS mean_1600m
-- --   FROM buffer_stats
-- --   GROUP BY id
-- -- )

-- -- -- 5. one single update
-- -- UPDATE all_tampere_samples ns
-- -- SET
-- --   elevation_dem     = pd.elevation,
-- --   elevation_tpi_12_5m  = pd.elevation - COALESCE(ps.mean_12_5m,  0),
-- --   elevation_tpi_25m    = pd.elevation - COALESCE(ps.mean_25m,    0),
-- --   elevation_tpi_50m    = pd.elevation - COALESCE(ps.mean_50m,    0),
-- --   elevation_tpi_100m   = pd.elevation - COALESCE(ps.mean_100m,   0),
-- --   elevation_tpi_200m   = pd.elevation - COALESCE(ps.mean_200m,   0),
-- --   elevation_tpi_400m   = pd.elevation - COALESCE(ps.mean_400m,   0),
-- --   elevation_tpi_800m   = pd.elevation - COALESCE(ps.mean_800m,   0),
-- --   elevation_tpi_1600m  = pd.elevation - COALESCE(ps.mean_1600m,  0)
-- -- FROM point_dem pd
-- -- JOIN pivot_stats ps
-- --   ON ps.id = pd.id
-- -- WHERE ns.id = pd.id;
