/*
====================================================================
Query: MSQL_DATABASE_CODE
Description: Retrieves all user-defined database objects (stored 
             procedures, functions, views, triggers) with their 
             code definitions and line counts, and inserts them 
             into a tracking table. Provides version control for 
             database projects by automatically tracking code changes 
             over time. Allows rollback to any previous version by 
             retrieving historical definitions. Useful for code 
             analysis, documentation, change tracking, and understanding 
             database complexity.
             
             This code can be scheduled in daily data jobs (SQL Agent, 
             SSIS, cron, etc.) to keep SQL versions automatically 
             without manual intervention.
Output Columns:
    - DB_Name          : Current database name
    - Schema           : Database schema name
    - Object_Type      : Type of object (readable format)
    - Object_Name      : Name of the database object
    - LinesOfCode      : Number of lines in the object definition
    - definition       : Full SQL code definition of the object
    - LogDate          : Current timestamp of query execution
Setup: 
    - Uncomment and execute the CREATE TABLE statement once
    - Then run the INSERT query to log database code
Author: PLANSIS
Date: 2025-10-10
GitHub: https://github.com/maximnl/msql
====================================================================
*/

-- ====================================================================
-- CREATE TABLE (Execute this once manually - uncomment first)
-- ====================================================================
/*
CREATE TABLE dbo.MSQL_DATABASE_CODE_LOG (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    DB_Name NVARCHAR(128) NOT NULL,
    [Schema] NVARCHAR(128) NULL,
    Object_Type NVARCHAR(50) NOT NULL,
    Object_Name NVARCHAR(256) NOT NULL,
    LinesOfCode INT NOT NULL,
    definition NVARCHAR(MAX) NULL,
    LogDate DATETIME NOT NULL DEFAULT GETDATE()
);

CREATE INDEX IX_MSQL_DATABASE_CODE_LOG_Date ON dbo.MSQL_DATABASE_CODE_LOG(LogDate);
CREATE INDEX IX_MSQL_DATABASE_CODE_LOG_Object ON dbo.MSQL_DATABASE_CODE_LOG(Object_Name, LogDate);
*/

-- ====================================================================
-- INSERT QUERY (Run this to log database code)
-- Only inserts rows when the object definition has changed
-- ====================================================================
INSERT INTO dbo.MSQL_DATABASE_CODE_LOG (DB_Name, [Schema], Object_Type, Object_Name, LinesOfCode, definition, LogDate)
SELECT
    DB_NAME(DB_ID()) AS [DB_Name],
    SchemaName AS [Schema],
    CASE 
        WHEN TYPE = 'TR' THEN 'Trigger'
        WHEN TYPE = 'P' THEN 'Stored Procedure'
        WHEN TYPE = 'FN' THEN 'Scalar Function'
        WHEN TYPE = 'IF' THEN 'Inline Table-Valued Function'
        WHEN TYPE = 'TF' THEN 'Multi-Statement Table-Valued Function'
        WHEN TYPE = 'V' THEN 'View'
        ELSE 'Unknown'
    END AS [Object Type],
    NameOfObject AS [Object Name],
    LinesOfCode,
    definition,
    GETDATE() as [date]
FROM (
    SELECT
        o.type AS TYPE,
        SCHEMA_NAME(o.schema_id) AS SchemaName,
        LEN(a.definition) - LEN(REPLACE(a.definition, CHAR(10), '')) AS LinesOfCode,
        OBJECT_NAME(a.OBJECT_ID) AS NameOfObject,
        a.definition
    FROM sys.all_sql_modules a
    JOIN sys.objects o
        ON a.OBJECT_ID = o.object_id
    WHERE OBJECTPROPERTY(a.OBJECT_ID, 'IsMSShipped') = 0
      AND o.name NOT IN (
          'sp_helpdiagrams',
          'sp_helpdiagramdefinition', 
          'sp_creatediagram',
          'sp_renamediagram',
          'sp_alterdiagram',
          'sp_dropdiagram',
          'sp_upgraddiagrams',
          'fn_diagramobjects'
      )
      AND o.name NOT LIKE 'dt[_]%'  -- Exclude dt_* diagram functions
) SubQuery
WHERE NOT EXISTS (
    SELECT 1 
    FROM dbo.MSQL_DATABASE_CODE_LOG log
    WHERE log.Object_Name = SubQuery.NameOfObject
      AND log.[Schema] = SubQuery.SchemaName
      AND log.DB_Name = DB_NAME(DB_ID())
      AND log.definition = SubQuery.definition
      AND log.ID = (
          SELECT TOP 1 ID 
          FROM dbo.MSQL_DATABASE_CODE_LOG 
          WHERE Object_Name = SubQuery.NameOfObject 
            AND [Schema] = SubQuery.SchemaName
            AND DB_Name = DB_NAME(DB_ID())
          ORDER BY LogDate DESC
      )
)
ORDER BY LinesOfCode DESC

