CREATE INDEX IF NOT EXISTS tampere_samples_geom_idx 
ON tampere_samples USING GIST (geom);

CREATE TABLE new_tampere AS
SELECT ns.*
FROM tampere_samples ns
WHERE NOT EXISTS (
    SELECT 1
    FROM new_sampled sd
    WHERE ST_Equals(ns.geom, sd.geom)
);