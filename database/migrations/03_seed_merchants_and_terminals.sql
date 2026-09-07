USE PaymentFlow;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    /* Numbers from 1 to 50 */

    ;WITH MerchantNumbers AS
    (
        SELECT TOP (50)
            ROW_NUMBER() OVER
            (
                ORDER BY object_id
            ) AS MerchantNumber
        FROM sys.all_objects
    )
    INSERT INTO payment.Merchant
    (
        MerchantCode,
        MerchantName,
        CountryCode,
        MerchantCategoryCode,
        City
    )
    SELECT
        CONCAT
        (
            'MER',
            RIGHT
            (
                '0000' + CONVERT(varchar(4), MerchantNumber),
                4
            )
        ),
        CONCAT
        (
            N'Demo Merchant ',
            RIGHT
            (
                N'0000' + CONVERT(nvarchar(4), MerchantNumber),
                4
            )
        ),
        CASE MerchantNumber % 10
            WHEN 0 THEN 'CZ'
            WHEN 1 THEN 'SK'
            WHEN 2 THEN 'DE'
            ELSE 'PL'
        END,
        CASE MerchantNumber % 5
            WHEN 0 THEN '5411'
            WHEN 1 THEN '5812'
            WHEN 2 THEN '5732'
            WHEN 3 THEN '5999'
            ELSE '7011'
        END,
        CASE
            WHEN MerchantNumber % 10 = 0 THEN N'Prague'
            WHEN MerchantNumber % 10 = 1 THEN N'Bratislava'
            WHEN MerchantNumber % 10 = 2 THEN N'Berlin'
            ELSE CHOOSE
            (
                ((MerchantNumber - 1) % 7) + 1,
                N'Warsaw',
                N'Krakow',
                N'Wroclaw',
                N'Gdansk',
                N'Poznan',
                N'Lodz',
                N'Katowice'
            )
        END
    FROM MerchantNumbers AS source
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM payment.Merchant AS target
        WHERE target.MerchantCode =
            CONCAT
            (
                'MER',
                RIGHT
                (
                    '0000'
                    + CONVERT(varchar(4), source.MerchantNumber),
                    4
                )
            )
    );

    /* Three terminals for each merchant */

    INSERT INTO payment.Terminal
    (
        MerchantId,
        TerminalCode,
        TerminalType,
        InstalledAt
    )
    SELECT
        merchant.MerchantId,
        CONCAT
        (
            'T',
            RIGHT(merchant.MerchantCode, 4),
            '-',
            terminalSource.TerminalSuffix
        ),
        terminalSource.TerminalType,
        DATEADD
        (
            DAY,
            merchant.MerchantId + terminalSource.DayOffset,
            CONVERT(date, '2024-01-01')
        )
    FROM payment.Merchant AS merchant
    CROSS JOIN
    (
        VALUES
            ('POS', 'POS',         0),
            ('MOB', 'MOBILE',     10),
            ('ECO', 'ECOMMERCE', 20)
    ) AS terminalSource
        (TerminalSuffix, TerminalType, DayOffset)
    WHERE merchant.MerchantCode LIKE
        'MER[0-9][0-9][0-9][0-9]'
      AND NOT EXISTS
      (
          SELECT 1
          FROM payment.Terminal AS target
          WHERE target.TerminalCode =
              CONCAT
              (
                  'T',
                  RIGHT(merchant.MerchantCode, 4),
                  '-',
                  terminalSource.TerminalSuffix
              )
      );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

SELECT
    (SELECT COUNT(*) FROM payment.Merchant)
        AS MerchantCount,
    (SELECT COUNT(*) FROM payment.Terminal)
        AS TerminalCount;

SELECT
    TerminalType,
    COUNT(*) AS TerminalCount
FROM payment.Terminal
GROUP BY TerminalType
ORDER BY TerminalType;
GO