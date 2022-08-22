/*
How do I select all the columns in a table that only contain NULL values for all the rows and do some actions? 
This is practical when we have many columns and like to get rid of empty ones. 
any action is possible here, just replace the commented lines (that drop empty collumns) with your action. it is about the principle. 

The script uses INFORMATION_SCHEMA.COLUMNS, adds variables for the table schema and table name. The column data type was added to the output. Including the column data type helps when looking for a column of a particular data type. I didn't added the column widths or anything.
For output the RAISERROR ... WITH NOWAIT is used so text will display immediately instead of all at once (for the most part) at the end like PRINT does.

Output

HTML
30_attrib1 (datetime) 
256_Info mbt aflevermoment/status transport (smallint) 
235_Taalbarrierre / communicatie monteur (smallint) 
218_Monteur/Wegenwacht ter plaatse (smallint) 
1593_MES medewerker 1e contact (smallint)

*/

SET NOCOUNT ON;

DECLARE
 @ColumnName sysname
,@DataType nvarchar(128)
,@cmd nvarchar(max)
,@TableSchema nvarchar(128) = 'dbo'
,@TableName sysname = 'YOUR_TABLE_NAME';

DECLARE getinfo CURSOR FOR
SELECT
     c.COLUMN_NAME
    ,c.DATA_TYPE
FROM
    INFORMATION_SCHEMA.COLUMNS AS c
WHERE
    c.TABLE_SCHEMA = @TableSchema
    AND c.TABLE_NAME = @TableName;

OPEN getinfo;

FETCH NEXT FROM getinfo INTO @ColumnName, @DataType;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @cmd = N'IF NOT EXISTS (SELECT * FROM ' + @TableSchema + N'.' + @TableName + N' WHERE [' + @ColumnName + N'] IS NOT NULL) RAISERROR(''' + @ColumnName + N' (' + @DataType + N')'', 0, 0) WITH NOWAIT;';
    EXECUTE (@cmd);

--  optional code , for instance drop columns with all nulls
--	SET @cmd= 'alter table PLANSIS_SOURCE_NPS_COBI drop column [' + @ColumnName + '] end'
--	EXECUTE (@cmd);

    FETCH NEXT FROM getinfo INTO @ColumnName, @DataType;
END;

CLOSE getinfo;
DEALLOCATE getinfo;
