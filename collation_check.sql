DECLARE @ServerCollation nvarchar(255) = (
    SELECT
        CONVERT(nvarchar(255), SERVERPROPERTY('collation'))
);

SELECT
    [name]
   ,collation_name
FROM
    sys.databases
WHERE
    collation_name != @ServerCollation;

DROP TABLE IF EXISTS ##collation_check;
CREATE TABLE ##collation_check (
    [database_name] nvarchar(255)
   ,table_name nvarchar(255)
   ,column_name nvarchar(255)
   ,column_type nvarchar(255)
   ,column_max_length nvarchar(255)
   ,collation_name nvarchar(255)
);

DECLARE @SQL nvarchar(max) = N'
    USE [?];
    INSERT INTO ##collation_check
    SELECT
        DB_NAME()
       ,SCHEMA_NAME(t.schema_id) + N''.'' + t.[name]
       ,c.[name]
       ,tp.[name]
       ,c.max_length
       ,c.collation_name
    FROM
        sys.tables AS t
        INNER JOIN sys.columns AS c
            ON t.object_id = c.object_id
        INNER JOIN sys.types AS tp
            ON c.user_type_id = tp.user_type_id
    WHERE
        c.collation_name != ''' + @ServerCollation + N'''';

EXEC sp_MSforeachdb @SQL;

SELECT * FROM ##collation_check;

