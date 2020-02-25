WITH MainQuery AS (
	SELECT
		DB_NAME() AS [database_name]
		,DB_NAME() + N':' + CAST(qry.query_id AS nvarchar(20)) AS query_id
		,obj.[type] AS [object_type]
		,SCHEMA_NAME(obj.schema_id) + N'.' + obj.[name] AS [object_name]
		,qrytxt.query_sql_text
		,qryexec.plan_count
		,qryexec.execution_count
		,qryexec.total_duration_in_minutes
		,qryexec.total_logical_io_reads
		,qryexec.total_physical_io_reads
		,qryexec.total_query_max_used_memory_mb
		,qryexec.total_rowcount
		,qryexec.total_tempdb_space_used_mb
	FROM
		sys.query_store_query AS qry
		INNER JOIN sys.query_store_query_text AS qrytxt
			ON qry.query_text_id = qrytxt.query_text_id
		LEFT JOIN sys.objects AS obj
			ON qry.[object_id] = obj.[object_id]
		INNER JOIN (
			SELECT
				qrypln.query_id
				,count(DISTINCT qrypln.plan_id) AS plan_count
				,SUM(qrystat.count_executions) AS execution_count
				,SUM(qrystat.count_executions * qrystat.avg_duration / 6000000) AS total_duration_in_minutes
				,SUM(qrystat.count_executions * qrystat.avg_logical_io_reads) AS total_logical_io_reads
				,SUM(qrystat.count_executions * qrystat.avg_physical_io_reads) AS total_physical_io_reads
				,SUM(qrystat.count_executions * qrystat.avg_query_max_used_memory * 8 / 1024) AS total_query_max_used_memory_mb
				,SUM(qrystat.count_executions * qrystat.avg_rowcount) AS total_rowcount
				,SUM(qrystat.count_executions * qrystat.avg_tempdb_space_used * 8 / 1024) AS total_tempdb_space_used_mb
			FROM 
				sys.query_store_plan AS qrypln
				INNER JOIN sys.query_store_runtime_stats AS qrystat
					ON qrypln.plan_id = qrystat.plan_id
				INNER JOIN sys.query_store_runtime_stats_interval AS intrvl
					ON qrystat.runtime_stats_interval_id = intrvl.runtime_stats_interval_id
			WHERE
				intrvl.start_time >= '2020-02-20'
			GROUP BY qrypln.query_id
		) AS qryexec
			ON qry.query_id = qryexec.query_id
),
TopDuration AS (
	SELECT TOP (25) N'Duration' AS top_type, *
	FROM MainQuery
	ORDER BY total_duration_in_minutes DESC
),
TopLogicalReads AS (
	SELECT TOP (25) N'Logical Reads' AS top_type, *
	FROM MainQuery
	ORDER BY total_logical_io_reads DESC
),
TopPhysicalReads AS (
	SELECT TOP (25) N'Physical Reads' AS top_type, *
	FROM MainQuery
	ORDER BY total_physical_io_reads DESC
),
TopMemoryConsumption AS (
	SELECT TOP (25) N'Memory Consumption' AS top_type, *
	FROM MainQuery
	ORDER BY total_query_max_used_memory_mb DESC
),
TopRowCount AS (
	SELECT TOP (25) N'Row Count' AS top_type, *
	FROM MainQuery
	ORDER BY total_rowcount DESC
),
TopTempdDBUsage AS (
	SELECT TOP (25) N'TempDB Usage' AS top_type, *
	FROM MainQuery
	ORDER BY total_tempdb_space_used_mb DESC
)
SELECT *
FROM TopDuration
UNION ALL
SELECT *
FROM TopLogicalReads
UNION ALL
SELECT *
FROM TopPhysicalReads
UNION ALL
SELECT *
FROM TopMemoryConsumption
UNION ALL
SELECT *
FROM TopRowCount
UNION ALL
SELECT *
FROM TopTempdDBUsage;

/*
	SELECT * FROM sys.query_store_runtime_stats;

	SELECT * FROM sys.database_query_store_options;
	SELECT * FROM sys.query_context_settings;
*/






