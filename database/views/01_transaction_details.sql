USE PaymentFlow;
GO

CREATE OR ALTER VIEW reporting.vw_TransactionDetails
AS
SELECT
    paymentTransaction.TransactionId,
    paymentTransaction.ExternalTransactionId,
    paymentTransaction.OccurredAtUtc,
    CONVERT(date, paymentTransaction.OccurredAtUtc) AS TransactionDate,
    paymentTransaction.Amount,
    paymentTransaction.CurrencyCode,

    merchant.MerchantId,
    merchant.MerchantPublicId,
    merchant.MerchantCode,
    merchant.MerchantName,
    merchant.CountryCode,
    merchant.MerchantCategoryCode,
    merchant.City,
    merchant.IsActive AS MerchantIsActive,

    terminal.TerminalId,
    terminal.TerminalCode,
    terminal.TerminalType,
    terminal.IsActive AS TerminalIsActive,

    transactionType.TransactionTypeId,
    transactionType.TypeCode AS TransactionTypeCode,
    transactionType.TypeName AS TransactionTypeName,

    transactionStatus.TransactionStatusId,
    transactionStatus.StatusCode AS TransactionStatusCode,
    transactionStatus.StatusName AS TransactionStatusName,
    transactionStatus.IsFinal AS IsFinalStatus,

    paymentMethod.PaymentMethodId,
    paymentMethod.MethodCode AS PaymentMethodCode,
    paymentMethod.MethodName AS PaymentMethodName,

    paymentTransaction.AuthorizationCode,
    paymentTransaction.CardNetwork,
    paymentTransaction.MaskedPan,
    paymentTransaction.SourceFileName,
    paymentTransaction.SourceRowNumber,
    paymentTransaction.CreatedAtUtc AS ImportedAtUtc
FROM payment.PaymentTransaction AS paymentTransaction
JOIN payment.Terminal AS terminal
    ON terminal.TerminalId = paymentTransaction.TerminalId
JOIN payment.Merchant AS merchant
    ON merchant.MerchantId = terminal.MerchantId
JOIN payment.TransactionType AS transactionType
    ON transactionType.TransactionTypeId =
       paymentTransaction.TransactionTypeId
JOIN payment.TransactionStatus AS transactionStatus
    ON transactionStatus.TransactionStatusId =
       paymentTransaction.TransactionStatusId
JOIN payment.PaymentMethod AS paymentMethod
    ON paymentMethod.PaymentMethodId =
       paymentTransaction.PaymentMethodId;
GO