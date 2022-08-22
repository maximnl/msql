  
  -- sql reporting/analytical queries 
  -- testen on SQL service and a SQL Azure database
  
  -- reporting involves grouping of required measures across grouping columns
  -- as a measure we use simple count but any sum, avg etc aggregation can be applied
  -- the grouping columns have values in this case, if your data has null values for
  -- the grouping columns, you will not be able to distingish totals from simple grouping
  -- as multiple rows with null values for the grouping columns will be present
  
  -- examples have two grouping columns, region and domain. 

  -- normal grouping , 59 regions, regions always have a value
  select region, count(*)
  from [A_DIM_ACTIVITY] 
  group by region 

  -- normal grouping , 10 domains, domains always have a value
  select domain, count(*)
  from [A_DIM_ACTIVITY] 
  group by domain 

  -- normal grouping , all combinations of regions with domains - 151 rows
  -- data does not have null values, so the result does not have null values
  select region, domain, count(*)
  from [A_DIM_ACTIVITY] 
  group by region, domain

  -- includes  totals per region and total # of records, 211 rows, (151 + 59 + 1)
  select region, domain, count(*)
  from [A_DIM_ACTIVITY] 
  group by rollup (region, domain)  

  -- includes  totals per region and excluding total # of records, 210 records
  select region, domain, count(*)
  from [A_DIM_ACTIVITY] 
  group by region, rollup (domain) 

  -- the same result as above 
  select region, domain, count(*)
  from [A_DIM_ACTIVITY] 
  group by grouping sets ( (region, domain) , (region))
  
  -- the same result as above with extra 10 totals for the domains (we have 10 domains), 220 records. 
  select region, domain, count(*)
  from [A_DIM_ACTIVITY] 
  group by grouping sets ( (region, domain) , (region), (domain))

   -- the same as above plus extra total records
  select region, domain, count(*)
  from [A_DIM_ACTIVITY] 
  group by cube( region, domain)
  order by region, domain  


  
  -- the same as above plus extra total records
  select region, domain, count(*)
  from [A_DIM_ACTIVITY] 
  group by cube( region, domain)
  order by region, domain  

  select * from [A_DIM_ACTIVITY]

  update [A_DIM_ACTIVITY]
  set domain = null -- 
  where activity_id=6




