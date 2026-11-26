USE FoodOrderingDb;
GO
IF OBJECT_ID(N'dbo.FoodItemImages', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.FoodItemImages
    (
        FoodItemImageId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_FoodItemImages PRIMARY KEY,
        FoodItemId INT NOT NULL,
        ImageUrl NVARCHAR(500) NOT NULL,
        CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_FoodItemImages_CreatedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_FoodItemImages_FoodItems FOREIGN KEY (FoodItemId)
            REFERENCES dbo.FoodItems(FoodItemId) ON DELETE CASCADE
    );
    CREATE INDEX IX_FoodItemImages_FoodItemId ON dbo.FoodItemImages(FoodItemId);
END;
GO
