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


-- ====================================================================
-- DIGEST REPORT (Run on request - uncomment and set date range)
-- Shows daily summary of code changes within a specified period
-- ====================================================================
/*
DECLARE @StartDate DATETIME = '2025-10-01';  -- Set your start date
DECLARE @EndDate DATETIME = '2025-10-31';    -- Set your end date

-- Summary: Changes per day
SELECT 
    CONVERT(DATE, LogDate) AS ChangeDate,
    COUNT(DISTINCT Object_Name) AS TotalObjectsChanged,
    COUNT(*) AS TotalChanges,
    SUM(CASE WHEN IsNew = 1 THEN 1 ELSE 0 END) AS NewObjects,
    SUM(CASE WHEN IsNew = 0 THEN 1 ELSE 0 END) AS ModifiedObjects,
    COUNT(DISTINCT CASE WHEN Object_Type = 'Stored Procedure' THEN Object_Name END) AS StoredProcedures,
    COUNT(DISTINCT CASE WHEN Object_Type = 'View' THEN Object_Name END) AS Views,
    COUNT(DISTINCT CASE WHEN Object_Type LIKE '%Function%' THEN Object_Name END) AS Functions,
    COUNT(DISTINCT CASE WHEN Object_Type = 'Trigger' THEN Object_Name END) AS Triggers
FROM (
    SELECT 
        log.LogDate,
        log.Object_Name,
        log.[Schema],
        log.Object_Type,
        CASE 
            WHEN NOT EXISTS (
                SELECT 1 
                FROM dbo.MSQL_DATABASE_CODE_LOG prev 
                WHERE prev.Object_Name = log.Object_Name 
                  AND prev.[Schema] = log.[Schema]
                  AND prev.DB_Name = log.DB_Name
                  AND prev.LogDate < log.LogDate
            ) THEN 1 
            ELSE 0 
        END AS IsNew
    FROM dbo.MSQL_DATABASE_CODE_LOG log
    WHERE log.LogDate >= @StartDate 
      AND log.LogDate < DATEADD(DAY, 1, @EndDate)
      AND log.DB_Name = DB_NAME(DB_ID())
) Summary
GROUP BY CONVERT(DATE, LogDate)
ORDER BY ChangeDate DESC;

-- Detail: All Objects with Line Changes (New and Modified in one table)
SELECT 
    CONVERT(DATE, curr.LogDate) AS ChangeDate,
    curr.LogDate AS ExactTimestamp,
    curr.[Schema],
    curr.Object_Type,
    curr.Object_Name,
    CASE 
        WHEN prev.Object_Name IS NULL THEN 'New Object'
        ELSE 'Modified'
    END AS ChangeType,
    ISNULL(prev.LinesOfCode, 0) AS PreviousLines,
    curr.LinesOfCode AS CurrentLines,
    CASE 
        WHEN curr.LinesOfCode > ISNULL(prev.LinesOfCode, 0) 
        THEN curr.LinesOfCode - ISNULL(prev.LinesOfCode, 0)
        ELSE 0 
    END AS LinesAdded,
    CASE 
        WHEN curr.LinesOfCode < ISNULL(prev.LinesOfCode, 0)
        THEN ISNULL(prev.LinesOfCode, 0) - curr.LinesOfCode 
        ELSE 0 
    END AS LinesRemoved,
    curr.LinesOfCode - ISNULL(prev.LinesOfCode, 0) AS NetChange,
    prev.LogDate AS PreviousVersionDate,
    DATEDIFF(DAY, prev.LogDate, curr.LogDate) AS DaysSinceLastChange
FROM dbo.MSQL_DATABASE_CODE_LOG curr
LEFT JOIN (
    SELECT 
        Object_Name,
        [Schema],
        DB_Name,
        LogDate,
        LinesOfCode,
        ROW_NUMBER() OVER (
            PARTITION BY Object_Name, [Schema], DB_Name 
            ORDER BY LogDate DESC
        ) AS RowNum
    FROM dbo.MSQL_DATABASE_CODE_LOG
    WHERE LogDate < @StartDate OR LogDate >= DATEADD(DAY, 1, @EndDate)
) prev ON curr.Object_Name = prev.Object_Name 
      AND curr.[Schema] = prev.[Schema]
      AND curr.DB_Name = prev.DB_Name
      AND prev.RowNum = 1  -- Most recent version before current
WHERE curr.LogDate >= @StartDate 
  AND curr.LogDate < DATEADD(DAY, 1, @EndDate)
  AND curr.DB_Name = DB_NAME(DB_ID())
ORDER BY curr.LogDate DESC, curr.Object_Name;

-- Detail: All changes with full history in date range
SELECT 
    CONVERT(DATE, log.LogDate) AS ChangeDate,
    log.LogDate AS ExactTimestamp,
    log.[Schema],
    log.Object_Type,
    log.Object_Name,
    log.LinesOfCode,
    CASE 
        WHEN NOT EXISTS (
            SELECT 1 
            FROM dbo.MSQL_DATABASE_CODE_LOG prev 
            WHERE prev.Object_Name = log.Object_Name 
              AND prev.[Schema] = log.[Schema]
              AND prev.DB_Name = log.DB_Name
              AND prev.LogDate < log.LogDate
        ) THEN 'New Object' 
        ELSE 'Modified' 
    END AS ChangeType
FROM dbo.MSQL_DATABASE_CODE_LOG log
WHERE log.LogDate >= @StartDate 
  AND log.LogDate < DATEADD(DAY, 1, @EndDate)
  AND log.DB_Name = DB_NAME(DB_ID())
ORDER BY log.LogDate DESC, log.Object_Name;
*/

