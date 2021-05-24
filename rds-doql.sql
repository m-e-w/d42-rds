SELECT  res.resource_pk 
       ,res.resource_name 
       ,res.category
       ,CASE WHEN 'Cluster' = ANY(res.category) THEN CAST(1 AS BIT)  ELSE CAST(0 AS BIT) END AS is_cluster 
       ,array_agg(DISTINCT slp.fqdn) fqdns
FROM view_resource_v2 res
LEFT JOIN view_servicelistenerport_v2 slp
ON slp.resource_fk = res.resource_pk
WHERE res.vendor_resource_type = 'RDS' 
GROUP BY  res.resource_pk 
         ,res.resource_name
         ,res.category
ORDER BY 
    is_cluster