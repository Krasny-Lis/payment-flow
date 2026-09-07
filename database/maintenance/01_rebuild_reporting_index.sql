USE PaymentFlow;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/*
Run this targeted maintenance operation only after measuring page density,
fragmentation and reporting performance. Schedule a maintenance window because
an offline rebuild can block access to the index.
*/

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'payment.PaymentTransaction')
      AND name = N'IX_PaymentTransaction_OccurredAtUtc_TerminalId'
)
BEGIN
    THROW 50001,
        'The reporting index does not exist. Run migration 05 first.',
        1;
END;
GO

ALTER INDEX IX_PaymentTransaction_OccurredAtUtc_TerminalId
ON payment.PaymentTransaction
REBUILD WITH
(
    FILLFACTOR = 90,
    SORT_IN_TEMPDB = ON
);
GO

SELECT
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
    OBJECT_ID(N'payment.PaymentTransaction'),
    NULL,
    NULL,
    'SAMPLED'
) AS physicalStats
JOIN sys.indexes AS indexObject
    ON indexObject.object_id = physicalStats.object_id
   AND indexObject.index_id = physicalStats.index_id
WHERE indexObject.name =
      N'IX_PaymentTransaction_OccurredAtUtc_TerminalId'
  AND physicalStats.index_level = 0
  AND physicalStats.alloc_unit_type_desc = N'IN_ROW_DATA';
GO
