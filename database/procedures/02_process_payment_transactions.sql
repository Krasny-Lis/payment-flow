USE PaymentFlow;
GO

CREATE OR ALTER PROCEDURE audit.usp_ProcessPaymentTransactions
    @EtlExecutionId bigint,
    @RowsRead bigint
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @ActualRows bigint,
        @RowsInserted bigint = 0,
        @RowsRejected bigint = 0,
        @SourceFileName nvarchar(260);

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT
            @SourceFileName = SourceFileName
        FROM audit.EtlExecution WITH (UPDLOCK, HOLDLOCK)
        WHERE EtlExecutionId = @EtlExecutionId
          AND ExecutionStatus = 'RUNNING';

        IF @SourceFileName IS NULL
            THROW 50010, 'Running ETL execution was not found.', 1;

        SELECT
            @ActualRows = COUNT_BIG(*)
        FROM staging.PaymentTransactionRaw
        WHERE EtlExecutionId = @EtlExecutionId;

        IF @ActualRows <> @RowsRead
            THROW 50011, 'SSIS row count does not match staging row count.', 1;

        /* Normalize text values */

        SELECT
            raw.StagingRowId,
            raw.SourceRowNumber,

            NULLIF(TRIM(raw.ExternalTransactionId), N'')
                AS ExternalTransactionIdText,

            UPPER(NULLIF(TRIM(raw.TerminalCode), N''))
                AS TerminalCode,

            UPPER(NULLIF(TRIM(raw.TransactionTypeCode), N''))
                AS TransactionTypeCode,

            UPPER(NULLIF(TRIM(raw.StatusCode), N''))
                AS StatusCode,

            UPPER(NULLIF(TRIM(raw.PaymentMethodCode), N''))
                AS PaymentMethodCode,

            UPPER(NULLIF(TRIM(raw.CurrencyCode), N''))
                AS CurrencyCode,

            NULLIF(TRIM(raw.AuthorizationCode), N'')
                AS AuthorizationCode,

            UPPER(NULLIF(TRIM(raw.CardNetwork), N''))
                AS CardNetwork,

            NULLIF(TRIM(raw.MaskedPan), N'')
                AS MaskedPan,

            TRY_CONVERT(
                uniqueidentifier,
                NULLIF(TRIM(raw.ExternalTransactionId), N'')
            ) AS ParsedExternalTransactionId,

            TRY_CONVERT(
                decimal(19,4),
                NULLIF(TRIM(raw.AmountText), N'')
            ) AS ParsedAmount,

            TRY_CONVERT(
                datetimeoffset(3),
                NULLIF(TRIM(raw.OccurredAtUtcText), N''),
                127
            ) AS ParsedOccurredAtUtc
        INTO #Normalized
        FROM staging.PaymentTransactionRaw AS raw
        WHERE raw.EtlExecutionId = @EtlExecutionId
          AND raw.ProcessingStatus = 'PENDING';

        /* Detect duplicates within a single file */

        SELECT
            normalized.*,
            ROW_NUMBER() OVER
            (
                PARTITION BY normalized.ParsedExternalTransactionId
                ORDER BY normalized.StagingRowId
            ) AS DuplicateRank
        INTO #Source
        FROM #Normalized AS normalized;

        /* Map codes to reference data */

        SELECT
            source.*,
            terminal.TerminalId,
            transactionType.TransactionTypeId,
            transactionStatus.TransactionStatusId,
            paymentMethod.PaymentMethodId,
            currency.CurrencyCode AS ResolvedCurrencyCode,
            existingTransaction.TransactionId AS ExistingTransactionId,

            CAST(NULL AS varchar(50)) AS RejectionCode,
            CAST(NULL AS nvarchar(500)) AS RejectionReason
        INTO #Prepared
        FROM #Source AS source

        LEFT JOIN payment.Terminal AS terminal
            ON terminal.TerminalCode = source.TerminalCode
           AND terminal.IsActive = 1

        LEFT JOIN payment.TransactionType AS transactionType
            ON transactionType.TypeCode = source.TransactionTypeCode

        LEFT JOIN payment.TransactionStatus AS transactionStatus
            ON transactionStatus.StatusCode = source.StatusCode

        LEFT JOIN payment.PaymentMethod AS paymentMethod
            ON paymentMethod.MethodCode = source.PaymentMethodCode
           AND paymentMethod.IsActive = 1

        LEFT JOIN payment.Currency AS currency
            ON currency.CurrencyCode = source.CurrencyCode
           AND currency.IsActive = 1

        LEFT JOIN payment.PaymentTransaction AS existingTransaction
            ON existingTransaction.ExternalTransactionId =
               source.ParsedExternalTransactionId;

        /* Determine the rejection reason */

        UPDATE prepared
        SET
            RejectionCode =
                CASE
                    WHEN ParsedExternalTransactionId IS NULL
                        THEN 'INVALID_EXTERNAL_ID'
                    WHEN DuplicateRank > 1
                        THEN 'DUPLICATE_IN_FILE'
                    WHEN ExistingTransactionId IS NOT NULL
                        THEN 'ALREADY_IMPORTED'
                    WHEN TerminalId IS NULL
                        THEN 'TERMINAL_NOT_FOUND'
                    WHEN TransactionTypeId IS NULL
                        THEN 'TRANSACTION_TYPE_NOT_FOUND'
                    WHEN TransactionStatusId IS NULL
                        THEN 'STATUS_NOT_FOUND'
                    WHEN PaymentMethodId IS NULL
                        THEN 'PAYMENT_METHOD_NOT_FOUND'
                    WHEN ResolvedCurrencyCode IS NULL
                        THEN 'CURRENCY_NOT_FOUND'
                    WHEN ParsedAmount IS NULL OR ParsedAmount <= 0
                        THEN 'INVALID_AMOUNT'
                    WHEN ParsedOccurredAtUtc IS NULL
                        THEN 'INVALID_OCCURRED_AT'
                    WHEN LEN(AuthorizationCode) > 20
                        THEN 'AUTHORIZATION_CODE_TOO_LONG'
                    WHEN LEN(CardNetwork) > 20
                        THEN 'CARD_NETWORK_TOO_LONG'
                    WHEN LEN(MaskedPan) > 19
                        THEN 'MASKED_PAN_TOO_LONG'
                END,

            RejectionReason =
                CASE
                    WHEN ParsedExternalTransactionId IS NULL
                        THEN N'External transaction ID is missing or invalid.'
                    WHEN DuplicateRank > 1
                        THEN N'Duplicate transaction ID in the source file.'
                    WHEN ExistingTransactionId IS NOT NULL
                        THEN N'Transaction was already imported.'
                    WHEN TerminalId IS NULL
                        THEN N'Terminal code was not found or is inactive.'
                    WHEN TransactionTypeId IS NULL
                        THEN N'Transaction type code was not found.'
                    WHEN TransactionStatusId IS NULL
                        THEN N'Transaction status code was not found.'
                    WHEN PaymentMethodId IS NULL
                        THEN N'Payment method was not found or is inactive.'
                    WHEN ResolvedCurrencyCode IS NULL
                        THEN N'Currency was not found or is inactive.'
                    WHEN ParsedAmount IS NULL OR ParsedAmount <= 0
                        THEN N'Amount is invalid or is not greater than zero.'
                    WHEN ParsedOccurredAtUtc IS NULL
                        THEN N'Transaction date is invalid.'
                    WHEN LEN(AuthorizationCode) > 20
                        THEN N'Authorization code exceeds 20 characters.'
                    WHEN LEN(CardNetwork) > 20
                        THEN N'Card network exceeds 20 characters.'
                    WHEN LEN(MaskedPan) > 19
                        THEN N'Masked PAN exceeds 19 characters.'
                END
        FROM #Prepared AS prepared;

        /* Insert rejected records */

        INSERT INTO audit.RejectedTransaction
        (
            EtlExecutionId,
            StagingRowId,
            RejectionCode,
            RejectionReason
        )
        SELECT
            @EtlExecutionId,
            StagingRowId,
            RejectionCode,
            RejectionReason
        FROM #Prepared
        WHERE RejectionCode IS NOT NULL;

        SET @RowsRejected = @@ROWCOUNT;

        UPDATE raw
        SET
            ProcessingStatus = 'REJECTED',
            ProcessedAtUtc = SYSUTCDATETIME()
        FROM staging.PaymentTransactionRaw AS raw
        JOIN #Prepared AS prepared
            ON prepared.StagingRowId = raw.StagingRowId
        WHERE prepared.RejectionCode IS NOT NULL;

        /* Insert valid transactions */

        DECLARE @InsertedTransactions TABLE
        (
            TransactionId bigint NOT NULL,
            TransactionStatusId tinyint NOT NULL
        );

        INSERT INTO payment.PaymentTransaction
        (
            ExternalTransactionId,
            TerminalId,
            TransactionTypeId,
            TransactionStatusId,
            PaymentMethodId,
            CurrencyCode,
            Amount,
            OccurredAtUtc,
            AuthorizationCode,
            CardNetwork,
            MaskedPan,
            SourceFileName,
            SourceRowNumber
        )
        OUTPUT
            inserted.TransactionId,
            inserted.TransactionStatusId
        INTO @InsertedTransactions
        (
            TransactionId,
            TransactionStatusId
        )
        SELECT
            ParsedExternalTransactionId,
            TerminalId,
            TransactionTypeId,
            TransactionStatusId,
            PaymentMethodId,
            ResolvedCurrencyCode,
            ParsedAmount,
            CONVERT(
                datetime2(3),
                SWITCHOFFSET(ParsedOccurredAtUtc, '+00:00')
            ),
            CONVERT(varchar(20), AuthorizationCode),
            CONVERT(varchar(20), CardNetwork),
            CONVERT(varchar(19), MaskedPan),
            @SourceFileName,
            SourceRowNumber
        FROM #Prepared
        WHERE RejectionCode IS NULL;

        SET @RowsInserted = @@ROWCOUNT;

        INSERT INTO payment.TransactionStatusHistory
        (
            TransactionId,
            TransactionStatusId,
            ChangeReason
        )
        SELECT
            TransactionId,
            TransactionStatusId,
            N'Initial status loaded by SSIS'
        FROM @InsertedTransactions;

        UPDATE raw
        SET
            ProcessingStatus = 'IMPORTED',
            ProcessedAtUtc = SYSUTCDATETIME()
        FROM staging.PaymentTransactionRaw AS raw
        JOIN #Prepared AS prepared
            ON prepared.StagingRowId = raw.StagingRowId
        WHERE prepared.RejectionCode IS NULL;

        /* Complete the audit record */

        UPDATE audit.EtlExecution
        SET
            CompletedAtUtc = SYSUTCDATETIME(),
            ExecutionStatus = 'SUCCEEDED',
            RowsRead = @RowsRead,
            RowsInserted = @RowsInserted,
            RowsRejected = @RowsRejected,
            ErrorMessage = NULL
        WHERE EtlExecutionId = @EtlExecutionId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO