 
/****** Object:  StoredProcedure [dbo].[MSQL_SP_TABLESTAT]    Script Date: 17-10-2023 12:22:39 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER   PROCEDURE [dbo].[MSQL_SP_TABLES_STAT]  
	@schema varchar(50)   = null
	 
AS
BEGIN

SET NOCOUNT ON;
 /* 
Script to display the size of all the tables in the database 
*/ 

IF @schema is null  SET @schema=SCHEMA_NAME() -- current user schema

declare @RowCount int
declare @tablename varchar(100) 
 
--Declare @Table to store the tables 
declare @Tables 
table ( 
PK int IDENTITY(1,1), 
tablename varchar(100), 
processed bit 
) 
 
-- Get all tables and insert into @Tables 
INSERT into @Tables (tablename) 
SELECT TABLE_SCHEMA+'.'+TABLE_NAME from INFORMATION_SCHEMA.TABLES 
where TABLE_TYPE = 'BASE TABLE' and TABLE_NAME not like 'dt%' 
and TABLE_SCHEMA like @schema 
order by TABLE_NAME asc 
 
--De declare table to store the space 
declare @Space table ( 
name varchar(100), rows nvarchar(100), reserved varchar(100), data varchar(100), index_size varchar(100), unused varchar(100) 
) 
 
--Get Table space for all tables and insert into @space 
select top 1 @tablename = tablename from @Tables where processed is null 
SET @RowCount = 1 
WHILE (@RowCount <> 0) 
BEGIN 
insert into @Space exec sp_spaceused @tablename 
update @Tables set processed = 1 where tablename = @tablename 
select top 1 @tablename = tablename from @Tables where processed is null 
SET @RowCount = @@RowCount 
END 
 
--Calculate space to display human format 
update @Space set data = replace(data, ' KB', '') 
update @Space set data = convert(int, data)/1000 
--update @Space set data = data + ' MB' 

update @Space set reserved = replace(reserved, ' KB', '') 
update @Space set reserved = convert(int, reserved)/1000 
--update @Space set reserved = reserved + ' MB' 

update @Space set index_size = replace(index_size, ' KB', '') 
update @Space set index_size = convert(int, index_size)/1000 
--update @Space set index_size = index_size + ' MB' 


update @Space set unused = replace(unused, ' KB', '') 
update @Space set unused = convert(int, unused)/1000 
--update @Space set unused = unused + ' MB' 
 
;WITH usages as (
SELECT OBJECT_NAME(OBJECT_ID) AS TableName,
 max(coalesce(last_user_lookup,last_user_seek,last_user_scan)) last_usage
 , max(last_user_update) last_update
 , sum(user_seeks) last_seeks_count
 , sum(user_scans) last_scans_count
 , sum(user_lookups) last_lookups_count
 , sum(user_updates) last_updates_count
FROM sys.dm_db_index_usage_stats
WHERE database_id = DB_ID( )
group by OBJECT_NAME(OBJECT_ID)
)

--Display the tables orders by size biggest first. 
select name,rows,data,reserved,index_size ,unused , last_usage, last_update, last_seeks_count, last_scans_count, last_lookups_count, last_updates_count
from @Space S
left join  usages  on S.[name]= TableName 
order by convert(int, replace(data, ' MB', '')) desc
		   
END
 
