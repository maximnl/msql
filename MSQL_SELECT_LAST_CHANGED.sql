SELECT name,type, create_date, modify_date 
FROM sys.objects
--where name like '%cube%'
WHERE type = 'V'-- The type for a function is FN , P for procedure, V for View. Or you can filter on the name column.
ORDER BY modify_date DESC
