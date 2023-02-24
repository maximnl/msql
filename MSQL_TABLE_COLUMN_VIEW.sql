SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- a combined view of all colums for all tables and views in the current database
CREATE OR ALTER view [dbo].[MSQL_TABLE_COLUMN_VIEW] as 
select v.object_id,
       object_name(c.object_id) as table_name,
       schema_name(v.schema_id) as table_schema,
       v.type_desc table_type,
       c.column_id,
       c.name as column_name,
       type_name(user_type_id) as data_type,
       c.max_length,
       c.precision
from sys.columns c
join sys.views v 
     on v.object_id = c.object_id
 

UNION ALL 

select v.object_id,
       object_name(c.object_id) as table_name,
       schema_name(v.schema_id) as table_schema,

       v.type_desc table_type,
       c.column_id,
       c.name as column_name,
       type_name(user_type_id) as data_type,
       c.max_length,
       c.precision
       
from sys.columns c
join sys.tables v 
     on v.object_id = c.object_id
 
GO
