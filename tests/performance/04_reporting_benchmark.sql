USE PaymentFlow;
GO

SET NOCOUNT ON;
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

DECLARE @TestLabel varchar(50) = 'baseline';
DECLARE @MeasuredRuns tinyint = 5;

DROP TABLE IF EXISTS #Scenarios;
DROP TABLE IF EXISTS #ReportResult;

IF OBJECT_ID(N'audit.QueryPerformanceBenchmark', N'U') IS NULL
BEGIN
    CREATE TABLE audit.QueryPerformanceBenchmark
    (
        BenchmarkId bigint IDENTITY(1, 1) NOT NULL,
        TestLabel varchar(50) NOT NULL,
        ScenarioName varchar(100) NOT NULL,
        RunNumber tinyint NOT NULL,
        ResultRowCount int NOT NULL,
        DurationMs decimal(18, 3) NOT NULL,
        CapturedAtUtc datetime2(3) NOT NULL
            CONSTRAINT DF_QueryPerformanceBenchmark_CapturedAtUtc
            DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_QueryPerformanceBenchmark
            PRIMARY KEY CLUSTERED (BenchmarkId)
    );
END;

DELETE FROM audit.QueryPerformanceBenchmark
WHERE TestLabel = @TestLabel;

CREATE TABLE #Scenarios
(
    ScenarioId tinyint IDENTITY(1, 1) NOT NULL,
    ScenarioName varchar(100) NOT NULL,
    DateFrom date NOT NULL,
    DateTo date NOT NULL,
    MerchantId int NULL,
    CountryCode char(2) NULL,
    CurrencyCode char(3) NULL
);

DECLARE @MerchantId int =
(
    SELECT MerchantId
    FROM payment.Merchant
    WHERE MerchantCode = 'MER0001'
);

INSERT INTO #Scenarios
(
    ScenarioName,
    DateFrom,
    DateTo,
    MerchantId,
    CountryCode,
    CurrencyCode
)
VALUES
    ('Full year - all filters', '2025-01-01', '2025-12-31', NULL, NULL, NULL),
    ('January - all filters', '2025-01-01', '2025-01-31', NULL, NULL, NULL),
    ('Full year - one merchant', '2025-01-01', '2025-12-31', @MerchantId, NULL, NULL),
    ('Full year - Poland and PLN', '2025-01-01', '2025-12-31', NULL, 'PL', 'PLN');

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

DECLARE
    @ScenarioName varchar(100),
    @DateFrom date,
    @DateTo date,
    @ScenarioMerchantId int,
    @CountryCode char(2),
    @CurrencyCode char(3),
    @RunNumber tinyint,
    @StartedAt datetime2(7),
    @DurationMs decimal(18, 3),
    @ResultRowCount int;

DECLARE scenarioCursor CURSOR LOCAL FAST_FORWARD FOR
SELECT
    ScenarioName,
    DateFrom,
    DateTo,
    MerchantId,
    CountryCode,
    CurrencyCode
FROM #Scenarios
ORDER BY ScenarioId;

OPEN scenarioCursor;

FETCH NEXT FROM scenarioCursor INTO
    @ScenarioName,
    @DateFrom,
    @DateTo,
    @ScenarioMerchantId,
    @CountryCode,
    @CurrencyCode;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @RunNumber = 0;

    WHILE @RunNumber <= @MeasuredRuns
    BEGIN
        TRUNCATE TABLE #ReportResult;
        SET @StartedAt = SYSDATETIME();

        INSERT INTO #ReportResult
        EXEC reporting.usp_GetDailyTransactionSummary
            @DateFrom = @DateFrom,
            @DateTo = @DateTo,
            @MerchantId = @ScenarioMerchantId,
            @CountryCode = @CountryCode,
            @CurrencyCode = @CurrencyCode;

        SET @DurationMs =
            DATEDIFF_BIG(MICROSECOND, @StartedAt, SYSDATETIME())
            / 1000.0;

        SELECT @ResultRowCount = COUNT(*)
        FROM #ReportResult;

        IF @RunNumber > 0
        BEGIN
            INSERT INTO audit.QueryPerformanceBenchmark
            (
                TestLabel,
                ScenarioName,
                RunNumber,
                ResultRowCount,
                DurationMs
            )
            VALUES
            (
                @TestLabel,
                @ScenarioName,
                @RunNumber,
                @ResultRowCount,
                @DurationMs
            );
        END;

        SET @RunNumber += 1;
    END;

    FETCH NEXT FROM scenarioCursor INTO
        @ScenarioName,
        @DateFrom,
        @DateTo,
        @ScenarioMerchantId,
        @CountryCode,
        @CurrencyCode;
END;

CLOSE scenarioCursor;
DEALLOCATE scenarioCursor;

SELECT
    TestLabel,
    ScenarioName,
    MIN(DurationMs) AS MinimumDurationMs,
    CAST(AVG(DurationMs) AS decimal(18, 3)) AS AverageDurationMs,
    MAX(DurationMs) AS MaximumDurationMs,
    MIN(ResultRowCount) AS ResultRowCount,
    COUNT(*) AS MeasuredRuns
FROM audit.QueryPerformanceBenchmark
GROUP BY
    TestLabel,
    ScenarioName
ORDER BY
    ScenarioName,
    TestLabel;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;

DROP TABLE IF EXISTS #ReportResult;
DROP TABLE IF EXISTS #Scenarios;
GO
