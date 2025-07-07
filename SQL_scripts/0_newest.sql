SELECT tmsnumber, AVG(elevation_dem) AS mean_elevation
FROM new_sampled
WHERE tmsnumber IN (1237, 21201)
AND log_tms_road > 3
AND ST_Y(new_sampled.geom) < (
    SELECT ST_Y(geom_3067)
    FROM oulu_stations
    LIMIT 1
)
GROUP BY tmsnumber;

SELECT AVG(elevation_dem) AS mean_elevation
FROM new_sampled
WHERE tmsnumber IN (1237, 21201)
AND NOT EXISTS (
    SELECT 1
    FROM melu_paiva
    WHERE melu_paiva.melu_db IN ('65-70 dB', '70-75 dB', 'yli 75 dB')
    AND ST_Intersects(new_sampled.geom, melu_paiva.geom)
)
AND ST_Y(new_sampled.geom) < (
    SELECT ST_Y(geom_3067)
    FROM oulu_stations
    LIMIT 1
);
