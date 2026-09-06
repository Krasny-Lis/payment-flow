USE master;
GO

IF DB_ID(N'PaymentFlow') IS NULL
BEGIN
    CREATE DATABASE PaymentFlow;
END;
GO

ALTER DATABASE PaymentFlow SET COMPATIBILITY_LEVEL = 160;
ALTER DATABASE PaymentFlow SET RECOVERY SIMPLE;
ALTER DATABASE PaymentFlow SET AUTO_CLOSE OFF;
ALTER DATABASE PaymentFlow SET AUTO_SHRINK OFF;
ALTER DATABASE PaymentFlow SET PAGE_VERIFY CHECKSUM;
GO

ALTER DATABASE PaymentFlow SET QUERY_STORE = ON;
GO

ALTER DATABASE PaymentFlow SET QUERY_STORE
(
    OPERATION_MODE = READ_WRITE,
    QUERY_CAPTURE_MODE = AUTO,
    MAX_STORAGE_SIZE_MB = 256,
    INTERVAL_LENGTH_MINUTES = 15,
    CLEANUP_POLICY =
    (
        STALE_QUERY_THRESHOLD_DAYS = 30
    )
);
GO

USE PaymentFlow;
GO

SELECT
    name AS DatabaseName,
    state_desc AS State,
    recovery_model_desc AS RecoveryModel,
    compatibility_level AS CompatibilityLevel,
    is_query_store_on AS QueryStoreEnabled
FROM sys.databases
WHERE name = DB_NAME();

SELECT
    name AS LogicalFileName,
    type_desc AS FileType,
    physical_name AS PhysicalPath
FROM sys.database_files;
GO