ALTER TABLE new_sampled
ADD COLUMN building_density_12_5m FLOAT;

UPDATE new_sampled sd
SET building_density_12_5m = COALESCE(
    (
        SELECT 
            COUNT(*) / (ST_Area(ST_Buffer(sd.geom, 12.5)) / 1000000.0)  -- buildings/km2
        -- the actual area of the buffer depends on the spatial reference system (SRS) used
        FROM 
            buildings_elevations be
        WHERE 
            ST_Intersects(be.geom, ST_Buffer(sd.geom, 12.5))
    ),
    0
);

WITH nearest_building AS (
  SELECT 
    sd.id,
    (SELECT be.roof_elevation 
     FROM buildings_elevations be 
     WHERE ST_DWithin(be.geom, sd.geom, 12.5)  -- Search within 12_5m
     ORDER BY be.geom <-> sd.geom  -- Find closest building
     LIMIT 1
    ) AS nearest_height
  FROM new_sampled sd
)
UPDATE new_sampled
SET local_build_height_12_5m = COALESCE(nearest_building.nearest_height, 0)
FROM nearest_building
WHERE new_sampled.id = nearest_building.id;

UPDATE new_sampled
SET avg_building_height_12_5m = COALESCE((
  SELECT AVG(be.roof_elevation)
  FROM buildings_elevations be
  WHERE ST_DWithin(be.geom, new_sampled.geom, 12.5)  -- 12_5m radius
), 0);

UPDATE new_sampled
SET building_tpi_12_5m = local_build_height_12_5m - avg_building_height_12_5m;

-- -- buildings

-- -- 0. Build spatial indexes to support fast spatial filtering & nearest
-- CREATE INDEX ON new_sampled USING GIST (geom);
-- CREATE INDEX ON buildings_elevations USING GIST (geom);
-- ANALYZE new_sampled;
-- ANALYZE buildings_elevations;


-- -- 1. Create all buffers (and compute their area in km²) once
-- CREATE TEMP TABLE buffers AS
-- SELECT 
--   ns.id,
--   r.radius,
--   ST_Buffer(ns.geom, r.radius)       AS geom,
--   ST_Area(ST_Buffer(ns.geom, r.radius)) / 1e6 AS area_km2
-- FROM new_sampled ns
-- CROSS JOIN (VALUES (12.5),(25),(50),(12_5),(200),(400),(800),(1600)) AS r(radius);

-- CREATE INDEX ON buffers USING GIST (geom);
-- ANALYZE buffers;

-- -- 2a. Density & average height per buffer
-- WITH density_avg AS (
--   SELECT
--     b.id,
--     b.radius,
--     COUNT(be.geom)::double precision / NULLIF(b.area_km2,0) AS density,
--     AVG(be.roof_elevation)                       AS avg_height
--   FROM buffers b
--   LEFT JOIN buildings_elevations be
--     ON ST_Intersects(be.geom, b.geom)
--   GROUP BY b.id, b.radius, b.area_km2
-- ),
-- -- 2b. Nearest building height per buffer
-- nearest AS (
--   SELECT
--     b.id,
--     b.radius,
--     nn.roof_elevation AS nearest_height
--   FROM buffers b
--   JOIN LATERAL (
--     SELECT be2.roof_elevation
--     FROM buildings_elevations be2
--     WHERE ST_DWithin(be2.geom, b.geom, b.radius)
--     ORDER BY b.geom <-> be2.geom
--     LIMIT 1
--   ) nn ON true
-- ),
-- -- 3. Combine and pivot all metrics into columns
-- pivoted AS (
--   SELECT
--     da.id,

--     -- densities
--     MAX(da.density) FILTER (WHERE da.radius = 12.5)  AS density_12_5m,
--     MAX(da.density) FILTER (WHERE da.radius =   25)  AS density_25m,
--     MAX(da.density) FILTER (WHERE da.radius =   50)  AS density_50m,
--     MAX(da.density) FILTER (WHERE da.radius =  12_5)  AS density_12_5m,
--     MAX(da.density) FILTER (WHERE da.radius =  200)  AS density_200m,
--     MAX(da.density) FILTER (WHERE da.radius =  400)  AS density_400m,
--     MAX(da.density) FILTER (WHERE da.radius =  800)  AS density_800m,
--     MAX(da.density) FILTER (WHERE da.radius = 1600)  AS density_1600m,

--     -- nearest heights
--     MAX(n.nearest_height) FILTER (WHERE n.radius = 12.5) AS nearest_12_5m,
--     MAX(n.nearest_height) FILTER (WHERE n.radius =   25) AS nearest_25m,
--     MAX(n.nearest_height) FILTER (WHERE n.radius =   50) AS nearest_50m,
--     MAX(n.nearest_height) FILTER (WHERE n.radius =  12_5) AS nearest_12_5m,
--     MAX(n.nearest_height) FILTER (WHERE n.radius =  200) AS nearest_200m,
--     MAX(n.nearest_height) FILTER (WHERE n.radius =  400) AS nearest_400m,
--     MAX(n.nearest_height) FILTER (WHERE n.radius =  800) AS nearest_800m,
--     MAX(n.nearest_height) FILTER (WHERE n.radius = 1600) AS nearest_1600m,

--     -- average heights
--     MAX(da.avg_height) FILTER (WHERE da.radius = 12.5) AS avg_12_5m,
--     MAX(da.avg_height) FILTER (WHERE da.radius =   25) AS avg_25m,
--     MAX(da.avg_height) FILTER (WHERE da.radius =   50) AS avg_50m,
--     MAX(da.avg_height) FILTER (WHERE da.radius =  12_5) AS avg_12_5m,
--     MAX(da.avg_height) FILTER (WHERE da.radius =  200) AS avg_200m,
--     MAX(da.avg_height) FILTER (WHERE da.radius =  400) AS avg_400m,
--     MAX(da.avg_height) FILTER (WHERE da.radius =  800) AS avg_800m,
--     MAX(da.avg_height) FILTER (WHERE da.radius = 1600) AS avg_1600m

--   FROM density_avg da
--   LEFT JOIN nearest n
--     ON n.id = da.id AND n.radius = da.radius
--   GROUP BY da.id
-- )

-- -- 4. Final update: densities, nearest & average heights, plus building-TPI
-- UPDATE new_sampled ns
-- SET 
--   building_density_12_5m   = COALESCE(p.density_12_5m,  0),
--   building_density_25m     = COALESCE(p.density_25m,    0),
--   building_density_50m     = COALESCE(p.density_50m,    0),
--   building_density_12_5m    = COALESCE(p.density_12_5m,   0),
--   building_density_200m    = COALESCE(p.density_200m,   0),
--   building_density_400m    = COALESCE(p.density_400m,   0),
--   building_density_800m    = COALESCE(p.density_800m,   0),
--   building_density_1600m   = COALESCE(p.density_1600m,  0),

--   local_build_height_12_5m  = COALESCE(p.nearest_12_5m,  0),
--   local_build_height_25m    = COALESCE(p.nearest_25m,    0),
--   local_build_height_50m    = COALESCE(p.nearest_50m,    0),
--   local_build_height_12_5m   = COALESCE(p.nearest_12_5m,   0),
--   local_build_height_200m   = COALESCE(p.nearest_200m,   0),
--   local_build_height_400m   = COALESCE(p.nearest_400m,   0),
--   local_build_height_800m   = COALESCE(p.nearest_800m,   0),
--   local_build_height_1600m  = COALESCE(p.nearest_1600m,  0),

--   avg_building_height_12_5m = COALESCE(p.avg_12_5m,     0),
--   avg_building_height_25m   = COALESCE(p.avg_25m,       0),
--   avg_building_height_50m   = COALESCE(p.avg_50m,       0),
--   avg_building_height_12_5m  = COALESCE(p.avg_12_5m,      0),
--   avg_building_height_200m  = COALESCE(p.avg_200m,      0),
--   avg_building_height_400m  = COALESCE(p.avg_400m,      0),
--   avg_building_height_800m  = COALESCE(p.avg_800m,      0),
--   avg_building_height_1600m = COALESCE(p.avg_1600m,     0),

--   building_tpi_12_5m  = COALESCE(p.nearest_12_5m, 0) - COALESCE(p.avg_12_5m,  0),
--   building_tpi_25m    = COALESCE(p.nearest_25m,   0) - COALESCE(p.avg_25m,    0),
--   building_tpi_50m    = COALESCE(p.nearest_50m,   0) - COALESCE(p.avg_50m,    0),
--   building_tpi_12_5m   = COALESCE(p.nearest_12_5m,  0) - COALESCE(p.avg_12_5m,   0),
--   building_tpi_200m   = COALESCE(p.nearest_200m,  0) - COALESCE(p.avg_200m,   0),
--   building_tpi_400m   = COALESCE(p.nearest_400m,  0) - COALESCE(p.avg_400m,   0),
--   building_tpi_800m   = COALESCE(p.nearest_800m,  0) - COALESCE(p.avg_800m,   0),
--   building_tpi_1600m  = COALESCE(p.nearest_1600m, 0) - COALESCE(p.avg_1600m,  0)

-- FROM pivoted p
-- WHERE ns.id = p.id;