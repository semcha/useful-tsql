-- Generate script to modify autogrowth on user databases files
USE [master];
GO

DECLARE @rows_autogrowth_size_mb int = 512
       ,@logs_autogrowth_size_mb int = 256;

SELECT
    DB_NAME(database_id) as [database_name],
	[type_desc],
    [name] as [file_name],
    N'ALTER DATABASE [' + DB_NAME(database_id) + N'] MODIFY FILE ( NAME = N''' + [name]
    + N''', FILEGROWTH = ' + CAST(@rows_autogrowth_size_mb AS nvarchar(50)) + N'MB' + N' );' AS modify_file_sql
FROM
    sys.master_files
WHERE
    database_id > 4
    AND [type] = 0
    AND (growth != @rows_autogrowth_size_mb / 8 * 1024 OR is_percent_growth = 1)
UNION ALL
SELECT
    DB_NAME(database_id) as [database_name],
    [type_desc],
	[name] as [file_name],
    N'ALTER DATABASE [' + DB_NAME(database_id) + N'] MODIFY FILE ( NAME = N''' + [name]
    + N''', FILEGROWTH = ' + CAST(@logs_autogrowth_size_mb AS nvarchar(50)) + N'MB' + N' );' AS modify_file_sql
FROM
    sys.master_files
WHERE
    database_id > 4
    AND [type] = 1
    AND (growth != @logs_autogrowth_size_mb / 8 * 1024 OR is_percent_growth = 1)
ORDER BY [database_name], [name];
