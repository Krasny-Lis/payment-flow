USE PaymentFlow;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    /* Schematy */

    IF NOT EXISTS (
        SELECT 1 FROM sys.schemas WHERE name = N'payment'
    )
        EXEC(N'CREATE SCHEMA payment AUTHORIZATION dbo;');

    IF NOT EXISTS (
        SELECT 1 FROM sys.schemas WHERE name = N'staging'
    )
        EXEC(N'CREATE SCHEMA staging AUTHORIZATION dbo;');

    IF NOT EXISTS (
        SELECT 1 FROM sys.schemas WHERE name = N'reporting'
    )
        EXEC(N'CREATE SCHEMA reporting AUTHORIZATION dbo;');

    IF NOT EXISTS (
        SELECT 1 FROM sys.schemas WHERE name = N'audit'
    )
        EXEC(N'CREATE SCHEMA audit AUTHORIZATION dbo;');

    /* Waluty */

    IF OBJECT_ID(N'payment.Currency', N'U') IS NULL
    BEGIN
        CREATE TABLE payment.Currency
        (
            CurrencyCode char(3) NOT NULL,
            CurrencyName nvarchar(50) NOT NULL,
            MinorUnit tinyint NOT NULL
                CONSTRAINT DF_Currency_MinorUnit DEFAULT (2),
            IsActive bit NOT NULL
                CONSTRAINT DF_Currency_IsActive DEFAULT (1),

            CONSTRAINT PK_Currency
                PRIMARY KEY CLUSTERED (CurrencyCode),

            CONSTRAINT CK_Currency_MinorUnit
                CHECK (MinorUnit BETWEEN 0 AND 4)
        );
    END;

    /* Statusy transakcji */

    IF OBJECT_ID(N'payment.TransactionStatus', N'U') IS NULL
    BEGIN
        CREATE TABLE payment.TransactionStatus
        (
            TransactionStatusId tinyint NOT NULL,
            StatusCode varchar(20) NOT NULL,
            StatusName nvarchar(50) NOT NULL,
            IsFinal bit NOT NULL,

            CONSTRAINT PK_TransactionStatus
                PRIMARY KEY CLUSTERED (TransactionStatusId),

            CONSTRAINT UQ_TransactionStatus_StatusCode
                UNIQUE (StatusCode)
        );
    END;

    /* Metody płatności */

    IF OBJECT_ID(N'payment.PaymentMethod', N'U') IS NULL
    BEGIN
        CREATE TABLE payment.PaymentMethod
        (
            PaymentMethodId tinyint NOT NULL,
            MethodCode varchar(30) NOT NULL,
            MethodName nvarchar(50) NOT NULL,
            IsActive bit NOT NULL
                CONSTRAINT DF_PaymentMethod_IsActive DEFAULT (1),

            CONSTRAINT PK_PaymentMethod
                PRIMARY KEY CLUSTERED (PaymentMethodId),

            CONSTRAINT UQ_PaymentMethod_MethodCode
                UNIQUE (MethodCode)
        );
    END;

    /* Typy operacji */

    IF OBJECT_ID(N'payment.TransactionType', N'U') IS NULL
    BEGIN
        CREATE TABLE payment.TransactionType
        (
            TransactionTypeId tinyint NOT NULL,
            TypeCode varchar(20) NOT NULL,
            TypeName nvarchar(50) NOT NULL,

            CONSTRAINT PK_TransactionType
                PRIMARY KEY CLUSTERED (TransactionTypeId),

            CONSTRAINT UQ_TransactionType_TypeCode
                UNIQUE (TypeCode)
        );
    END;

    /* Dane słownikowe */

    INSERT INTO payment.Currency
        (CurrencyCode, CurrencyName, MinorUnit, IsActive)
    SELECT
        source.CurrencyCode,
        source.CurrencyName,
        source.MinorUnit,
        1
    FROM
    (
        VALUES
            ('PLN', N'Polish zloty', 2),
            ('EUR', N'Euro', 2),
            ('USD', N'US dollar', 2),
            ('GBP', N'Pound sterling', 2),
            ('CZK', N'Czech koruna', 2)
    ) AS source (CurrencyCode, CurrencyName, MinorUnit)
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM payment.Currency AS target
        WHERE target.CurrencyCode = source.CurrencyCode
    );

    INSERT INTO payment.TransactionStatus
        (TransactionStatusId, StatusCode, StatusName, IsFinal)
    SELECT
        source.TransactionStatusId,
        source.StatusCode,
        source.StatusName,
        source.IsFinal
    FROM
    (
        VALUES
            (1, 'PENDING',    N'Pending',    0),
            (2, 'AUTHORIZED', N'Authorized', 0),
            (3, 'SETTLED',    N'Settled',    1),
            (4, 'DECLINED',   N'Declined',   1),
            (5, 'REFUNDED',   N'Refunded',   1),
            (6, 'REVERSED',   N'Reversed',   1)
    ) AS source
        (TransactionStatusId, StatusCode, StatusName, IsFinal)
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM payment.TransactionStatus AS target
        WHERE target.TransactionStatusId =
              source.TransactionStatusId
    );

    INSERT INTO payment.PaymentMethod
        (PaymentMethodId, MethodCode, MethodName, IsActive)
    SELECT
        source.PaymentMethodId,
        source.MethodCode,
        source.MethodName,
        1
    FROM
    (
        VALUES
            (1, 'CARD',           N'Payment card'),
            (2, 'BLIK',           N'BLIK'),
            (3, 'DIGITAL_WALLET', N'Digital wallet'),
            (4, 'BANK_TRANSFER',  N'Bank transfer')
    ) AS source
        (PaymentMethodId, MethodCode, MethodName)
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM payment.PaymentMethod AS target
        WHERE target.PaymentMethodId =
              source.PaymentMethodId
    );

    INSERT INTO payment.TransactionType
        (TransactionTypeId, TypeCode, TypeName)
    SELECT
        source.TransactionTypeId,
        source.TypeCode,
        source.TypeName
    FROM
    (
        VALUES
            (1, 'PURCHASE', N'Purchase'),
            (2, 'REFUND',   N'Refund'),
            (3, 'REVERSAL', N'Reversal')
    ) AS source
        (TransactionTypeId, TypeCode, TypeName)
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM payment.TransactionType AS target
        WHERE target.TransactionTypeId =
              source.TransactionTypeId
    );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

/* Kontrola wyniku */

SELECT name AS SchemaName
FROM sys.schemas
WHERE name IN (N'payment', N'staging', N'reporting', N'audit')
ORDER BY name;

SELECT 'Currency' AS TableName, COUNT(*) AS [RowCount]
FROM payment.Currency

UNION ALL

SELECT 'TransactionStatus', COUNT(*)
FROM payment.TransactionStatus

UNION ALL

SELECT 'PaymentMethod', COUNT(*)
FROM payment.PaymentMethod

UNION ALL

SELECT 'TransactionType', COUNT(*)
FROM payment.TransactionType;
GO