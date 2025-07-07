-- Noise labels

UPDATE new_sampled ns
SET d_noise_lvl = mp.vyohyke
FROM melu_paiva mp
WHERE ST_Contains(mp.geom_3067, ns.geom);

UPDATE new_sampled ns
SET n_noise_lvl = my.vyohyke
FROM melu_yo my
WHERE ST_Contains(my.geom_3067, ns.geom);