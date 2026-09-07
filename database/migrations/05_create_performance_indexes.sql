USE PaymentFlow;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* Cover the fact-table columns used by the reporting views. */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'payment.PaymentTransaction')
      AND name = N'IX_PaymentTransaction_OccurredAtUtc_TerminalId'
)
BEGIN
    CREATE NONCLUSTERED INDEX
        IX_PaymentTransaction_OccurredAtUtc_TerminalId
    ON payment.PaymentTransaction
    (
        OccurredAtUtc,
        TerminalId
    )
    INCLUDE
    (
        TransactionTypeId,
        TransactionStatusId,
        PaymentMethodId,
        CurrencyCode,
        Amount
    )
    WITH
    (
        FILLFACTOR = 90
    );
END;
GO

/* Locate rows belonging to one ETL execution without scanning old batches. */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'staging.PaymentTransactionRaw')
      AND name = N'IX_PaymentTransactionRaw_Execution_Status'
)
BEGIN
    CREATE NONCLUSTERED INDEX
        IX_PaymentTransactionRaw_Execution_Status
    ON staging.PaymentTransactionRaw
    (
        EtlExecutionId,
        ProcessingStatus,
        StagingRowId
    );
END;
GO

/* Support rejection summaries for a selected ETL execution. */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'audit.RejectedTransaction')
      AND name = N'IX_RejectedTransaction_Execution_Code'
)
BEGIN
    CREATE NONCLUSTERED INDEX
        IX_RejectedTransaction_Execution_Code
    ON audit.RejectedTransaction
    (
        EtlExecutionId,
        RejectionCode
    );
END;
GO

/* Index the foreign key used to verify and retrieve transaction history. */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'payment.TransactionStatusHistory')
      AND name = N'IX_TransactionStatusHistory_TransactionId'
)
BEGIN
    CREATE NONCLUSTERED INDEX
        IX_TransactionStatusHistory_TransactionId
    ON payment.TransactionStatusHistory
    (
        TransactionId
    )
    INCLUDE
    (
        TransactionStatusId,
        ChangedAtUtc
    );
END;
GO

SELECT
    schemaObject.name AS SchemaName,
    tableObject.name AS TableName,
    indexObject.name AS IndexName,
    indexObject.type_desc AS IndexType
FROM sys.indexes AS indexObject
JOIN sys.tables AS tableObject
    ON tableObject.object_id = indexObject.object_id
JOIN sys.schemas AS schemaObject
    ON schemaObject.schema_id = tableObject.schema_id
WHERE indexObject.name IN
(
    N'IX_PaymentTransaction_OccurredAtUtc_TerminalId',
    N'IX_PaymentTransactionRaw_Execution_Status',
    N'IX_RejectedTransaction_Execution_Code',
    N'IX_TransactionStatusHistory_TransactionId'
)
ORDER BY
    SchemaName,
    TableName,
    IndexName;
GO
