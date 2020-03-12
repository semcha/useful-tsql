WITH table_clustering AS (
    SELECT
        ix.[object_id]
       ,ix.index_id
       ,CASE
            WHEN ix.is_primary_key = 1 THEN ix.[type_desc] + N' PK'
            WHEN ix.is_unique = 1 THEN ix.[type_desc] + N' UNIQUE'
            WHEN ix.is_disabled = 1 THEN N'!!! DISABLED ' + ix.[type_desc]
            ELSE ix.[type_desc]
        END AS clustering_type
    FROM
        sys.indexes AS ix
    WHERE
        ix.[type] IN (0, 1, 5) -- HEAP, CLUSTERED B-tree/Columnstore
),
table_partitions AS (
    SELECT
        p.[object_id]
       ,p.index_id
       ,COUNT(1) AS partitions_count
       ,SUM(p.[rows]) AS rows_count
       ,MIN(p.data_compression_desc) AS [compression]
       ,COUNT(IIF(p.[data_compression] IS NOT NULL, 1, NULL)) AS compressed_partitions
    FROM
        sys.partitions AS p
    GROUP BY
        p.[object_id]
       ,p.index_id
),
table_space AS (
    SELECT
        s.[object_id]
       ,CAST(SUM(s.[used_page_count]) * 8. / 1024. / 1024. AS decimal(19, 2)) AS reserved_gb
       ,CAST(SUM(IIF(ix.[type] IN (0, 1, 5), s.[used_page_count], 0)) * 8. / 1024. / 1024. AS decimal(19, 2)) AS table_gb
       ,CAST(SUM(IIF(ix.[type] IN (2, 6, 7), s.[used_page_count], 0)) * 8. / 1024. / 1024. AS decimal(19, 2)) AS indexes_gb
    FROM
        sys.dm_db_partition_stats AS s
        INNER JOIN sys.indexes AS ix
            ON s.[object_id] = ix.[object_id]
                AND s.index_id = ix.index_id
    GROUP BY
        s.[object_id]
),
nc_indexes_source AS (
    SELECT
        qryix.[object_id]
       ,LTRIM(
        qryix.index_is_disabled
        + N' ' + qryix.index_has_filter
        + N' ' + qryix.index_type_1
        + N' ' + qryix.index_type_2
        + N': ' + CAST(qryix.index_count AS nvarchar(50))
        ) AS index_type
    FROM
        (
            SELECT
                ix.[object_id]
               ,ix.[type]
               ,ix.is_unique
               ,ix.is_primary_key
               ,ix.is_unique_constraint
               ,ix.is_disabled
               ,COUNT(1) AS index_count
               ,CASE
                    WHEN ix.is_disabled = 1 THEN N'FILTERED'
                    ELSE N''
                END AS index_is_disabled
               ,CASE
                    WHEN ix.has_filter = 1 THEN N'FILTERED'
                    ELSE N''
                END AS index_has_filter
               ,CASE
                    WHEN ix.[type] = 2 THEN N'NC B-TREE'
                    WHEN ix.[type] = 6 THEN N'NC COLUMNSTORE'
                    WHEN ix.[type] = 7 THEN N'HASH'
                END index_type_1
               ,CASE
                    WHEN ix.is_primary_key = 1 THEN N'PK'
                    WHEN ix.is_unique_constraint = 1 THEN N'UQ CNSTRNT'
                    WHEN ix.is_unique = 1 THEN N'UQ'
                    ELSE N''
                END index_type_2
            FROM
                sys.indexes AS ix
            WHERE
                ix.[type] IN (2, 6, 7) -- NONCLUSTERED B-tree/Columnstore, HASH
            GROUP BY
                ix.[object_id]
               ,ix.[type]
               ,ix.is_unique
               ,ix.is_primary_key
               ,ix.is_unique_constraint
               ,ix.is_disabled
               ,ix.has_filter
        ) AS qryix
),
nc_indexes AS (
    SELECT
        ncix.[object_id]
       ,N'{' + STUFF(CAST((
            SELECT
                [text()] = '; ' + index_type
            FROM
                nc_indexes_source AS qry
            WHERE
                qry.[object_id] = ncix.[object_id]
            FOR xml PATH (''), TYPE
        )
        AS nvarchar(max))
        , 1, 1, N'') + N'}' AS nc_indexes
    FROM
        (
            SELECT DISTINCT
                [object_id]
            FROM
                nc_indexes_source
        ) AS ncix
)
SELECT
    DB_NAME() AS [database_name]
   ,t.[object_id]
   ,OBJECT_SCHEMA_NAME(t.[object_id]) + N'.' + t.[name] AS table_name
   ,t.is_memory_optimized AS is_inmem
   ,tblcls.clustering_type
   ,tblprttn.partitions_count
   ,tblprttn.compressed_partitions
   ,tblprttn.[compression]
   ,tblprttn.rows_count
   ,tblspc.reserved_gb
   ,tblspc.table_gb
   ,tblspc.indexes_gb
   ,ncix.nc_indexes
FROM
    sys.tables AS t
    INNER JOIN table_clustering AS tblcls
        ON t.[object_id] = tblcls.[object_id]
    INNER JOIN table_partitions AS tblprttn
        ON t.[object_id] = tblprttn.[object_id]
            AND tblcls.index_id = tblprttn.index_id
    INNER JOIN table_space AS tblspc
        ON t.[object_id] = tblspc.[object_id]
    LEFT JOIN nc_indexes AS ncix
        ON t.[object_id] = ncix.[object_id]
WHERE
    t.[type] = N'U'
ORDER BY tblspc.reserved_gb DESC;
