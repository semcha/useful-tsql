SELECT
	db.[name] AS [database_name]
	,dbfl.[name] AS [file_name]
	,CAST(dbfl.size * 8. / 1024. / 1024. as decimal(19, 2)) AS disk_space_gb
	,dbfl.[type_desc] AS file_type
	,dbfl.physical_name
FROM
	sys.databases as db 
	INNER JOIN sys.master_files as dbfl
		ON db.database_id = dbfl.database_id
ORDER BY [database_name], [file_name];

EXECUTE sys.xp_fixeddrives;
