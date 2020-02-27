-- Completed queries
SELECT
	SUBSTRING(qt.[text], (qs.statement_start_offset / 2) + 1,
	((CASE
		WHEN qs.statement_end_offset = -1
			THEN LEN(CONVERT(nvarchar(max), qt.text)) * 2
		ELSE qs.statement_end_offset
	END - qs.statement_start_offset) / 2) + 1) AS [query_text],
	qt.[text] as [full_text],
	qs.execution_count,
	CAST(qs.last_elapsed_time / 1000. / 1000. / 60. AS decimal(18, 2)) AS last_elapsed_time_min,
	--qp.query_plan,
	qs.last_execution_time,
	qs.last_physical_reads,
	qs.last_logical_reads,
	qs.last_logical_writes,
	(qs.total_logical_reads + qs.total_logical_writes) / qs.execution_count AS average_io,
	qs.last_rows
FROM
	sys.dm_exec_query_stats AS qs
	CROSS APPLY sys.dm_exec_sql_text(qs.[sql_handle]) AS qt
	--OUTER APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp
WHERE CAST(qs.last_elapsed_time / 1000. / 1000. / 60. AS decimal(18, 2)) > 0.99
ORDER BY last_elapsed_time_min DESC
OPTION (RECOMPILE);
