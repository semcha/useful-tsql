-- Generate script to modify autogrowth on user databases files
USE [master];
GO

DECLARE @rows_autogrowth_size_mb int = 512
	   ,@logs_autogrowth_size_mb int = 256;
SELECT
	N'ALTER DATABASE [' + DB_NAME(database_id) + N'] MODIFY FILE ( NAME = N''' + [name]
	+ N''', FILEGROWTH = ' + CAST(@rows_autogrowth_size_mb AS nvarchar(50)) + N'MB' + N' );' AS modify_file_sql
FROM
	sys.master_files
WHERE
	database_id > 4
	AND [type] = 0
	AND growth < @rows_autogrowth_size_mb / 8 * 1024
UNION ALL
SELECT
	N'ALTER DATABASE [' + DB_NAME(database_id) + N'] MODIFY FILE ( NAME = N''' + [name]
	+ N''', FILEGROWTH = ' + CAST(@logs_autogrowth_size_mb AS nvarchar(50)) + N'MB' + N' );' AS modify_file_sql
FROM
	sys.master_files
WHERE
	database_id > 4
	AND [type] = 1
	AND growth < @logs_autogrowth_size_mb / 8 * 1024;
