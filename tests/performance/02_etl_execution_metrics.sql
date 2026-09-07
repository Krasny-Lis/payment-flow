USE PaymentFlow;
GO

SET NOCOUNT ON;

SELECT TOP (20)
    execution.EtlExecutionId,
    execution.PackageName,
    execution.SourceFileName,
    execution.ExecutionStatus,
    execution.StartedAtUtc,
    execution.CompletedAtUtc,
    execution.RowsRead,
    execution.RowsInserted,
    execution.RowsRejected,
    duration.DurationMs,
    CAST(
        CASE
            WHEN duration.DurationMs > 0
                THEN execution.RowsRead * 1000.0 / duration.DurationMs
            ELSE NULL
        END
        AS decimal(18, 2)
    ) AS RowsPerSecond,
    execution.ErrorMessage
FROM audit.EtlExecution AS execution
CROSS APPLY
(
    VALUES
    (
        DATEDIFF_BIG(
            MILLISECOND,
            execution.StartedAtUtc,
            execution.CompletedAtUtc
        )
    )
) AS duration (DurationMs)
ORDER BY execution.EtlExecutionId DESC;

SELECT TOP (20)
    execution.EtlExecutionId,
    execution.SourceFileName,
    rawData.ProcessingStatus,
    COUNT_BIG(*) AS StagingRowCount
FROM audit.EtlExecution AS execution
JOIN staging.PaymentTransactionRaw AS rawData
    ON rawData.EtlExecutionId = execution.EtlExecutionId
GROUP BY
    execution.EtlExecutionId,
    execution.SourceFileName,
    rawData.ProcessingStatus
ORDER BY
    execution.EtlExecutionId DESC,
    rawData.ProcessingStatus;

SELECT TOP (20)
    rejected.EtlExecutionId,
    execution.SourceFileName,
    rejected.RejectionCode,
    COUNT_BIG(*) AS RejectedRowCount
FROM audit.RejectedTransaction AS rejected
JOIN audit.EtlExecution AS execution
    ON execution.EtlExecutionId = rejected.EtlExecutionId
GROUP BY
    rejected.EtlExecutionId,
    execution.SourceFileName,
    rejected.RejectionCode
ORDER BY
    rejected.EtlExecutionId DESC,
    RejectedRowCount DESC;
GO
