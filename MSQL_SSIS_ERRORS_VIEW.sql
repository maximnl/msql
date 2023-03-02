
-- VIEW SSIS EXECUTION ERROR MESSAGES 

CREATE OR ALTER VIEW dbo.MSQL_SSIS_ERRORS_VIEW AS
SELECT   DISTINCT   MSG.operation_id
			,E.Folder_Name AS Project_Name 
			,E.Project_name AS SSIS_Project_Name
			,EM.Package_Name
			,EM.Message_Source_Name AS Component_Name 
			,EM.Subcomponent_Name AS Sub_Component_Name
			,case when  MSG.message_type =120 then 'ERROR'  when  MSG.message_type =130 then 'WARNING' END result
			, OPR.object_name
            , convert(date, MSG.message_time) message_date
            , MSG.message_time
            , MSG.message
			, OPR.server_name
			, OPR.caller_name
FROM        SSISDB.catalog.operation_messages  AS MSG
INNER JOIN  SSISDB.catalog.operations          AS OPR  ON OPR.operation_id            = MSG.operation_id
INNER JOIN  SSISDB.catalog.executions          AS E  ON E.execution_id            = MSG.operation_id
INNER JOIN  SSISDB.catalog.event_messages AS EM ON EM.operation_id = MSG.operation_id 
WHERE       
MSG.message_type in (120) -- ONLY SSIS  ERRORS
and  ISNULL(EM.subcomponent_name, '') <> 'SSIS.Pipeline' 
and  EM.event_name = 'OnError' 
and  MSG.message_time>getdate()-30 -- GET MESSAGES BACK DAYS
and  E.Folder_Name = 'ANWB_dataverlading'  -- YOUR PACKAGE NAME OR REMOVE FOR ALL
 
 
