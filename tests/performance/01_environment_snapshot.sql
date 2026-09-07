USE PaymentFlow;
GO

SET NOCOUNT ON;

SELECT
    SYSUTCDATETIME() AS CapturedAtUtc,
    SERVERPROPERTY('MachineName') AS MachineName,
    SERVERPROPERTY('ServerName') AS ServerName,
    SERVERPROPERTY('Edition') AS Edition,
    SERVERPROPERTY('ProductVersion') AS ProductVersion,
    SERVERPROPERTY('ProductLevel') AS ProductLevel,
    SERVERPROPERTY('ProductUpdateLevel') AS ProductUpdateLevel;

SELECT
    databaseObject.name AS DatabaseName,
    databaseObject.compatibility_level AS CompatibilityLevel,
    databaseObject.recovery_model_desc AS RecoveryModel,
    databaseObject.page_verify_option_desc AS PageVerification,
    databaseObject.is_auto_create_stats_on AS AutoCreateStatistics,
    databaseObject.is_auto_update_stats_on AS AutoUpdateStatistics,
    databaseObject.is_query_store_on AS QueryStoreEnabled,
    databaseObject.collation_name AS CollationName
FROM sys.databases AS databaseObject
WHERE databaseObject.database_id = DB_ID();

SELECT
    fileObject.name AS LogicalFileName,
    fileObject.type_desc AS FileType,
    CAST(fileObject.size * 8.0 / 1024 AS decimal(18, 2)) AS SizeMb,
    CASE
        WHEN fileObject.is_percent_growth = 1
            THEN CONCAT(fileObject.growth, '%')
        ELSE CONCAT(
            CAST(fileObject.growth * 8.0 / 1024 AS decimal(18, 2)),
            ' MB'
        )
    END AS GrowthSetting,
    fileObject.physical_name AS PhysicalFileName
FROM sys.database_files AS fileObject
ORDER BY fileObject.type_desc, fileObject.file_id;

;WITH TableStorage AS
(
    SELECT
        partitionStats.object_id,
        SUM
        (
            CASE
                WHEN partitionStats.index_id IN (0, 1)
                    THEN partitionStats.row_count
                ELSE 0
            END
        ) AS ApproximateRowCount,
        SUM(partitionStats.reserved_page_count) AS ReservedPageCount,
        SUM(partitionStats.used_page_count) AS UsedPageCount
    FROM sys.dm_db_partition_stats AS partitionStats
    GROUP BY partitionStats.object_id
)
SELECT
    schemaObject.name AS SchemaName,
    tableObject.name AS TableName,
    tableStorage.ApproximateRowCount,
    CAST(
        tableStorage.ReservedPageCount * 8.0 / 1024
        AS decimal(18, 2)
    ) AS ReservedMb,
    CAST(
        tableStorage.UsedPageCount * 8.0 / 1024
        AS decimal(18, 2)
    ) AS UsedMb
FROM sys.tables AS tableObject
JOIN sys.schemas AS schemaObject
    ON schemaObject.schema_id = tableObject.schema_id
JOIN TableStorage AS tableStorage
    ON tableStorage.object_id = tableObject.object_id
ORDER BY
    ReservedMb DESC,
    SchemaName,
    TableName;

SELECT
    schemaObject.name AS SchemaName,
    tableObject.name AS TableName,
    indexObject.name AS IndexName,
    indexObject.type_desc AS IndexType,
    indexObject.is_unique AS IsUnique,
    indexObject.is_disabled AS IsDisabled
FROM sys.indexes AS indexObject
JOIN sys.tables AS tableObject
    ON tableObject.object_id = indexObject.object_id
JOIN sys.schemas AS schemaObject
    ON schemaObject.schema_id = tableObject.schema_id
WHERE indexObject.index_id > 0
ORDER BY
    SchemaName,
    TableName,
    indexObject.index_id;
GO
