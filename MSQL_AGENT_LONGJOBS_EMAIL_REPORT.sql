--get currently running SQL Agent jobs that have been running for longer than 30 minutes
-- 1. get currently running jobs
-- 2. leave if no running jobs
-- 3. use msdb history to calculate average duration for running jobs for comparison
-- 4. get only running jobs, that started more than 30 minutes ago
-- 5. send e-mail if any results from step #4

SET NOCOUNT ON
SET CONCAT_NULL_YIELDS_NULL OFF

--e-mail subject, empty body
DECLARE @EmailSubject NVARCHAR(255) = N'** SQL Server long running jobs on ' + @@SERVERNAME + N' **',
        @EmailBody NVARCHAR(MAX)

--temp table for all jobs from msdb stored proc "xp_sqlagent_enum_jobs"
--user running this script needs permission to run stored proc
DECLARE @temp_xp_sqlagent_enum_jobs TABLE (
    [job_id] UNIQUEIDENTIFIER NOT NULL PRIMARY KEY, --job identifier, can be matched back to sysjobs
    [last_run_date] INT NOT NULL, --last run date in YYYYMMDD format
    [last_run_time] INT NOT NULL, --last run time in HMMSS format (24-hour time)
    [next_run_date] INT NOT NULL, --next run date or zero if not scheduled
    [next_run_time] INT NOT NULL, --next run time or zero if not scheduled
    [next_run_schedule_id] INT NOT NULL, --schedule identifier for next run or zero if not scheduled
    [requested_to_run] INT NOT NULL,
    [request_source] INT NOT NULL,
    [request_source_id] SYSNAME NULL,
    [running] INT NOT NULL, --1 if the job is executing
    [current_step] INT NOT NULL, --step number that is currently executing or zero
    [current_retry_attempt] INT NOT NULL, --retry attempt number
    [job_state] INT NOT NULL --from http://www.sqlnotes.info/2012/01/13/are-jobs-currently-running/#more-1194:
                             --0 = Not idle or suspended, 1 = Executing, 2 = Waiting For Thread, 3 = Between Retries, 4 = Idle, 5 = Suspended, [6 = WaitingForStepToFinish], 7 = PerformingCompletionActions
)

--get all jobs into temp table
INSERT INTO @temp_xp_sqlagent_enum_jobs
EXEC master..xp_sqlagent_enum_jobs 1, N''

--leave only running jobs in temp table
DELETE
FROM    @temp_xp_sqlagent_enum_jobs
WHERE   --not executing
        [job_state] != 1

--sanity check: do we have any running jobs? If not, exit
IF 0 = (SELECT COUNT(*) FROM @temp_xp_sqlagent_enum_jobs)
    RETURN

--format results as HTML table row, each column called "td"
--adapted from https://www.sqlservercentral.com/Forums/Topic1465444-279-1.aspx
--limit to where job has been running for more than 30 minutes
DECLARE @TableHtml NVARCHAR(MAX) = (
 --get currently running jobs, last started date and historical average
 SELECT  --job name
         [td] = j.[name],
         --last started from sysjobactivity for executing jobs (ignore non-executing jobs)
         [td] = CONVERT(VARCHAR(25), CONVERT(DATETIME, CASE
             WHEN MAX(CURRENTLY_RUNNING.[job_state]) = 1 THEN MAX(sja.[start_execution_date])
         END), 100),
         --current duration in minutes for executing jobs
         [td] = CONVERT(INT, CASE
             WHEN MAX(CURRENTLY_RUNNING.[job_state]) = 1 AND MAX(sja.[start_execution_date]) IS NOT NULL THEN DATEDIFF(MINUTE, MAX(sja.[start_execution_date]), GETDATE())
         END),
         --average for all executions from recent history
         [td] = MAX(AVERAGES.[avg_duration_in_mins])
 FROM    --from docs: "Stores the information for each scheduled job to be executed by SQL Server Agent."
         msdb..[sysjobs] j INNER JOIN
             @temp_xp_sqlagent_enum_jobs CURRENTLY_RUNNING ON
                 j.[job_id] = CURRENTLY_RUNNING.[job_id] INNER JOIN
             --get only latest start from activity table
             --have had cases of phantom, non-current record from job perhaps not terminated properly?
             --from docs: "Records current SQL Server Agent job activity and status."
             msdb..[sysjobactivity] sja ON
                 j.[job_id] = sja.[job_id] AND
                 --started
                 sja.[start_execution_date] IS NOT NULL AND
                 --latest started
                 sja.[start_execution_date] = (SELECT MAX([start_execution_date]) FROM msdb..[sysjobactivity] sja2 WHERE sja.[job_id] = sja2.[job_id]) AND
                 --not finished
                 sja.[stop_execution_date] IS NULL LEFT OUTER JOIN
             (
              --calculate average duration in minutes for jobs from history data
              SELECT  I.[job_id],
                      --average for all executions in minutes from recent history
                      [avg_duration_in_mins] = CONVERT(INT, AVG(I.[run_duration_in_secs])/60)
              FROM    (
                       --job history from msdb "sysjobhistory"
                       --this table only has recent history, determined by "Limit size of job history log" SQL Agent setting
                       SELECT  JH.[job_id],
                               --date executed as DATETIME
                               [date_executed] = msdb.dbo.agent_datetime(JH.[run_date], JH.[run_time]),
                               --convert elapsed time in HHMMSS format to seconds
                                
                               [run_duration_in_secs] = (JH.[run_duration]/10000 * 3600) + (JH.[run_duration] % 10000/100 * 60) + (JH.[run_duration] % 100)
                       FROM    msdb..[sysjobhistory] JH INNER JOIN
                                   --currently running jobs
                                   @temp_xp_sqlagent_enum_jobs CURRENTLY_RUNNING ON
                                         JH.[job_id] = CURRENTLY_RUNNING.[job_id]
                       WHERE   --job outcome step
                               JH.[step_id] = 0 AND
                               --successful execution
                               JH.[run_status] = 1
                      ) I
              GROUP BY I.[job_id]
             ) AVERAGES ON
                 j.[job_id] = AVERAGES.[job_id]
 GROUP BY j.[job_id], j.[name]
 HAVING  --is running
         MAX(CURRENTLY_RUNNING.[job_state]) = 1 AND
         MAX(sja.[start_execution_date]) IS NOT NULL AND
         --has been running for longer than 30 minutes
         DATEDIFF(MINUTE, MAX(sja.[start_execution_date]), GETDATE()) > 30
 FOR     --wrap in HTML table row element
         XML RAW('tr'), ELEMENTS
)

--sanity check: did we get any jobs that have been running for longer than 30 minutes? If not, leave
IF @TableHtml IS NULL
    RETURN

--prepend table HTML element, table header row to table HTML
SET @TableHtml = N'<table><tr><th>Job</th><th>Started</th><th>Running for (minutes)</th><th>Average duration (minutes)</th></tr>' + @TableHtml + N'</table>'

--set e-mail body, inserting table HTML
SET @EmailBody =
    N'<body><p>The following jobs have been running for more than 30 minutes on SQL Server ' + @@SERVERNAME + N' and should be investigated:</p>' +
    @TableHtml +
    N'<p><em>This e-mail was sent by an automated process. Do not reply to this e-mail.</em></p>' +
    N'</body>'

SET NOCOUNT OFF

--send the e-mail
--requires Database Mail to be set up
EXEC msdb.dbo.sp_send_dbmail @recipients = 'ad@mai.ll', @subject = @EmailSubject, @body = @EmailBody, @body_format = 'HTML'
