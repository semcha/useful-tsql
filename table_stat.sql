with table_clustering as (
    select
        ix.[object_id]
       ,ix.index_id
       ,case
            when ix.is_primary_key = 1 then ix.[type_desc] + N' PK'
            when ix.is_unique = 1 then ix.[type_desc] + N' UNIQUE'
            when ix.is_disabled = 1 then N'!!! DISABLED ' + ix.[type_desc]
            else ix.[type_desc]
        end as table_organization
    from
        sys.indexes as ix with (nolock)
    where
        ix.[type] in (0, 1, 5) -- HEAP, CLUSTERED B-tree/Columnstore
),
table_partitions as (
    select
        p.[object_id]
       ,p.index_id
       ,count(1) as partitions_count
       ,sum(p.[rows]) as rows_count
       ,min(p.data_compression_desc) as [compression]
       ,count(iif(p.[data_compression] > 0, 1, null)) as compressed_partitions
    from
        sys.partitions as p with (nolock)
    group by
        p.[object_id]
       ,p.index_id
),
table_space as (
    select
        s.[object_id]
       ,cast(sum(s.[used_page_count]) * 8. / 1024. / 1024. as decimal(19, 2)) as reserved_gb
       ,cast(sum(iif(ix.[type] in (0, 1, 5), s.[used_page_count], 0)) * 8. / 1024. / 1024. as decimal(19, 2)) as table_gb
       ,cast(sum(iif(ix.[type] in (2, 6, 7), s.[used_page_count], 0)) * 8. / 1024. / 1024. as decimal(19, 2)) as indexes_gb
    from
        sys.dm_db_partition_stats as s with (nolock)
        inner join sys.indexes as ix with (nolock)
            on s.[object_id] = ix.[object_id]
                and s.index_id = ix.index_id
    group by
        s.[object_id]
),
nc_indexes_source as (
    select
        qryix.[object_id]
       ,ltrim(
        qryix.index_is_disabled
        + N' ' + qryix.index_has_filter
        + N' ' + qryix.index_type_1
        + N' ' + qryix.index_type_2
        + N': ' + cast(qryix.index_count as nvarchar(50))
        ) as index_type
    from
        (
            select
                ix.[object_id]
               ,ix.[type]
               ,ix.is_unique
               ,ix.is_primary_key
               ,ix.is_unique_constraint
               ,ix.is_disabled
               ,count(1) as index_count
               ,case
                    when ix.is_disabled = 1 then N'!!! DISABLED'
                    else N''
                end as index_is_disabled
               ,case
                    when ix.has_filter = 1 then N'FILTERED'
                    else N''
                end as index_has_filter
               ,case
                    when ix.[type] = 2 then N'NC B-TREE'
                    when ix.[type] = 6 then N'NC COLUMNSTORE'
                    when ix.[type] = 7 then N'HASH'
                end index_type_1
               ,case
                    when ix.is_primary_key = 1 then N'PK'
                    when ix.is_unique_constraint = 1 then N'UQ CNSTRNT'
                    when ix.is_unique = 1 then N'UQ'
                    else N''
                end index_type_2
            from
                sys.indexes as ix with (nolock)
            where
                ix.[type] in (2, 6, 7) -- NONCLUSTERED B-tree/Columnstore, HASH
            group by
                ix.[object_id]
               ,ix.[type]
               ,ix.is_unique
               ,ix.is_primary_key
               ,ix.is_unique_constraint
               ,ix.is_disabled
               ,ix.has_filter
        ) as qryix
),
nc_indexes as (
    select
        ncix.[object_id]
       ,N'{' + stuff(cast((
            select
                [text()] = '; ' + index_type
            from
                nc_indexes_source as qry
            where
                qry.[object_id] = ncix.[object_id]
            for xml path (''), type
        )
        as nvarchar(max))
        , 1, 1, N'') + N'}' as nc_indexes
    from
        (
            select distinct
                [object_id]
            from
                nc_indexes_source
        ) as ncix
)
select
    db_name() as [database_name]
   ,t.[object_id]
   ,object_schema_name(t.[object_id]) + N'.' + t.[name] as table_name
   ,t.is_memory_optimized as is_inmem
   ,tblcls.table_organization
   ,tblprttn.partitions_count
   ,tblprttn.compressed_partitions
   ,tblprttn.[compression]
   ,tblprttn.rows_count
   ,tblspc.reserved_gb
   ,tblspc.table_gb
   ,tblspc.indexes_gb
   ,ncix.nc_indexes
from
    sys.tables as t with (nolock)
    inner join table_clustering as tblcls
        on t.[object_id] = tblcls.[object_id]
    inner join table_partitions as tblprttn
        on t.[object_id] = tblprttn.[object_id]
            and tblcls.index_id = tblprttn.index_id
    inner join table_space as tblspc
        on t.[object_id] = tblspc.[object_id]
    left join nc_indexes as ncix
        on t.[object_id] = ncix.[object_id]
where
    t.[type] = N'U'
order by tblspc.reserved_gb desc;

select
    object_schema_name(t.[object_id]) + N'.' + t.[name] as table_name
   ,ix.[type_desc] as index_type
   ,ix.[name] as index_name
   ,ps.[name] as p_scheme
   ,pf.[name] as p_function
   ,col.[name] as p_column
   ,prttnvl.p_function_min_value
   ,prttnvl.p_function_max_value
from
    sys.tables as t with (nolock)
    inner join sys.indexes as ix with (nolock)
        on t.object_id = ix.object_id
    inner join sys.partition_schemes as ps with (nolock)
        on ix.data_space_id = ps.data_space_id
    inner join sys.partition_functions as pf with (nolock)
        on ps.function_id = pf.function_id
    inner join sys.index_columns as ixcol with (nolock)
        on ix.[object_id] = ixcol.[object_id]
            and ix.index_id = ixcol.index_id
            and ixcol.partition_ordinal > 0
    inner join sys.columns as col with (nolock)
        on ixcol.[object_id] = col.[object_id]
            and ixcol.column_id = col.column_id
    inner join (
        select
            prv.function_id
           ,min(prv.[value]) as p_function_min_value
           ,max(prv.[value]) as p_function_max_value
        from
            sys.partition_range_values as prv with (nolock)
        group by
            prv.function_id
    ) as prttnvl
        on pf.function_id = prttnvl.function_id;
