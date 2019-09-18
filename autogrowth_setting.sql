-- Generate script to modify autogrowth on user databases files
USE [master];
GO

DECLARE @rows_file_size_mb int = 512
	   ,@logs_file_size_mb int = 256;
SELECT
	N'ALTER DATABASE [' + DB_NAME(database_id) + N'] MODIFY FILE ( NAME = N''' + [name] + N''', FILEGROWTH = ' +
	CASE [type_desc]
		WHEN N'ROWS' THEN CAST(@rows_file_size_mb AS nvarchar(50)) + N'MB'
		WHEN N'LOG' THEN CAST(@logs_file_size_mb AS nvarchar(50)) + N'MB'
	END + N' );' AS modify_file_sql
FROM
	sys.master_files
WHERE
	database_id > 4;
