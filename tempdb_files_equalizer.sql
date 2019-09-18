-- Tempdb Files Equalizer
USE tempdb;
GO

-- Shrink
SELECT
    N'DBCC SHRINKFILE (N''' + [name] + ''' , 1);' AS shrink_sql
FROM
    sys.database_files;

-- Modify / Add files
DECLARE @min_rows_file_size_mb int = 1024
       ,@rows_autogrowth_size_mb int = 512
       ,@logs_autogrowth_size_mb int = 256
       ,@tempdb_file_path nvarchar(250) = (
            SELECT
                REPLACE(physical_name, N'tempdb.mdf', N'')
            FROM
                sys.database_files
            WHERE
                [file_id] = 1
        );

WITH max_size_file
AS
(
    SELECT
        IIF(
        MAX([size] * 8 / 1024) < @min_rows_file_size_mb
        , @min_rows_file_size_mb
        , MAX([size] * 8 / 1024)
        ) AS rows_max_size_mb
       ,COUNT(*) AS rows_file_count
    FROM
        sys.database_files
    WHERE
        [type] = 0
)
SELECT
    N'ALTER DATABASE [' + DB_NAME() + N'] '
    + N'MODIFY FILE ( NAME = N''' + dbfl.[name] + N''', '
    + N'SIZE = ' + CAST(ms.rows_max_size_mb AS nvarchar(50)) + N'MB, '
    + N'FILEGROWTH = ' + CAST(@rows_autogrowth_size_mb AS nvarchar(50)) + N'MB );'
    AS alter_database_files_sql
FROM
    sys.database_files AS dbfl
    CROSS JOIN (
        SELECT
            rows_max_size_mb
        FROM
            max_size_file
    ) AS ms
WHERE
    [type] = 0
UNION ALL
SELECT
    N'ALTER DATABASE [' + DB_NAME() + N'] '
    + N'MODIFY FILE ( NAME = N''' + [name] + N''', '
    + N'FILEGROWTH = ' + CAST(@logs_autogrowth_size_mb AS nvarchar(50)) + N'MB );' AS alter_sql
FROM
    sys.database_files
WHERE
    [type] = 1
UNION ALL
SELECT
    N'ALTER DATABASE [' + DB_NAME() + N'] ADD FILE ( NAME = N''temp' + CAST(q.rownum AS nvarchar(50)) + N''', '
    + N'FILENAME = N''' + @tempdb_file_path + N'tempdb_mssql_' + CAST(q.rownum AS nvarchar(50)) + '.ndf''' + N', '
    + N'SIZE = ' + CAST(ms.rows_max_size_mb AS nvarchar(50)) + N'MB, '
    + N'FILEGROWTH = ' + CAST(@rows_autogrowth_size_mb AS nvarchar(50)) + N'MB );'
FROM
    (
        SELECT
            ROW_NUMBER() OVER (ORDER BY (
                SELECT
                    NULL
            )
            ) AS rownum
        FROM
            [master].dbo.spt_values
    ) AS q
    CROSS JOIN (
        SELECT
            rows_max_size_mb
           ,rows_file_count
        FROM
            max_size_file
    ) AS ms
WHERE
    q.rownum BETWEEN ms.rows_file_count + 1 AND 8;