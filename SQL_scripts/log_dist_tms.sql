ALTER TABLE new_sampled 
ADD COLUMN log_tms_station DOUBLE PRECISION;

UPDATE new_sampled ns
SET log_tms_station = subquery.log_tms_station 
FROM (
  SELECT 
    ns.id, 
    LN(1 + ST_Distance(ST_Transform(os.geom, 3067), ns.geom)) AS log_tms_station
  FROM new_sampled ns
  JOIN tms_stations os ON os."tmsNumber" = ns.tmsnumber
) AS subquery
WHERE ns.id = subquery.id;



-- 1) add the new column
ALTER TABLE new_sampled 
ADD COLUMN log_tms_road DOUBLE PRECISION;

-- Update the column with log-transformed distance from the sample point to the nearest relevant road
UPDATE new_sampled ns
SET log_tms_road = COALESCE(LN(1 + rd.min_dist), -LN(3))
FROM (
  SELECT
    ns.id,
    MIN(
      ST_Distance(
        ST_Transform(ns.geom, 3067),
        r.geom
      )
    ) AS min_dist
  FROM new_sampled ns
  JOIN tms_stations ts 
    ON ts."tmsNumber" = ns.tmsnumber
  JOIN relevant_osm_roads r
    ON ST_DWithin(
         ST_Transform(ns.geom, 3067),
         r.geom,
         450
       )
  GROUP BY ns.id
) AS rd
WHERE ns.id = rd.id;
