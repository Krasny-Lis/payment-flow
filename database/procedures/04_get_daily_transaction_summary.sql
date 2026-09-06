USE PaymentFlow;
GO

CREATE OR ALTER PROCEDURE reporting.usp_GetDailyTransactionSummary
    @DateFrom date,
    @DateTo date,
    @MerchantId int = NULL,
    @CountryCode char(2) = NULL,
    @CurrencyCode char(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @DateFrom IS NULL OR @DateTo IS NULL
        THROW 50020, 'Date range is required.', 1;

    IF @DateFrom > @DateTo
        THROW 50021, 'DateFrom cannot be later than DateTo.', 1;

    SELECT
        TransactionDate,
        MerchantId,
        MerchantCode,
        MerchantName,
        CountryCode,
        TerminalType,
        CurrencyCode,
        TransactionTypeCode,
        TransactionTypeName,
        TransactionStatusCode,
        TransactionStatusName,
        PaymentMethodCode,
        PaymentMethodName,
        TransactionCount,
        TotalAmount,
        AverageAmount,
        MinimumAmount,
        MaximumAmount
    FROM reporting.vw_DailyTransactionSummary
    WHERE TransactionDate >= @DateFrom
      AND TransactionDate <= @DateTo
      AND (@MerchantId IS NULL OR MerchantId = @MerchantId)
      AND (@CountryCode IS NULL OR CountryCode = @CountryCode)
      AND (@CurrencyCode IS NULL OR CurrencyCode = @CurrencyCode)
    ORDER BY
        TransactionDate,
        MerchantName,
        TransactionStatusCode,
        PaymentMethodCode
    OPTION (RECOMPILE);
END;
GO