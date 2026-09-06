USE PaymentFlow;
GO

CREATE OR ALTER VIEW reporting.vw_DailyTransactionSummary
AS
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

    COUNT_BIG(*) AS TransactionCount,
    SUM(Amount) AS TotalAmount,
    AVG(Amount) AS AverageAmount,
    MIN(Amount) AS MinimumAmount,
    MAX(Amount) AS MaximumAmount
FROM reporting.vw_TransactionDetails
GROUP BY
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
    PaymentMethodName;
GO