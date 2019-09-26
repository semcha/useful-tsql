-- Recommended Trace Flags
-- Based on: https://github.com/ktaranov/sqlserver-kit/blob/master/SQL%20Server%20Trace%20Flag.md#recommended-trace-flags
USE [master];
GO

DECLARE @sql_version int
       ,@product_level nvarchar(10)
       ,@product_update_level nvarchar(10)
       ,@engine_edition int;

SELECT
    @sql_version = CAST(SERVERPROPERTY('ProductMajorVersion') AS int)
   ,@product_level = CAST(SERVERPROPERTY('ProductLevel') AS nvarchar(10))
   ,@product_update_level = CAST(SERVERPROPERTY('ProductUpdateLevel') AS nvarchar(10))
   ,@engine_edition = CAST(SERVERPROPERTY('EngineEdition') AS int);

IF @sql_version < 13
    OR @sql_version > 15
    OR @engine_edition NOT IN (2, 3) -- Standard, Enterprise
    SELECT
        N'Sorry :''('
ELSE
IF @sql_version = 13
    AND @product_level != N'SP2'
    SELECT
        N'Upgrade to SQL Server 2016 SP2 Last CU first: https://www.microsoft.com/en-us/download/details.aspx?id=56975'
ELSE
IF @sql_version BETWEEN 13 AND 15
BEGIN
    DROP TABLE IF EXISTS #trace_flags;

    SELECT
        460 AS tf
    INTO #trace_flags
    WHERE
        (@sql_version = 13
            AND @product_level >= N'SP2'
            AND @product_update_level >= N'CU6')
        OR (@sql_version = 14
            AND @product_update_level >= N'CU14')
    UNION ALL
    SELECT
        3226
    UNION ALL
    SELECT
        3427
    WHERE
        @sql_version = 13
    UNION ALL
    SELECT
        7412
    WHERE
        @sql_version IN (13, 14)
    UNION ALL
    SELECT
        7745;

    SELECT
        N'DBCC TRACEON (' + CAST(tf AS nvarchar(10)) + N');' AS session_enable
       ,N'DBCC TRACEON (' + CAST(tf AS nvarchar(10)) + N', -1);' AS global_enable
       ,N'-T' + CAST(tf AS nvarchar(10)) AS startup_parameter
    FROM
        #trace_flags;

END

