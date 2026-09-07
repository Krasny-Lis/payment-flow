USE PaymentFlow;
GO

SET NOCOUNT ON;

DECLARE @ExpectedMinimumTransactionCount bigint = 1000000;

CREATE TABLE #ValidationResult
(
    TestName varchar(100) NOT NULL,
    ActualValue bigint NOT NULL,
    ExpectedValue varchar(100) NOT NULL,
    TestStatus varchar(10) NOT NULL
);

DECLARE @ActualTransactionCount bigint =
(
    SELECT COUNT_BIG(*)
    FROM payment.PaymentTransaction
);

INSERT INTO #ValidationResult
    (TestName, ActualValue, ExpectedValue, TestStatus)
VALUES
(
    'Minimum transaction count',
    @ActualTransactionCount,
    CONCAT('>= ', @ExpectedMinimumTransactionCount),
    CASE
        WHEN @ActualTransactionCount >= @ExpectedMinimumTransactionCount
            THEN 'PASS'
        ELSE 'FAIL'
    END
);

INSERT INTO #ValidationResult
    (TestName, ActualValue, ExpectedValue, TestStatus)
SELECT
    'Duplicate external transaction IDs',
    COUNT_BIG(*),
    '0',
    CASE WHEN COUNT_BIG(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM
(
    SELECT transactionData.ExternalTransactionId
    FROM payment.PaymentTransaction AS transactionData
    GROUP BY transactionData.ExternalTransactionId
    HAVING COUNT_BIG(*) > 1
) AS duplicateData;

INSERT INTO #ValidationResult
    (TestName, ActualValue, ExpectedValue, TestStatus)
SELECT
    'Transactions with non-positive amount',
    COUNT_BIG(*),
    '0',
    CASE WHEN COUNT_BIG(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM payment.PaymentTransaction AS transactionData
WHERE transactionData.Amount <= 0;

INSERT INTO #ValidationResult
    (TestName, ActualValue, ExpectedValue, TestStatus)
SELECT
    'Transactions without status history',
    COUNT_BIG(*),
    '0',
    CASE WHEN COUNT_BIG(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM payment.PaymentTransaction AS transactionData
WHERE NOT EXISTS
(
    SELECT 1
    FROM payment.TransactionStatusHistory AS history
    WHERE history.TransactionId = transactionData.TransactionId
);

INSERT INTO #ValidationResult
    (TestName, ActualValue, ExpectedValue, TestStatus)
SELECT
    'Successful ETL executions with inconsistent counts',
    COUNT_BIG(*),
    '0',
    CASE WHEN COUNT_BIG(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM audit.EtlExecution AS execution
WHERE execution.ExecutionStatus = 'SUCCEEDED'
  AND execution.RowsRead <>
      execution.RowsInserted + execution.RowsRejected;

INSERT INTO #ValidationResult
    (TestName, ActualValue, ExpectedValue, TestStatus)
SELECT
    'Pending rows from successful ETL executions',
    COUNT_BIG(*),
    '0',
    CASE WHEN COUNT_BIG(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM staging.PaymentTransactionRaw AS rawData
JOIN audit.EtlExecution AS execution
    ON execution.EtlExecutionId = rawData.EtlExecutionId
WHERE execution.ExecutionStatus = 'SUCCEEDED'
  AND rawData.ProcessingStatus = 'PENDING';

SELECT
    TestName,
    ActualValue,
    ExpectedValue,
    TestStatus
FROM #ValidationResult
ORDER BY
    CASE TestStatus WHEN 'FAIL' THEN 0 ELSE 1 END,
    TestName;

SELECT
    transactionData.CurrencyCode,
    COUNT_BIG(*) AS TransactionCount,
    CAST(SUM(transactionData.Amount) AS decimal(38, 2)) AS TotalAmount
FROM payment.PaymentTransaction AS transactionData
GROUP BY transactionData.CurrencyCode
ORDER BY transactionData.CurrencyCode;

SELECT
    transactionStatus.StatusCode,
    COUNT_BIG(*) AS TransactionCount
FROM payment.PaymentTransaction AS transactionData
JOIN payment.TransactionStatus AS transactionStatus
    ON transactionStatus.TransactionStatusId =
       transactionData.TransactionStatusId
GROUP BY transactionStatus.StatusCode
ORDER BY transactionStatus.StatusCode;
GO
