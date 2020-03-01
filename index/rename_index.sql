IF OBJECT_ID(N'tempdb..#index_source') IS NOT NULL
	DROP TABLE #index_source;
SELECT
	ixcol.[object_id]
   ,ixcol.index_id
   ,ix.[type_desc] AS index_type
   ,CASE
		WHEN ix.[type_desc] = N'CLUSTERED' THEN N'CIX_'
		WHEN ix.[type_desc] = N'NONCLUSTERED' THEN N'IX_'
		WHEN ix.[type_desc] = N'CLUSTERED_COLUMNSTORE' THEN N'CCIX_'
		WHEN ix.[type_desc] = N'NONCLUSTERED_COLUMNSTORE' THEN N'NCIX_'
	END AS index_prefix
   ,ixcol.key_ordinal
   ,col.[name] AS column_name
INTO #index_source
FROM
	sys.objects AS obj
	INNER JOIN sys.indexes AS ix
		ON obj.[object_id] = ix.[object_id]
	INNER JOIN sys.index_columns AS ixcol
		ON ix.[object_id] = ixcol.[object_id]
			AND ix.index_id = ixcol.index_id
	INNER JOIN sys.columns AS col
		ON ixcol.[object_id] = col.[object_id]
			AND ixcol.column_id = col.column_id
WHERE
	obj.[type] = N'U'
	AND ix.[type] IN (1, 2, 5, 6)
	AND ix.is_primary_key = 0
	AND ix.is_unique_constraint = 0
	AND ix.is_disabled = 0
	AND ixcol.is_included_column = 0
ORDER BY [object_id], index_id, key_ordinal;

IF OBJECT_ID(N'tempdb..#index_columns') IS NOT NULL
	DROP TABLE #index_columns;
SELECT
	qry.[object_id]
	,qry.index_id
	,STUFF(CAST((
		SELECT
			[text()] = '_' + column_name
		FROM #index_source AS ixsrc
		WHERE
			ixsrc.[object_id] = qry.[object_id]
			AND ixsrc.index_id = qry.index_id
		FOR XML PATH (''), TYPE)
	AS NVARCHAR(MAX))
	, 1, 1, '') AS [columns]
INTO #index_columns
FROM (
	SELECT DISTINCT
		[object_id]
		,index_id
	FROM #index_source
) AS qry;

IF OBJECT_ID(N'tempdb..#index_name') IS NOT NULL
	DROP TABLE #index_name;
SELECT
	ixsrc.[object_id]
   ,ixsrc.index_id
   ,MAX(index_type) AS index_type
   ,MAX(index_prefix) AS index_prefix
   ,CASE
		WHEN MAX(index_type) = N'CLUSTERED' THEN MAX(ixcol.[columns])
		WHEN MAX(index_type) = N'NONCLUSTERED' THEN MAX(ixcol.[columns])
		WHEN MAX(index_type) = N'CLUSTERED_COLUMNSTORE' THEN OBJECT_NAME(ixsrc.[object_id])
		WHEN MAX(index_type) = N'NONCLUSTERED_COLUMNSTORE' THEN OBJECT_NAME(ixsrc.[object_id]) + N'_' + CAST(ixsrc.index_id AS nvarchar(20))
	END AS index_name
INTO #index_name
FROM
	#index_source AS ixsrc
	INNER JOIN #index_columns AS ixcol
		ON ixsrc.[object_id] = ixcol.[object_id]
			AND ixsrc.index_id = ixcol.index_id
GROUP BY
	ixsrc.[object_id]
   ,ixsrc.index_id;

SELECT
	REPLACE(REPLACE(
	N'EXECUTE sys.sp_rename
			@objname = N''${OBJECT_NAME}''
			,@newname = N''${NEW_NAME}''
			,@objtype = N''INDEX'';'
	, N'${OBJECT_NAME}', N'[' + OBJECT_SCHEMA_NAME(ix.[object_id]) + N'].[' + OBJECT_NAME(ix.[object_id]) + N'].[' + ix.[name] + N']')
	, N'${NEW_NAME}', ixnm.index_prefix + ixnm.index_name)
FROM
	sys.indexes AS ix
	INNER JOIN #index_name AS ixnm
		ON ix.[object_id] = ixnm.[object_id]
			AND ix.index_id = ixnm.index_id
WHERE
	ix.[name] != ixnm.index_prefix + ixnm.index_name;
