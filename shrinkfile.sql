USE [master];

-- user databases
SELECT
	REPLACE(REPLACE(
	N'
	USE @DATABASE_NAME;
	GO
	DBCC SHRINKFILE (N''@FILE_NAME'', 1);
	GO'
	, N'@DATABASE_NAME', db.[name])
	, N'@FILE_NAME', dbfl.[name])
	, dbfl.[type_desc]
FROM sys.databases AS db
INNER JOIN sys.master_files AS dbfl
	ON db.database_id = dbfl.database_id
WHERE db.database_id > 4
ORDER BY dbfl.[type_desc], db.[name];

-- tempdb
SELECT
	REPLACE(REPLACE(
	N'
	USE @DATABASE_NAME;
	GO
	DBCC SHRINKFILE (N''@FILE_NAME'', 1);
	GO'
	, N'@DATABASE_NAME', db.[name])
	, N'@FILE_NAME', dbfl.[name])
	, dbfl.[type_desc]
FROM sys.databases AS db
INNER JOIN sys.master_files AS dbfl
	ON db.database_id = dbfl.database_id
WHERE db.[name] = N'tempdb';
