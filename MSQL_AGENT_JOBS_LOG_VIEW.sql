 
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER view [dbo].[MSQL_AGENT_JOBS_LOG_VIEW] AS
SELECT 
  convert(varchar(50),sj.name) JobName
, sjh.step_id
, convert(varchar(50), case when sjs.step_name is null then 'SQL Agent Job Status' else  'step ' + right(convert(varchar(10),1000+sjh.step_id),3)+'. '+ ISNULL(sjs.step_name, '') end) StepName
, convert(date,[msdb].dbo.agent_datetime(sjh.run_date, sjh.run_time)) RunDate
, [msdb].dbo.agent_datetime(sjh.run_date, sjh.run_time) RunDateAndTime
, STUFF(STUFF(RIGHT('00000' + CAST(run_duration AS VARCHAR(6)),6),3,0,':'),6,0,':')  duration_time
, (DATEDIFF(SECOND, '0:00:00', STUFF(STUFF(RIGHT('00000' + CAST(run_duration AS VARCHAR(6)),6),3,0,':'),6,0,':')  )) duration_sec
, CASE sjh.run_status
    WHEN 0 THEN 'Failed'
    WHEN 1 THEN 'Succeeded'
    WHEN 2 THEN 'Retry'
    WHEN 3 THEN 'Canceled'
    WHEN 4 THEN 'In Progress'
  END RunStatus
, convert(varchar(4000),convert(varchar(10),(DATEDIFF(SECOND, '0:00:00', STUFF(STUFF(RIGHT('00000' + CAST(run_duration AS VARCHAR(6)),6),3,0,':'),6,0,':'))  )) + ' sec duration. ' + sjh.message) as message
, datediff(SECOND, [msdb].dbo.agent_datetime(sjh.run_date, sjh.run_time),getdate() ) sec_ago
, 1 as site_id
FROM [msdb].dbo.sysjobs sj
  INNER JOIN [msdb].dbo.sysjobhistory sjh ON sj.job_id = sjh.job_id
  LEFT OUTER JOIN [msdb].dbo.sysjobsteps sjs ON sjh.job_id = sjs.job_id AND sjh.step_id = sjs.step_id  
WHERE sj.name = 'YOUR AGENT JOB NAME' 
-- and sjh.step_name in ( 'A STEP NAME1','A STEP NAME1')
 
GO


