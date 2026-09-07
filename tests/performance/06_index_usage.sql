USE PaymentFlow;
GO

SET NOCOUNT ON;

SELECT
    schemaObject.name AS SchemaName,
    tableObject.name AS TableName,
    indexObject.name AS IndexName,
    indexObject.type_desc AS IndexType,
    indexObject.is_unique AS IsUnique,
    COALESCE(usageStats.user_seeks, 0) AS UserSeeks,
    COALESCE(usageStats.user_scans, 0) AS UserScans,
    COALESCE(usageStats.user_lookups, 0) AS UserLookups,
    COALESCE(usageStats.user_updates, 0) AS UserUpdates,
    usageStats.last_user_seek AS LastUserSeek,
    usageStats.last_user_scan AS LastUserScan
FROM sys.indexes AS indexObject
JOIN sys.tables AS tableObject
    ON tableObject.object_id = indexObject.object_id
JOIN sys.schemas AS schemaObject
    ON schemaObject.schema_id = tableObject.schema_id
LEFT JOIN sys.dm_db_index_usage_stats AS usageStats
    ON usageStats.database_id = DB_ID()
   AND usageStats.object_id = indexObject.object_id
   AND usageStats.index_id = indexObject.index_id
WHERE indexObject.index_id > 0
  AND schemaObject.name IN ('payment', 'staging', 'audit')
ORDER BY
    SchemaName,
    TableName,
    IndexName;

SELECT
    schemaObject.name AS SchemaName,
    tableObject.name AS TableName,
    indexObject.name AS IndexName,
    partitionStats.row_count AS IndexRowCount,
    CAST(
        partitionStats.reserved_page_count * 8.0 / 1024
        AS decimal(18, 2)
    ) AS ReservedMb,
    CAST(
        partitionStats.used_page_count * 8.0 / 1024
        AS decimal(18, 2)
    ) AS UsedMb
FROM sys.dm_db_partition_stats AS partitionStats
JOIN sys.indexes AS indexObject
    ON indexObject.object_id = partitionStats.object_id
   AND indexObject.index_id = partitionStats.index_id
JOIN sys.tables AS tableObject
    ON tableObject.object_id = indexObject.object_id
JOIN sys.schemas AS schemaObject
    ON schemaObject.schema_id = tableObject.schema_id
WHERE indexObject.index_id > 0
  AND schemaObject.name IN ('payment', 'staging', 'audit')
ORDER BY ReservedMb DESC;
GO
