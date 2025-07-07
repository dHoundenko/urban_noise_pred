-- 1 min 46s

-- log dist water

UPDATE new_sampled ns
SET log_dist_water = (
    SELECT LN(1 + MIN(ST_Distance(ns.geom, wt.geom)))
    FROM water wt
);

CREATE TABLE rail_geom AS
SELECT geom
FROM rail_tampere;

CREATE INDEX idx_rail_geom_geom
ON rail_geom
USING GIST (geom);

UPDATE new_sampled ns
SET log_dist_pub = sub.log_dist
FROM (
    SELECT ns.id, LN(1 + MIN(ST_Distance(ns.geom, pt.geom))) AS log_dist
    FROM new_sampled ns
    JOIN LATERAL (
        SELECT pt.geom
        FROM rail_geom pt
        WHERE ST_DWithin(ns.geom, pt.geom, 10000)
    ) AS pt ON TRUE
    GROUP BY ns.id
) sub
WHERE ns.id = sub.id;

-- digiroad

UPDATE new_sampled ns
SET traffic_light_200m = (
    SELECT COUNT(*)
    FROM traffic_light_digiroad tld
    WHERE ST_DWithin(
        tld.geom, 
        ns.geom,
        200  -- 200 meters away from sample
    )
);

UPDATE new_sampled ns
SET crossing_200m = (
    SELECT COUNT(*)
    FROM crossing_digiroad cd
    WHERE ST_DWithin(
        cd.geom,
        ns.geom,
        200  -- 200 meters away from sample
    )
);
