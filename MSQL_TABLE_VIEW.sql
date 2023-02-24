SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- LIST ALL TABLES AND VIEWS PER SCHEMA FROM THE CURRENT DATABASE
CREATE OR ALTER VIEW [dbo].[MSQL_TABLE_VIEW] as 
select object_id
, name table_name
, schema_name(schema_id) as table_schema
, type_desc table_type
, create_date
, modify_date
from  sys.tables  
UNION ALL
select object_id
, name table_name
, schema_name(schema_id) as table_schema
, type_desc table_type
, create_date
, modify_date
from  sys.views 

GO
