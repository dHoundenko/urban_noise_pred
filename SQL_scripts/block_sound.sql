-- 101s

WITH nearest_road AS (
  SELECT 
    s.id AS sample_id,
    h.id AS road_id,
    ST_ClosestPoint(h.geom_3067, s.geom) AS closest_pt,
    ST_Distance(s.geom, h.geom_3067) AS road_distance
  FROM (SELECT * FROM new_sampled ORDER BY id) s
  JOIN highway_tampere h
    ON ST_DWithin(s.geom, h.geom_3067, 200)
    AND h.highway IN ('motorway', 'trunk')
  ORDER BY s.id, ST_Distance(s.geom, h.geom_3067)
),
sound_block_status AS (
  SELECT DISTINCT ON (nr.sample_id)
         nr.sample_id,
         nr.road_distance AS dist_to_road,
         EXISTS (
           SELECT 1
           FROM sound_barrier sb
           WHERE ST_Intersects(
             ST_MakeLine(samp.geom, nr.closest_pt),
             sb.geom_3067
           )
         ) AS is_blocked
  FROM nearest_road nr
  JOIN new_sampled samp
    ON samp.id = nr.sample_id
  ORDER BY nr.sample_id, nr.road_distance
)
UPDATE new_sampled s
SET sound_blocked = sb.is_blocked,
    log_dist_block = CASE 
                   WHEN sb.is_blocked THEN LN(1 + sb.dist_to_road)
                   ELSE -LN(1 + sb.dist_to_road)
                 END
FROM sound_block_status sb
WHERE s.id = sb.sample_id;