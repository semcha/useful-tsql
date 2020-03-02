IF OBJECT_ID(N'tempdb..##disabled_indexes_01') IS NOT NULL
    DROP TABLE ##disabled_indexes_01;
CREATE TABLE ##disabled_indexes_01 (
    [database_name] NVARCHAR(255)
   ,drop_sql NVARCHAR(1000)
);

EXECUTE sp_MSforeachdb N'USE [?]
	INSERT INTO ##disabled_indexes_01 ([database_name], drop_sql)
	SELECT
		DB_NAME() AS [database_name]
		,N''DROP INDEX ['' + OBJECT_SCHEMA_NAME([object_id]) + N''].['' + OBJECT_NAME([object_id]) + N'']''
		+ N''.['' + [name] + N''];'' AS [drop_sql]
	FROM
		sys.indexes
	WHERE
		is_disabled = 1;
';

SELECT
    *
FROM
    ##disabled_indexes_01;
