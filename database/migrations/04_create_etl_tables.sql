USE PaymentFlow;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    /* ETL execution log */

    IF OBJECT_ID(N'audit.EtlExecution', N'U') IS NULL
    BEGIN
        CREATE TABLE audit.EtlExecution
        (
            EtlExecutionId bigint IDENTITY(1, 1) NOT NULL,
            PackageName nvarchar(128) NOT NULL,
            SourceFileName nvarchar(260) NOT NULL,

            StartedAtUtc datetime2(3) NOT NULL
                CONSTRAINT DF_EtlExecution_StartedAtUtc
                DEFAULT (SYSUTCDATETIME()),

            CompletedAtUtc datetime2(3) NULL,

            ExecutionStatus varchar(20) NOT NULL
                CONSTRAINT DF_EtlExecution_Status
                DEFAULT ('RUNNING'),

            RowsRead bigint NOT NULL
                CONSTRAINT DF_EtlExecution_RowsRead DEFAULT (0),

            RowsInserted bigint NOT NULL
                CONSTRAINT DF_EtlExecution_RowsInserted DEFAULT (0),

            RowsRejected bigint NOT NULL
                CONSTRAINT DF_EtlExecution_RowsRejected DEFAULT (0),

            ErrorMessage nvarchar(2000) NULL,

            CONSTRAINT PK_EtlExecution
                PRIMARY KEY CLUSTERED (EtlExecutionId),

            CONSTRAINT CK_EtlExecution_Status
                CHECK
                (
                    ExecutionStatus IN
                    (
                        'RUNNING',
                        'SUCCEEDED',
                        'FAILED'
                    )
                ),

            CONSTRAINT CK_EtlExecution_CompletedAt
                CHECK
                (
                    CompletedAtUtc IS NULL
                    OR CompletedAtUtc >= StartedAtUtc
                ),

            CONSTRAINT CK_EtlExecution_RowCounts
                CHECK
                (
                    RowsRead >= 0
                    AND RowsInserted >= 0
                    AND RowsRejected >= 0
                )
        );
    END;

    /* Raw data loaded from the CSV file */

    IF OBJECT_ID
    (
        N'staging.PaymentTransactionRaw',
        N'U'
    ) IS NULL
    BEGIN
        CREATE TABLE staging.PaymentTransactionRaw
        (
            StagingRowId bigint IDENTITY(1, 1) NOT NULL,
            EtlExecutionId bigint NOT NULL,

            ExternalTransactionId nvarchar(50) NULL,
            TerminalCode nvarchar(50) NULL,
            TransactionTypeCode nvarchar(50) NULL,
            StatusCode nvarchar(50) NULL,
            PaymentMethodCode nvarchar(50) NULL,
            CurrencyCode nvarchar(10) NULL,
            AmountText nvarchar(50) NULL,
            OccurredAtUtcText nvarchar(50) NULL,
            AuthorizationCode nvarchar(50) NULL,
            CardNetwork nvarchar(50) NULL,
            MaskedPan nvarchar(50) NULL,

            SourceRowNumber int NULL,

            ProcessingStatus varchar(20) NOT NULL
                CONSTRAINT DF_StagingTransaction_Status
                DEFAULT ('PENDING'),

            LoadedAtUtc datetime2(3) NOT NULL
                CONSTRAINT DF_StagingTransaction_LoadedAtUtc
                DEFAULT (SYSUTCDATETIME()),

            ProcessedAtUtc datetime2(3) NULL,

            CONSTRAINT PK_StagingPaymentTransaction
                PRIMARY KEY CLUSTERED (StagingRowId),

            CONSTRAINT FK_StagingTransaction_EtlExecution
                FOREIGN KEY (EtlExecutionId)
                REFERENCES audit.EtlExecution
                    (EtlExecutionId),

            CONSTRAINT CK_StagingTransaction_Status
                CHECK
                (
                    ProcessingStatus IN
                    (
                        'PENDING',
                        'IMPORTED',
                        'REJECTED'
                    )
                ),

            CONSTRAINT CK_StagingTransaction_SourceRow
                CHECK
                (
                    SourceRowNumber IS NULL
                    OR SourceRowNumber > 0
                )
        );
    END;

    /* Records rejected during validation */

    IF OBJECT_ID
    (
        N'audit.RejectedTransaction',
        N'U'
    ) IS NULL
    BEGIN
        CREATE TABLE audit.RejectedTransaction
        (
            RejectedTransactionId bigint IDENTITY(1, 1)
                NOT NULL,

            EtlExecutionId bigint NOT NULL,
            StagingRowId bigint NOT NULL,
            RejectionCode varchar(50) NOT NULL,
            RejectionReason nvarchar(500) NOT NULL,

            RejectedAtUtc datetime2(3) NOT NULL
                CONSTRAINT DF_RejectedTransaction_RejectedAtUtc
                DEFAULT (SYSUTCDATETIME()),

            CONSTRAINT PK_RejectedTransaction
                PRIMARY KEY CLUSTERED
                (RejectedTransactionId),

            CONSTRAINT FK_RejectedTransaction_Execution
                FOREIGN KEY (EtlExecutionId)
                REFERENCES audit.EtlExecution
                    (EtlExecutionId),

            CONSTRAINT FK_RejectedTransaction_StagingRow
                FOREIGN KEY (StagingRowId)
                REFERENCES staging.PaymentTransactionRaw
                    (StagingRowId)
        );
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

SELECT
    schemaObject.name AS SchemaName,
    tableObject.name AS TableName
FROM sys.tables AS tableObject
INNER JOIN sys.schemas AS schemaObject
    ON schemaObject.schema_id = tableObject.schema_id
WHERE schemaObject.name IN (N'staging', N'audit')
ORDER BY
    schemaObject.name,
    tableObject.name;
GO