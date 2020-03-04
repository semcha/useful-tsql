-- Monitoring running queries
SELECT
    es.session_id AS [sid]
   ,er.blocking_session_id AS bloc_sid
   ,CAST(er.total_elapsed_time / 1000. / 60. AS DECIMAL(34, 2)) AS [duration]
   ,SUBSTRING(qt.[text], (er.statement_start_offset / 2) + 1,
    ((CASE
        WHEN er.statement_end_offset = -1 THEN LEN(CONVERT(NVARCHAR(MAX), qt.[text])) * 2
        ELSE er.statement_end_offset
    END - er.statement_start_offset) / 2) + 1) AS [statement]
   ,qt.[text] AS query
   ,DB_NAME(er.database_id) AS [db_name]
   ,OBJECT_SCHEMA_NAME(qt.objectid, er.database_id) + N'.' + OBJECT_NAME(qt.objectid, er.database_id) AS [object_name]
   ,er.[status]
   ,er.command
   ,es.login_name
   ,es.[host_name]
   ,es.[program_name]
   ,er.start_time
    --,qp.query_plan
   ,er.wait_type
   ,er.cpu_time
   ,er.logical_reads
   ,er.open_transaction_count
   ,er.last_wait_type
   ,er.percent_complete
   ,mg.requested_memory_kb / 1024 AS requested_memory_mb
   ,mg.granted_memory_kb / 1024 AS granted_memory_mb
FROM
    sys.dm_exec_requests AS er WITH (NOLOCK)
    INNER JOIN sys.dm_exec_sessions AS es WITH (NOLOCK)
        ON er.session_id = es.session_id
    LEFT JOIN sys.dm_exec_query_memory_grants AS mg WITH (NOLOCK)
        ON es.session_id = mg.session_id
    CROSS APPLY sys.dm_exec_sql_text(er.[sql_handle]) AS qt
--OUTER APPLY sys.dm_exec_query_plan(er.plan_handle) AS qp
WHERE
    es.is_user_process = 1
    AND es.session_id NOT IN (@@spid)
ORDER BY [statement], er.session_id DESC
OPTION (RECOMPILE);