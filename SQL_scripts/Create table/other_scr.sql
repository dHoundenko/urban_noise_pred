CREATE INDEX IF NOT EXISTS new_data_geom_idx 
ON new_data USING GIST (geom);

-- UPDATE new_sampled ns
-- SET motorway_length_100m = COALESCE(
--   (
--     SELECT SUM(ST_Length(ht.geom_3067))
--     FROM highway_tampere ht
--     WHERE ht.highway = 'motorway'
--       AND ht.geom_3067 && ST_Expand(ns.geom, 100)  -- Bounding box filter
--       AND ST_Intersects(ht.geom_3067, ST_Buffer(ns.geom, 100))
--   ),
--   0  -- Default to 0 if no motorways in buffer
-- );

CREATE TABLE new_sampled AS
SELECT ns.*
FROM new_data ns
WHERE NOT EXISTS (
    SELECT 1
    FROM sampled_data sd
    WHERE ST_Equals(ns.geom, sd.geom)
);

ALTER TABLE new_sampled 
ADD COLUMN IF NOT EXISTS d_noise_lvl TEXT;

UPDATE new_sampled ns
SET d_noise_lvl = mp.vyohyke
FROM melu_paiva mp
WHERE ST_Contains(mp.geom_3067, ns.geom);

UPDATE new_sampled
SET d_noise_lvl = 'alle 45 dB'
WHERE d_noise_lvl IN ('30-35 dB', '35-40 dB', '40-45 dB');

-- Oulu

ALTER TABLE new_data2 
ADD COLUMN IF NOT EXISTS d_noise_lvl TEXT;

UPDATE new_data2 ns
SET d_noise_lvl = mp.melu_db
FROM melu_paiva mp
WHERE ST_Contains(mp.geom, ns.geom);