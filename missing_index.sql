IF OBJECT_ID(N'tempdb..#missing_index') IS NOT NULL
	DROP TABLE #missing_index;

SELECT
	db.[name] AS [database_name]
   ,id.[object_id] AS [object_id]
   ,OBJECT_NAME(id.[object_id], db.database_id) AS [object_name]
   ,id.[statement] AS full_name
   ,id.equality_columns
   ,id.inequality_columns
   ,id.included_columns
   ,gs.unique_compiles
   ,gs.user_seeks
   ,gs.user_scans
   ,gs.last_user_seek
   ,gs.last_user_scan
   ,gs.avg_total_user_cost -- Average cost of the user queries that could be reduced by the index in the group.
   ,gs.avg_user_impact -- The value means that the query cost would on average drop by this percentage if this missing index group was implemented.
   ,avg_total_user_cost * avg_user_impact * (user_seeks + user_scans) AS index_advantage
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

SELECT *
FROM #missing_index
ORDER BY full_name;

WITH IndexFull AS (
	SELECT
		full_name
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
		full_name
		,index_name
		,[index_columns]
		,STRING_AGG(included_columns, N',') AS all_include_columns
	FROM
		IndexFull
	GROUP BY
		full_name
		,index_name
		,[index_columns]
),
IndexInclude AS (
	SELECT
		full_name
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
		full_name
		,index_name
		,[index_columns]
)
SELECT
	full_name
	,[index_columns]
	,include_columns
	,REPLACE(REPLACE(REPLACE(REPLACE(
		N'CREATE INDEX [AUTOIX__${INDEX_NAME}] ON ${OBJECT_NAME} (${INDEX_COLUMNS})'
		+ IIF(include_columns IS NULL, N'', N' INCLUDE (${INCLUDE_COLUMNS})')
		+ N' WITH (ONLINE = ON);'
		, N'${INDEX_NAME}', index_name)
		, N'${OBJECT_NAME}', full_name)
		, N'${INDEX_COLUMNS}', [index_columns])
		, N'${INCLUDE_COLUMNS}', ISNULL(include_columns, N''))
FROM IndexInclude
ORDER BY full_name, [index_columns];