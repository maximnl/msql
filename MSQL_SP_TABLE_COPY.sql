SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:      MAXIM IVASHKOV / PLANSIS
-- Create Date: 2022-04-01
-- Description: SP to copy/synchronize data from one table to another / all source columns should match target
-- We assume source and target tables already exist
-- due to automatic column names detection 
-- Supports multiple schemas
-- Supports identity automatic detection / turns on or off. 
-- Supports transactions, if inset statement fails, the delete will be rolled back
-- Commands parameter added
-- -BULK command uses trancation and avoids transaction container
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[MSQL_SP_TABLE_COPY] 

(
@SCHEMA_FROM varchar(50)='[dbo]',
@SCHEMA_TO varchar(50)='[dbo]',
@TABLE_FROM varchar(50)='',
@TABLE_TO varchar(50)='',
@COMMANDS varchar(1000)='',
@COLUMNS_SKIP varchar(1000)='timestamp'
)
WITH EXECUTE AS OWNER
AS
BEGIN
    -- SET NOCOUNT ON added to prevent extra result sets from
    -- interfering with SELECT statements.
    SET NOCOUNT ON
   

DECLARE @SQL nvarchar(max)=''
DECLARE @columns varchar(max)=''
DECLARE @output nvarchar(max)=''
DECLARE @ErrorMessage nvarchar(max)='No errors'

IF @TABLE_TO ='' AND @SCHEMA_FROM <> @SCHEMA_TO
BEGIN  
    SET @TABLE_TO = @TABLE_FROM 
END 
ELSE PRINT 'Target table TABLE_TO parameter must be filled in.'

SET @columns='['+(select STRING_AGG(name,'],[')+']' from syscolumns 
where id=object_id(@SCHEMA_FROM + '.'+@TABLE_FROM) and name not in (select value from STRING_SPLIT (@COLUMNS_SKIP,',')))

SET @SQL = '
IF OBJECTPROPERTY(OBJECT_ID('''+ @SCHEMA_TO + '.'+@TABLE_TO + '''), ''TableHasIdentity'') = 1 SET IDENTITY_INSERT '+ @SCHEMA_TO + '.'+@TABLE_TO + ' ON '

IF @COMMANDS not like '%-TRUNSACTION%' SET @SQL=@SQL + ';TRUNCATE TABLE '+ @SCHEMA_TO + '.'+@TABLE_TO    
ELSE SET @SQL=@SQL + ';DELETE FROM '+ @SCHEMA_TO + '.'+@TABLE_TO 
 
SET @SQL=@SQL + ';INSERT INTO '+ @SCHEMA_TO + '.'+@TABLE_TO + '(' + @columns + ') 
SELECT '+ @columns + ' FROM ' + @SCHEMA_FROM + '.'+@TABLE_FROM   


IF @COMMANDS not like '%-TRUNSACTION%'  EXEC dbo.sp_executesql @SQL
, @Params=N'@output varchar(max) OUTPUT'
, @output=@output OUTPUT

ELSE  -- transaction mode execution
 BEGIN
    BEGIN TRY
        BEGIN TRANSACTION 
        EXEC dbo.sp_executesql @SQL
        , @Params=N'@output varchar(max) OUTPUT'
        , @output=@output OUTPUT
        COMMIT TRAN	 
        --SELECT @output 
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRAN
            SET @output=ERROR_MESSAGE()
            SET @ErrorMessage= ERROR_MESSAGE()
            DECLARE @ErrorSeverity INT = ERROR_SEVERITY()
            DECLARE @ErrorState INT = ERROR_STATE()

        -- Use RAISERROR inside the CATCH block to return error  
        -- information about the original error that caused  
        -- execution to jump to the CATCH block.  
        -- RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END -- end transaction mode execution
--print @output
select @ErrorMessage 

END -- end SP
GO

-- LOG 
-- switched to default truncate mode
-- for transactions please use commands=-TRANSACTION
