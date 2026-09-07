USE PaymentFlow;
GO

SET NOCOUNT ON;

SELECT
    schemaObject.name AS SchemaName,
    tableObject.name AS TableName,
    indexObject.name AS IndexName,
    physicalStats.page_count AS PageCount,
    CAST
    (
        physicalStats.avg_fragmentation_in_percent
        AS decimal(10, 2)
    ) AS FragmentationPercent,
    CAST
    (
        physicalStats.avg_page_space_used_in_percent
        AS decimal(10, 2)
    ) AS PageSpaceUsedPercent
FROM sys.dm_db_index_physical_stats
(
    DB_ID(),
    NULL,
    NULL,
    NULL,
    'SAMPLED'
) AS physicalStats
JOIN sys.indexes AS indexObject
    ON indexObject.object_id = physicalStats.object_id
   AND indexObject.index_id = physicalStats.index_id
JOIN sys.tables AS tableObject
    ON tableObject.object_id = indexObject.object_id
JOIN sys.schemas AS schemaObject
    ON schemaObject.schema_id = tableObject.schema_id
WHERE physicalStats.index_level = 0
  AND physicalStats.alloc_unit_type_desc = N'IN_ROW_DATA'
  AND indexObject.name IN
  (
      N'IX_PaymentTransaction_OccurredAtUtc_TerminalId',
      N'IX_PaymentTransactionRaw_Execution_Status',
      N'IX_TransactionStatusHistory_TransactionId',
      N'IX_RejectedTransaction_Execution_Code'
  )
ORDER BY physicalStats.page_count DESC;
GO
