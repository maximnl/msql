/****** Object:  StoredProcedure [S_1_W].[MSQL_SP_TABLESTAT]    Script Date: 12-1-2022 11:27:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER   PROCEDURE [S_1_W].[MSQL_SP_TABLESTAT]  
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
update @Space set data = data + ' MB' 
update @Space set reserved = replace(reserved, ' KB', '') 
update @Space set reserved = convert(int, reserved)/1000 
update @Space set reserved = reserved + ' MB' 
 
--Display the tables orders by size biggest first. 
select * from @Space order by convert(int, replace(data, ' MB', '')) desc 
		   
END
 