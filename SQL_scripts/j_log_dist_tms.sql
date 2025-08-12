-- log distance from the sample to the geolocation of tms station

UPDATE all_tampere_samples ns
SET log_tms_station = subquery.log_tms_station 
FROM (
  SELECT 
    ns.id, 
    ST_Distance(ST_Transform(os.geom, 3067), ns.geom) AS log_tms_station
  FROM all_tampere_samples ns
  JOIN tms_stations os ON os."tmsNumber" = ns.tmsnumber
) AS subquery
WHERE ns.id = subquery.id;

-- idk s
-- 1s


-- log distance from the sample to road, along which points were sampled

-- Update the column with log-transformed distance from the sample point to the nearest relevant road
UPDATE all_tampere_samples ns
SET log_tms_road = COALESCE(rd.min_dist, -1)
FROM (
  SELECT
    ns.id,
    MIN(
      ST_Distance(
        ST_Transform(ns.geom, 3067),
        r.geom
      )
    ) AS min_dist
  FROM all_tampere_samples ns
  JOIN tms_stations ts 
    ON ts."tmsNumber" = ns.tmsnumber
  JOIN relevant_osm_roads2 r
    ON ST_DWithin(
         ST_Transform(ns.geom, 3067),
         r.geom,
         450
       )
  GROUP BY ns.id
) AS rd
WHERE ns.id = rd.id;

-- 20s
-- 1s