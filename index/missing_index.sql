IF OBJECT_ID(N'tempdb..#missing_index') IS NOT NULL
	DROP TABLE #missing_index;

SELECT
   db.database_id
   ,db.[name] AS [database_name]
   ,id.[object_id] AS [object_id]
   ,OBJECT_SCHEMA_NAME(id.[object_id], db.database_id) AS [schema_name]
   ,OBJECT_NAME(id.[object_id], db.database_id) AS [table__name]
   ,id.[statement] AS [object_name]
   ,id.equality_columns
   ,id.inequality_columns
   ,id.included_columns
   ,gs.unique_compiles
   ,gs.user_seeks
   ,gs.user_scans
   ,((user_seeks + user_scans ) * avg_total_user_cost * avg_user_impact) as index_benefit_number
INTO #missing_index
FROM
	sys.dm_db_missing_index_group_stats AS gs
	INNER JOIN sys.dm_db_missing_index_groups AS ig
		ON gs.group_handle = ig.index_group_handle
	INNER JOIN sys.dm_db_missing_index_details AS id
		ON ig.index_handle = id.index_handle
	INNER JOIN sys.databases AS db
		ON db.database_id = id.database_id
WHERE
	db.database_id > 4;

DROP TABLE IF EXISTS ##table_create_date_01;
CREATE TABLE ##table_create_date_01 (
	database_id bigint
	,[schema_name] nvarchar(255)
	,[object_id] bigint
	,create_days bigint
);

DECLARE @SQL nvarchar(4000) 
SELECT @SQL = 'USE [?]
	INSERT INTO ##table_create_date_01
	SELECT
		DB_ID() AS database_id
	   ,SCHEMA_NAME([schema_id]) AS [schema_name]
	   ,[object_id]
	   ,ISNULL(NULLIF(MAX(DATEDIFF(DAY, create_date, SYSDATETIME())), 0), 1) AS create_days
	FROM
		sys.objects
	WHERE
		DB_ID() > 4
		AND [type] = N''U''
	GROUP BY
		SCHEMA_NAME([schema_id])
		,[object_id];
' 
EXEC sp_MSforeachdb @SQL;

DECLARE @DaysUptime numeric(23, 2)
SELECT
	@DaysUptime = CAST(DATEDIFF(HOUR, create_date, GETDATE()) / 24. AS NUMERIC(23, 2))
FROM
	sys.databases
WHERE database_id = 2;

UPDATE ##table_create_date_01
SET create_days =
		CASE
			WHEN create_days < @DaysUptime THEN create_days
			ELSE @DaysUptime
		END;

DELETE FROM mindx
FROM
	#missing_index AS mindx
	INNER JOIN ##table_create_date_01 AS crdt
		ON mindx.database_id = crdt.database_id
			AND mindx.[schema_name] = crdt.[schema_name]
			AND mindx.[object_id] = crdt.[object_id]
WHERE (mindx.index_benefit_number / crdt.create_days) < 100000;

WITH IndexFull AS (
	SELECT
		[object_name]
		,ISNULL(
			REPLACE(REPLACE(REPLACE(equality_columns, N'[', N''), N']', N''), N', ', N'&')
			, N''
		) + ISNULL(
			IIF(equality_columns IS NULL, N'', N'&')
			+ REPLACE(REPLACE(REPLACE(inequality_columns, N'[', N''), N']', N''), N', ', N'&')
			, N''
		) AS index_name
		,ISNULL(equality_columns, N'') + ISNULL(
			IIF(equality_columns IS NULL, N'', N', ') + inequality_columns
			, N''
		) AS [index_columns]
		,mindx.included_columns
	FROM
		#missing_index as mindx
),
IndexIncludeAll AS (
	SELECT
		[object_name]
		,index_name
		,[index_columns]
		,STRING_AGG(included_columns, N',') AS all_include_columns
	FROM
		IndexFull
	GROUP BY
		[object_name]
		,index_name
		,[index_columns]
),
IndexInclude AS (
	SELECT
		[object_name]
		,index_name
		,[index_columns]
		,STRING_AGG(TRIM(incld.include_columns), N',') AS include_columns
	FROM
		IndexIncludeAll AS ix
		OUTER APPLY (
			SELECT DISTINCT TRIM(CAST([value] AS NVARCHAR(1000))) AS include_columns
			FROM STRING_SPLIT(ix.all_include_columns, N',')
		) AS incld
	GROUP BY
		[object_name]
		,index_name
		,[index_columns]
)
SELECT
	[object_name]
	,[index_columns]
	,include_columns
	,REPLACE(REPLACE(REPLACE(REPLACE(
		N'CREATE INDEX [AUTOIX__${INDEX_NAME}] ON ${OBJECT_NAME} (${INDEX_COLUMNS})'
		+ IIF(include_columns IS NULL, N'', N' INCLUDE (${INCLUDE_COLUMNS})')
		+ N' WITH (ONLINE = ON);'
		, N'${INDEX_NAME}', index_name)
		, N'${OBJECT_NAME}', [object_name])
		, N'${INDEX_COLUMNS}', [index_columns])
		, N'${INCLUDE_COLUMNS}', ISNULL(include_columns, N''))
FROM IndexInclude
ORDER BY [object_name], [index_columns];
