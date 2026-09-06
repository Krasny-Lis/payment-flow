USE PaymentFlow;
GO

CREATE OR ALTER PROCEDURE audit.usp_FailEtlExecution
    @EtlExecutionId bigint,
    @ErrorMessage nvarchar(4000)
AS
BEGIN
    SET NOCOUNT ON;

    IF @EtlExecutionId IS NULL OR @EtlExecutionId <= 0
        RETURN;

    UPDATE audit.EtlExecution
    SET
        CompletedAtUtc = SYSUTCDATETIME(),
        ExecutionStatus = 'FAILED',
        ErrorMessage = LEFT(
            COALESCE(
                NULLIF(TRIM(@ErrorMessage), N''),
                N'Unknown SSIS execution error.'
            ),
            2000
        )
    WHERE EtlExecutionId = @EtlExecutionId
      AND ExecutionStatus = 'RUNNING';
END;
GO