USE PaymentFlow;
GO

SET NOCOUNT ON;
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

CREATE TABLE #ReportResult
(
    TransactionDate date NOT NULL,
    MerchantId int NOT NULL,
    MerchantCode varchar(20) NOT NULL,
    MerchantName nvarchar(150) NOT NULL,
    CountryCode char(2) NOT NULL,
    TerminalType varchar(20) NOT NULL,
    CurrencyCode char(3) NOT NULL,
    TransactionTypeCode varchar(20) NOT NULL,
    TransactionTypeName nvarchar(50) NOT NULL,
    TransactionStatusCode varchar(20) NOT NULL,
    TransactionStatusName nvarchar(50) NOT NULL,
    PaymentMethodCode varchar(30) NOT NULL,
    PaymentMethodName nvarchar(50) NOT NULL,
    TransactionCount bigint NOT NULL,
    TotalAmount decimal(38, 4) NULL,
    AverageAmount decimal(38, 6) NULL,
    MinimumAmount decimal(19, 4) NULL,
    MaximumAmount decimal(19, 4) NULL
);

/* Enable Include Actual Execution Plan in SSMS before running this script. */

INSERT INTO #ReportResult
EXEC reporting.usp_GetDailyTransactionSummary
    @DateFrom = '2025-01-01',
    @DateTo = '2025-12-31',
    @MerchantId = NULL,
    @CountryCode = NULL,
    @CurrencyCode = NULL;

SELECT COUNT(*) AS FullYearResultRowCount
FROM #ReportResult;

TRUNCATE TABLE #ReportResult;

DECLARE @MerchantId int =
(
    SELECT MerchantId
    FROM payment.Merchant
    WHERE MerchantCode = 'MER0001'
);

INSERT INTO #ReportResult
EXEC reporting.usp_GetDailyTransactionSummary
    @DateFrom = '2025-01-01',
    @DateTo = '2025-12-31',
    @MerchantId = @MerchantId,
    @CountryCode = NULL,
    @CurrencyCode = NULL;

SELECT COUNT(*) AS MerchantResultRowCount
FROM #ReportResult;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO
