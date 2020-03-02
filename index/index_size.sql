SELECT
    SCHEMA_NAME(tbl.[schema_id]) + N'.' + tbl.[name] AS table_name
   ,ix.index_id
   ,MAX(ix.[type_desc]) AS index_type
   ,MAX(ix.[name]) AS index_name
   ,COUNT(prttn.partition_number) AS partitions_num
   ,CAST(ROUND(SUM(prttn.[used_page_count]) * 8. / 1024., 0) AS BIGINT) AS index_size_mb
FROM
    sys.dm_db_partition_stats AS prttn
    INNER JOIN sys.indexes AS ix
        ON prttn.[object_id] = ix.[object_id]
            AND prttn.[index_id] = ix.[index_id]
    INNER JOIN sys.tables AS tbl
        ON ix.[object_id] = tbl.[object_id]
    INNER JOIN sys.objects AS obj
        ON tbl.[object_id] = obj.[object_id]
WHERE
    obj.is_ms_shipped = 0
    AND obj.[type] = N'U'
GROUP BY
    SCHEMA_NAME(tbl.[schema_id]) + N'.' + tbl.[name]
   ,ix.index_id
ORDER BY index_size_mb DESC;
