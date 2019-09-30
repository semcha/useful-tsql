SELECT
    SCHEMA_NAME(t.[schema_id]) + N'.' + t.[name] AS table_name
   ,i.[name] AS index_name
   ,MAX(i.[type_desc]) AS index_type
   ,CAST(ROUND(SUM(s.[used_page_count]) * 8. / 1024., 0) AS bigint) AS index_size_mb
FROM
    sys.dm_db_partition_stats AS s
    INNER JOIN sys.indexes AS i
        ON s.[object_id] = i.[object_id]
            AND s.[index_id] = i.[index_id]
    INNER JOIN sys.tables AS t
        ON i.[object_id] = t.[object_id]
GROUP BY
    SCHEMA_NAME(t.[schema_id]) + N'.' + t.[name]
   ,i.[name]
ORDER BY i.[name];
