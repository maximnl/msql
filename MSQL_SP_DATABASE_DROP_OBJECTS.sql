/*
====================================================================
Stored Procedure: MSQL_SP_DATABASE_DROP_OBJECTS
Description: Drops all user tables, views, stored procedures, and 
             user-defined functions from a specified database
Parameters: 
    @DatabaseName - Name of the database to clean
    @Mode         - Execution mode (default: 'TEST')
                    'TEST' = Preview SQL without executing
                    'RUN'  = Execute DROP statements
Author: Auto-generated
Date: 2025-10-09
====================================================================
*/

USE master
GO

IF OBJECT_ID('dbo.MSQL_SP_DATABASE_DROP_OBJECTS', 'P') IS NOT NULL
    DROP PROCEDURE dbo.MSQL_SP_DATABASE_DROP_OBJECTS
GO

CREATE PROCEDURE dbo.MSQL_SP_DATABASE_DROP_OBJECTS
    @DatabaseName NVARCHAR(128),
    @Mode NVARCHAR(10) = 'TEST'  -- Default to TEST mode for safety
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @ObjectName NVARCHAR(256);
    DECLARE @SchemaName NVARCHAR(128);
    DECLARE @FullObjectName NVARCHAR(512);
    
    -- Validate and normalize @Mode parameter
    SET @Mode = UPPER(LTRIM(RTRIM(@Mode)));
    
    IF @Mode NOT IN ('TEST', 'RUN')
    BEGIN
        RAISERROR('Invalid @Mode parameter. Must be ''TEST'' or ''RUN''.', 16, 1);
        RETURN;
    END
    
    -- Validate database exists
    IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = @DatabaseName)
    BEGIN
        RAISERROR('Database [%s] does not exist.', 16, 1, @DatabaseName);
        RETURN;
    END
    
    -- Prevent dropping system databases
    IF @DatabaseName IN ('master', 'model', 'msdb', 'tempdb')
    BEGIN
        RAISERROR('Cannot drop objects from system database [%s].', 16, 1, @DatabaseName);
        RETURN;
    END
    
    PRINT '====================================================================';
    PRINT 'Mode: ' + @Mode + ' - ' + CASE WHEN @Mode = 'TEST' THEN 'Preview Only (No Changes)' ELSE 'Executing DROP Statements' END;
    PRINT 'Database: ' + @DatabaseName;
    PRINT '====================================================================';
    PRINT '';
    
    -- Step 1: Drop all Foreign Key Constraints
    PRINT 'Step 1: Dropping Foreign Key Constraints...';
    SET @SQL = N'
    USE [' + @DatabaseName + N'];
    DECLARE @Mode NVARCHAR(10) = N''' + @Mode + N''';
    DECLARE fk_cursor CURSOR FOR
        SELECT 
            SCHEMA_NAME(fk.schema_id) AS SchemaName,
            OBJECT_NAME(fk.parent_object_id) AS TableName,
            fk.name AS FKName
        FROM sys.foreign_keys fk
        ORDER BY SCHEMA_NAME(fk.schema_id), OBJECT_NAME(fk.parent_object_id);
    
    DECLARE @Schema NVARCHAR(128), @Table NVARCHAR(128), @FK NVARCHAR(128);
    DECLARE @DropSQL NVARCHAR(MAX);
    
    OPEN fk_cursor;
    FETCH NEXT FROM fk_cursor INTO @Schema, @Table, @FK;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @DropSQL = N''ALTER TABLE ['' + @Schema + ''].['' + @Table + ''] DROP CONSTRAINT ['' + @FK + '']'';
        
        IF @Mode = ''TEST''
        BEGIN
            PRINT ''  [TEST] '' + @DropSQL;
        END
        ELSE
        BEGIN
            PRINT ''  Dropping FK: '' + @Schema + ''.'' + @Table + ''.'' + @FK;
            EXEC sp_executesql @DropSQL;
        END
        
        FETCH NEXT FROM fk_cursor INTO @Schema, @Table, @FK;
    END
    
    CLOSE fk_cursor;
    DEALLOCATE fk_cursor;
    ';
    
    EXEC sp_executesql @SQL;
    PRINT '';
    
    -- Step 2: Drop all Views
    PRINT 'Step 2: Dropping Views...';
    SET @SQL = N'
    USE [' + @DatabaseName + N'];
    DECLARE @Mode NVARCHAR(10) = N''' + @Mode + N''';
    DECLARE view_cursor CURSOR FOR
        SELECT 
            SCHEMA_NAME(v.schema_id) AS SchemaName,
            v.name AS ViewName
        FROM sys.views v
        WHERE v.is_ms_shipped = 0
        ORDER BY SCHEMA_NAME(v.schema_id), v.name;
    
    DECLARE @Schema NVARCHAR(128), @View NVARCHAR(128);
    DECLARE @DropSQL NVARCHAR(MAX);
    
    OPEN view_cursor;
    FETCH NEXT FROM view_cursor INTO @Schema, @View;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @DropSQL = N''DROP VIEW ['' + @Schema + ''].['' + @View + '']'';
        
        IF @Mode = ''TEST''
        BEGIN
            PRINT ''  [TEST] '' + @DropSQL;
        END
        ELSE
        BEGIN
            PRINT ''  Dropping View: '' + @Schema + ''.'' + @View;
            EXEC sp_executesql @DropSQL;
        END
        
        FETCH NEXT FROM view_cursor INTO @Schema, @View;
    END
    
    CLOSE view_cursor;
    DEALLOCATE view_cursor;
    ';
    
    EXEC sp_executesql @SQL;
    PRINT '';
    
    -- Step 3: Drop all User-Defined Functions
    PRINT 'Step 3: Dropping User-Defined Functions...';
    SET @SQL = N'
    USE [' + @DatabaseName + N'];
    DECLARE @Mode NVARCHAR(10) = N''' + @Mode + N''';
    DECLARE func_cursor CURSOR FOR
        SELECT 
            SCHEMA_NAME(o.schema_id) AS SchemaName,
            o.name AS FunctionName,
            o.type_desc AS FunctionType
        FROM sys.objects o
        WHERE o.type IN (''FN'', ''IF'', ''TF'', ''FS'', ''FT'')  -- Scalar, Inline Table-Valued, Table-Valued, CLR Scalar, CLR Table-Valued
          AND o.is_ms_shipped = 0
        ORDER BY 
            CASE o.type 
                WHEN ''FN'' THEN 1  -- Scalar functions first
                WHEN ''FS'' THEN 2  -- CLR Scalar
                ELSE 3              -- Table-valued functions
            END,
            SCHEMA_NAME(o.schema_id), o.name;
    
    DECLARE @Schema NVARCHAR(128), @Function NVARCHAR(128), @FuncType NVARCHAR(60);
    DECLARE @DropSQL NVARCHAR(MAX);
    
    OPEN func_cursor;
    FETCH NEXT FROM func_cursor INTO @Schema, @Function, @FuncType;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @DropSQL = N''DROP FUNCTION ['' + @Schema + ''].['' + @Function + '']'';
        
        IF @Mode = ''TEST''
        BEGIN
            PRINT ''  [TEST] '' + @DropSQL;
        END
        ELSE
        BEGIN
            PRINT ''  Dropping Function ('' + @FuncType + ''): '' + @Schema + ''.'' + @Function;
            EXEC sp_executesql @DropSQL;
        END
        
        FETCH NEXT FROM func_cursor INTO @Schema, @Function, @FuncType;
    END
    
    CLOSE func_cursor;
    DEALLOCATE func_cursor;
    ';
    
    EXEC sp_executesql @SQL;
    PRINT '';
    
    -- Step 4: Drop all Stored Procedures
    PRINT 'Step 4: Dropping Stored Procedures...';
    SET @SQL = N'
    USE [' + @DatabaseName + N'];
    DECLARE @Mode NVARCHAR(10) = N''' + @Mode + N''';
    DECLARE proc_cursor CURSOR FOR
        SELECT 
            SCHEMA_NAME(p.schema_id) AS SchemaName,
            p.name AS ProcedureName
        FROM sys.procedures p
        WHERE p.is_ms_shipped = 0
        ORDER BY SCHEMA_NAME(p.schema_id), p.name;
    
    DECLARE @Schema NVARCHAR(128), @Procedure NVARCHAR(128);
    DECLARE @DropSQL NVARCHAR(MAX);
    
    OPEN proc_cursor;
    FETCH NEXT FROM proc_cursor INTO @Schema, @Procedure;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @DropSQL = N''DROP PROCEDURE ['' + @Schema + ''].['' + @Procedure + '']'';
        
        IF @Mode = ''TEST''
        BEGIN
            PRINT ''  [TEST] '' + @DropSQL;
        END
        ELSE
        BEGIN
            PRINT ''  Dropping Procedure: '' + @Schema + ''.'' + @Procedure;
            EXEC sp_executesql @DropSQL;
        END
        
        FETCH NEXT FROM proc_cursor INTO @Schema, @Procedure;
    END
    
    CLOSE proc_cursor;
    DEALLOCATE proc_cursor;
    ';
    
    EXEC sp_executesql @SQL;
    PRINT '';
    
    -- Step 5: Drop all Tables
    PRINT 'Step 5: Dropping Tables...';
    SET @SQL = N'
    USE [' + @DatabaseName + N'];
    DECLARE @Mode NVARCHAR(10) = N''' + @Mode + N''';
    DECLARE table_cursor CURSOR FOR
        SELECT 
            SCHEMA_NAME(t.schema_id) AS SchemaName,
            t.name AS TableName
        FROM sys.tables t
        WHERE t.is_ms_shipped = 0
          AND t.type = ''U''  -- User tables only
        ORDER BY SCHEMA_NAME(t.schema_id), t.name;
    
    DECLARE @Schema NVARCHAR(128), @Table NVARCHAR(128);
    DECLARE @DropSQL NVARCHAR(MAX);
    
    OPEN table_cursor;
    FETCH NEXT FROM table_cursor INTO @Schema, @Table;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @DropSQL = N''DROP TABLE ['' + @Schema + ''].['' + @Table + '']'';
        
        IF @Mode = ''TEST''
        BEGIN
            PRINT ''  [TEST] '' + @DropSQL;
        END
        ELSE
        BEGIN
            PRINT ''  Dropping Table: '' + @Schema + ''.'' + @Table;
            EXEC sp_executesql @DropSQL;
        END
        
        FETCH NEXT FROM table_cursor INTO @Schema, @Table;
    END
    
    CLOSE table_cursor;
    DEALLOCATE table_cursor;
    ';
    
    EXEC sp_executesql @SQL;
    PRINT '';
    
    PRINT '====================================================================';
    PRINT CASE WHEN @Mode = 'TEST' THEN 'Preview completed for database: ' ELSE 'Cleanup completed for database: ' END + @DatabaseName;
    PRINT '====================================================================';
END
GO

-- Grant execute permission (adjust as needed)
-- GRANT EXECUTE ON dbo.MSQL_SP_DATABASE_DROP_OBJECTS TO [YourRole];
-- GO

PRINT 'Stored procedure MSQL_SP_DATABASE_DROP_OBJECTS created successfully.';
PRINT '';
PRINT 'Usage Examples:';
PRINT '';
PRINT '  -- Preview mode (default) - Shows SQL without executing:';
PRINT '  EXEC dbo.MSQL_SP_DATABASE_DROP_OBJECTS @DatabaseName = ''YourDatabaseName'';';
PRINT '  -- or explicitly:';
PRINT '  EXEC dbo.MSQL_SP_DATABASE_DROP_OBJECTS @DatabaseName = ''YourDatabaseName'', @Mode = ''TEST'';';
PRINT '';
PRINT '  -- Run mode - Actually executes DROP statements:';
PRINT '  EXEC dbo.MSQL_SP_DATABASE_DROP_OBJECTS @DatabaseName = ''YourDatabaseName'', @Mode = ''RUN'';';
PRINT '';
GO

