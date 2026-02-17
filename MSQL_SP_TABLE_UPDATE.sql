SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE  PROCEDURE  [dbo].[MSQL_SP_TABLE_UPDATE] AS 
BEGIN
-- updates MSQL_TABLE metadata for all tables 
-- similar to [MSQL_TABLE_VIEW]
insert into [dbo].[MSQL_TABLE]
(
table_id
,[object_id]
,[table_name]
,[table_schema]
,[table_type]
,[create_date]
,[modify_date])
select [table_schema]+'.'+[table_name]
,[object_id]
,[table_name]
,[table_schema]
,[table_type]
,[create_date]
,[modify_date]
  FROM [dbo].[MSQL_TABLE_VIEW]
  where table_schema = 'MAIS_ANWB_P'
  and [table_schema]+'.'+[table_name] not in (select table_id from [MAIS_ANWB_P].[MSQL_TABLE])

  update T 
  set T.table_type=S.table_type
  ,T.modify_date=S.modify_date
  from [MAIS_ANWB_P].[MSQL_TABLE] T 
  inner join [dbo].[MSQL_TABLE_VIEW] S on T.table_id = S.[table_schema]+'.'+S.[table_name] 

END
GO
