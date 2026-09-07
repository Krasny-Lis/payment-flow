USE PaymentFlow;
GO

CREATE OR ALTER PROCEDURE audit.usp_StartEtlExecution
    @PackageName nvarchar(128),
    @SourceFileName nvarchar(260)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(TRIM(@PackageName), N'') IS NULL
        THROW 50001, 'Package name is required.', 1;

    IF NULLIF(TRIM(@SourceFileName), N'') IS NULL
        THROW 50002, 'Source file name is required.', 1;

    INSERT INTO audit.EtlExecution
    (
        PackageName,
        SourceFileName
    )
    OUTPUT
        inserted.EtlExecutionId
    VALUES
    (
        @PackageName,
        @SourceFileName
    );
END;
GO

/* Test without persisting the inserted record */

BEGIN TRANSACTION;

EXEC audit.usp_StartEtlExecution
    @PackageName = N'LoadPaymentTransactions',
    @SourceFileName = N'sample_transactions.csv';

ROLLBACK TRANSACTION;
GO