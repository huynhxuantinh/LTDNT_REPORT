USE FoodOrderingDb;
GO

IF COL_LENGTH('dbo.Users', 'SecurityStamp') IS NULL
BEGIN
    ALTER TABLE dbo.Users
        ADD SecurityStamp UNIQUEIDENTIFIER NOT NULL
            CONSTRAINT DF_Users_SecurityStamp DEFAULT NEWID() WITH VALUES;
END;
GO
