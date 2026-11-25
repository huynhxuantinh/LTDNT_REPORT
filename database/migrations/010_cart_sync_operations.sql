USE FoodOrderingDb;
GO
IF OBJECT_ID(N'dbo.CartSyncOperations', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.CartSyncOperations (
        OperationId uniqueidentifier NOT NULL PRIMARY KEY,
        UserId uniqueidentifier NOT NULL,
        CreatedAt datetime2 NOT NULL,
        CONSTRAINT FK_CartSyncOperations_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(UserId) ON DELETE CASCADE
    );
END;
GO
