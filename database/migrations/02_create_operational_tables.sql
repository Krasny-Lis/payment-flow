USE PaymentFlow;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    /* Akceptanci płatności */

    IF OBJECT_ID(N'payment.Merchant', N'U') IS NULL
    BEGIN
        CREATE TABLE payment.Merchant
        (
            MerchantId int IDENTITY(1, 1) NOT NULL,
            MerchantPublicId uniqueidentifier NOT NULL
                CONSTRAINT DF_Merchant_PublicId
                DEFAULT (NEWSEQUENTIALID()),

            MerchantCode varchar(20) NOT NULL,
            MerchantName nvarchar(150) NOT NULL,
            CountryCode char(2) NOT NULL,
            MerchantCategoryCode char(4) NOT NULL,
            City nvarchar(100) NOT NULL,
            IsActive bit NOT NULL
                CONSTRAINT DF_Merchant_IsActive DEFAULT (1),

            CreatedAtUtc datetime2(3) NOT NULL
                CONSTRAINT DF_Merchant_CreatedAtUtc
                DEFAULT (SYSUTCDATETIME()),

            CONSTRAINT PK_Merchant
                PRIMARY KEY CLUSTERED (MerchantId),

            CONSTRAINT UQ_Merchant_PublicId
                UNIQUE (MerchantPublicId),

            CONSTRAINT UQ_Merchant_Code
                UNIQUE (MerchantCode),

            CONSTRAINT CK_Merchant_CountryCode
                CHECK (LEN(CountryCode) = 2),

            CONSTRAINT CK_Merchant_CategoryCode
                CHECK
                (
                    LEN(MerchantCategoryCode) = 4
                    AND MerchantCategoryCode NOT LIKE '%[^0-9]%'
                )
        );
    END;

    /* Terminale POS, mobilne i internetowe */

    IF OBJECT_ID(N'payment.Terminal', N'U') IS NULL
    BEGIN
        CREATE TABLE payment.Terminal
        (
            TerminalId int IDENTITY(1, 1) NOT NULL,
            MerchantId int NOT NULL,
            TerminalCode varchar(20) NOT NULL,
            TerminalType varchar(20) NOT NULL,
            InstalledAt date NULL,

            IsActive bit NOT NULL
                CONSTRAINT DF_Terminal_IsActive DEFAULT (1),

            CreatedAtUtc datetime2(3) NOT NULL
                CONSTRAINT DF_Terminal_CreatedAtUtc
                DEFAULT (SYSUTCDATETIME()),

            CONSTRAINT PK_Terminal
                PRIMARY KEY CLUSTERED (TerminalId),

            CONSTRAINT UQ_Terminal_Code
                UNIQUE (TerminalCode),

            CONSTRAINT FK_Terminal_Merchant
                FOREIGN KEY (MerchantId)
                REFERENCES payment.Merchant (MerchantId),

            CONSTRAINT CK_Terminal_Type
                CHECK
                (
                    TerminalType IN
                    (
                        'POS',
                        'MOBILE',
                        'ECOMMERCE'
                    )
                )
        );
    END;

    /* Główna tabela transakcji */

    IF OBJECT_ID(N'payment.PaymentTransaction', N'U') IS NULL
    BEGIN
        CREATE TABLE payment.PaymentTransaction
        (
            TransactionId bigint IDENTITY(1, 1) NOT NULL,

            ExternalTransactionId uniqueidentifier NOT NULL
                CONSTRAINT DF_PaymentTransaction_ExternalId
                DEFAULT (NEWSEQUENTIALID()),

            TerminalId int NOT NULL,
            TransactionTypeId tinyint NOT NULL,
            TransactionStatusId tinyint NOT NULL,
            PaymentMethodId tinyint NOT NULL,
            CurrencyCode char(3) NOT NULL,

            Amount decimal(19, 4) NOT NULL,
            OccurredAtUtc datetime2(3) NOT NULL,

            AuthorizationCode varchar(20) NULL,
            CardNetwork varchar(20) NULL,
            MaskedPan varchar(19) NULL,

            SourceFileName nvarchar(260) NULL,
            SourceRowNumber int NULL,

            CreatedAtUtc datetime2(3) NOT NULL
                CONSTRAINT DF_PaymentTransaction_CreatedAtUtc
                DEFAULT (SYSUTCDATETIME()),

            CONSTRAINT PK_PaymentTransaction
                PRIMARY KEY CLUSTERED (TransactionId),

            CONSTRAINT UQ_PaymentTransaction_ExternalId
                UNIQUE (ExternalTransactionId),

            CONSTRAINT FK_PaymentTransaction_Terminal
                FOREIGN KEY (TerminalId)
                REFERENCES payment.Terminal (TerminalId),

            CONSTRAINT FK_PaymentTransaction_Type
                FOREIGN KEY (TransactionTypeId)
                REFERENCES payment.TransactionType (TransactionTypeId),

            CONSTRAINT FK_PaymentTransaction_Status
                FOREIGN KEY (TransactionStatusId)
                REFERENCES payment.TransactionStatus (TransactionStatusId),

            CONSTRAINT FK_PaymentTransaction_Method
                FOREIGN KEY (PaymentMethodId)
                REFERENCES payment.PaymentMethod (PaymentMethodId),

            CONSTRAINT FK_PaymentTransaction_Currency
                FOREIGN KEY (CurrencyCode)
                REFERENCES payment.Currency (CurrencyCode),

            CONSTRAINT CK_PaymentTransaction_Amount
                CHECK (Amount > 0),

            CONSTRAINT CK_PaymentTransaction_SourceRow
                CHECK
                (
                    SourceRowNumber IS NULL
                    OR SourceRowNumber > 0
                )
        );
    END;

    /* Historia zmian statusów */

    IF OBJECT_ID(N'payment.TransactionStatusHistory', N'U') IS NULL
    BEGIN
        CREATE TABLE payment.TransactionStatusHistory
        (
            TransactionStatusHistoryId bigint IDENTITY(1, 1) NOT NULL,
            TransactionId bigint NOT NULL,
            TransactionStatusId tinyint NOT NULL,

            ChangedAtUtc datetime2(3) NOT NULL
                CONSTRAINT DF_StatusHistory_ChangedAtUtc
                DEFAULT (SYSUTCDATETIME()),

            ChangeReason nvarchar(200) NULL,
            SourceName varchar(30) NOT NULL
                CONSTRAINT DF_StatusHistory_SourceName
                DEFAULT ('PaymentFlow'),

            CONSTRAINT PK_TransactionStatusHistory
                PRIMARY KEY CLUSTERED
                (TransactionStatusHistoryId),

            CONSTRAINT FK_StatusHistory_Transaction
                FOREIGN KEY (TransactionId)
                REFERENCES payment.PaymentTransaction
                    (TransactionId),

            CONSTRAINT FK_StatusHistory_Status
                FOREIGN KEY (TransactionStatusId)
                REFERENCES payment.TransactionStatus
                    (TransactionStatusId)
        );
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

SELECT
    schemaObject.name AS SchemaName,
    tableObject.name AS TableName
FROM sys.tables AS tableObject
INNER JOIN sys.schemas AS schemaObject
    ON schemaObject.schema_id = tableObject.schema_id
WHERE schemaObject.name = N'payment'
ORDER BY tableObject.name;
GO