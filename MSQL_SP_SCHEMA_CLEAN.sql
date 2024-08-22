-- clean all objects from a schema - views, tables, SP, functions

DECLARE @tableName NVARCHAR(128)
DECLARE @schema NVARCHAR(128)
DEClARE @schema_name_filter NVARCHAR(100)
SET @schema_name_filter = 'STG'

--delete views
DECLARE cursorTables CURSOR FOR
SELECT T.name,S.name as [schema]
FROM sys.views T inner join sys.schemas S on T.schema_id=S.schema_id
WHERE is_ms_shipped = 0  and S.name like @schema_name_filter --S.schema_id in (13,11,10)
OPEN cursorTables
FETCH NEXT FROM cursorTables INTO @tableName,@schema
WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC('DROP VIEW ' + @schema+'.'+@tableName)
    FETCH NEXT FROM cursorTables INTO @tableName,@schema
END
CLOSE cursorTables
DEALLOCATE cursorTables

-- delete tables 
--DECLARE @tableName NVARCHAR(128)
--DECLARE @schema NVARCHAR(128)
DECLARE cursorTables CURSOR FOR
SELECT T.name,S.name as [schema]
FROM sys.tables T inner join sys.schemas S on T.schema_id=S.schema_id
WHERE is_ms_shipped = 0  and  S.name like @schema_name_filter --S.schema_id in (13,11,10)
OPEN cursorTables
FETCH NEXT FROM cursorTables INTO @tableName,@schema
WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC('DROP TABLE ' + @schema+'.'+@tableName)
    FETCH NEXT FROM cursorTables INTO @tableName,@schema
END
CLOSE cursorTables
DEALLOCATE cursorTables

-- delete procedures
--DECLARE @tableName NVARCHAR(128)
--DECLARE @schema NVARCHAR(128)
DECLARE cursorTables CURSOR FOR
SELECT T.name,S.name as [schema]
FROM sys.procedures T inner join sys.schemas S on T.schema_id=S.schema_id
WHERE is_ms_shipped = 0  and S.name like @schema_name_filter --S.schema_id in (13,11,10)
OPEN cursorTables
FETCH NEXT FROM cursorTables INTO @tableName,@schema
WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC('DROP PROCEDURE ' + @schema+'.'+@tableName)
    FETCH NEXT FROM cursorTables INTO @tableName,@schema
END
CLOSE cursorTables
DEALLOCATE cursorTables


-- delete functions
--DECLARE @tableName NVARCHAR(128)
--DECLARE @schema NVARCHAR(128)
DECLARE cursorTables CURSOR FOR
SELECT T.name,S.name as [schema]
FROM sys.sysobjects T  inner join sys.schemas S on T.uid=S.schema_id
WHERE  type='FN'  and uid  like @schema_name_filter --S.schema_id in (13,11,10)
OPEN cursorTables
FETCH NEXT FROM cursorTables INTO @tableName,@schema
WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC('DROP FUNCTION ' + @schema+'.'+@tableName)
    FETCH NEXT FROM cursorTables INTO @tableName,@schema
END
CLOSE cursorTables
DEALLOCATE cursorTables
  
