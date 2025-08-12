CREATE INDEX IF NOT EXISTS tampere_geom_idx 
ON all_tampere_samples USING GIST (geom);

UPDATE all_tampere_samples ns
SET d_noise_lvl = mp.vyohyke
FROM melu_paiva mp
WHERE ST_Contains(mp.geom_3067, ns.geom);

UPDATE all_tampere_samples
SET d_noise_lvl = 'alle 45 dB'
WHERE d_noise_lvl IN ('30-35 dB', '35-40 dB', '40-45 dB');

-- Oulu

CREATE INDEX IF NOT EXISTS oulu_geom_idx 
ON all_oulu_samples USING GIST (geom);

UPDATE all_oulu_samples ns
SET d_noise_lvl = mp.melu_db
FROM melu_paiva mp
WHERE ST_Contains(mp.geom, ns.geom);