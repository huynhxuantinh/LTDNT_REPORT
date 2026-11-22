USE FoodOrderingDb;
GO
IF OBJECT_ID(N'dbo.PendingRegistrations', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PendingRegistrations (
        PendingRegistrationId UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
        Email NVARCHAR(254) NOT NULL,
        FullName NVARCHAR(120) NOT NULL,
        TokenHash NVARCHAR(255) NOT NULL,
        ExpiresAt DATETIME2 NOT NULL,
        CreatedAt DATETIME2 NOT NULL,
        CONSTRAINT UQ_PendingRegistrations_Email UNIQUE (Email),
        CONSTRAINT UQ_PendingRegistrations_TokenHash UNIQUE (TokenHash)
    );
END
GO
