/*
CREATE TABLE [dbo].[tracked_queries](
	[timestamp] [datetime2](3) NULL,
	[duration] [decimal](19, 1) NULL,
	[event_name] [nvarchar](255) NULL,
	[database_name] [nvarchar](255) NULL,
	[sql_statement] [nvarchar](max) NULL,
	[sql_text] [nvarchar](max) NULL,
	[object_name] [nvarchar](255) NULL,
	[row_count] [bigint] NULL,
	[cpu] [bigint] NULL,
	[physical_reads] [bigint] NULL,
	[logical_reads] [bigint] NULL,
	[logical_writes] [bigint] NULL,
	[query_hash] [decimal](38, 0) NULL,
	[client_hostname] [nvarchar](255) NULL,
	[client_app_name] [nvarchar](255) NULL,
	[server_principal_name] [nvarchar](255) NULL,
	[username] [nvarchar](255) NULL,
	[nt_username] [nvarchar](255) NULL,
	[row_hash] [binary](32) NULL
);
GO
CREATE UNIQUE CLUSTERED INDEX [CIX_row_hash] ON [dbo].[tracked_queries]
(
	[row_hash] ASC
);
GO

*/

IF OBJECT_ID('tempdb..#event_data') IS NOT NULL
	DROP TABLE #event_data;
SELECT
	HASHBYTES('SHA2_256'
		,[file_name]
		+ N':offset_' + cast(file_offset as nvarchar(20))
		+ N':data_' + cast(event_data as nvarchar(4000))
	) AS row_hash
	,CAST(event_data AS XML) as event_data
INTO #event_data
FROM
	sys.fn_xe_file_target_read_file('E:\ExtendedEvents\QueryMetrics_*.xel', null, null, null)
WHERE
	[object_name] != N'existing_connection';

INSERT INTO msdb.dbo.tracked_queries WITH (TABLOCK) (
	[timestamp]
	,duration
	,event_name
	,[database_name]
	,sql_statement
	,sql_text
	,[object_name]
	,row_count
	,cpu
	,physical_reads
	,logical_reads
	,logical_writes
	,query_hash
	,client_hostname
	,client_app_name
	,server_principal_name
	,username
	,nt_username
	,row_hash
)
SELECT
	DATEADD(HOUR, 3, n.value('(@timestamp)[1]', 'datetime2(3)')) AS [timestamp],
	CAST(n.value('(data[@name="duration"]/value)[1]', 'bigint') / 60000000. as decimal(19, 1)) as duration,
	n.value('(@name)[1]', 'nvarchar(255)') as event_name,
	n.value('(action[@name="database_name"]/value)[1]', 'nvarchar(255)') as [database_name],
	COALESCE(
		n.value('(data[@name="statement"]/value)[1]', 'nvarchar(max)')
		, n.value('(data[@name="batch_text"]/value)[1]', 'nvarchar(max)')
	) as sql_statement,
	n.value('(action[@name="sql_text"]/value)[1]', 'nvarchar(max)') as sql_text,
	n.value('(data[@name="object_name"]/value)[1]', 'nvarchar(255)') as [object_name],
	n.value('(data[@name="row_count"]/value)[1]', 'bigint') as row_count,
	n.value('(data[@name="cpu_time"]/value)[1]', 'bigint') as cpu,
	n.value('(data[@name="physical_reads"]/value)[1]', 'bigint') as physical_reads,
	n.value('(data[@name="logical_reads"]/value)[1]', 'bigint') as logical_reads,
	n.value('(data[@name="writes"]/value)[1]', 'bigint') as logical_writes,
	n.value('(action[@name="query_hash"]/value)[1]', 'decimal(38,0)') as query_hash,
	n.value('(action[@name="client_hostname"]/value)[1]', 'nvarchar(255)') as client_hostname,
	n.value('(action[@name="client_app_name"]/value)[1]', 'nvarchar(255)') as client_app_name,
	n.value('(action[@name="server_principal_name"]/value)[1]', 'nvarchar(255)') as server_principal_name,
	n.value('(action[@name="username"]/value)[1]', 'nvarchar(255)') as username,
	n.value('(action[@name="nt_username"]/value)[1]', 'nvarchar(255)') as nt_username,
	ed.row_hash
FROM
	#event_data AS ed
	CROSS APPLY ed.event_data.nodes('event') AS q (n)
WHERE NOT EXISTS (
	SELECT 1
	FROM msdb.dbo.tracked_queries AS tq
	WHERE tq.row_hash = ed.row_hash
);

SELECT
	*
FROM
	msdb.dbo.tracked_queries
ORDER BY duration DESC;
