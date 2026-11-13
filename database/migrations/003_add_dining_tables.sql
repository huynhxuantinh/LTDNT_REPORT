/*
  Schema migration: add restaurant tables and link DineIn orders to a table.
  Safe to run once against FoodOrderingDb after 001 and 002.
*/

USE FoodOrderingDb;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'dbo.DiningTables', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DiningTables
    (
        TableId   INT IDENTITY(1,1) NOT NULL,
        TableCode NVARCHAR(20)      NOT NULL,
        Capacity  TINYINT           NOT NULL,
        Status    VARCHAR(20)       NOT NULL CONSTRAINT DF_DiningTables_Status DEFAULT 'Available',
        CreatedAt DATETIME2(0)      NOT NULL CONSTRAINT DF_DiningTables_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt DATETIME2(0)      NULL,
        CONSTRAINT PK_DiningTables PRIMARY KEY (TableId),
        CONSTRAINT UQ_DiningTables_TableCode UNIQUE (TableCode),
        CONSTRAINT CK_DiningTables_Capacity CHECK (Capacity > 0),
        CONSTRAINT CK_DiningTables_Status CHECK (Status IN ('Available', 'Occupied'))
    );
END
GO

IF COL_LENGTH(N'dbo.Orders', N'TableId') IS NULL
BEGIN
    ALTER TABLE dbo.Orders ADD TableId INT NULL;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Orders_DiningTables')
BEGIN
    ALTER TABLE dbo.Orders
        ADD CONSTRAINT FK_Orders_DiningTables
        FOREIGN KEY (TableId) REFERENCES dbo.DiningTables(TableId);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Orders') AND name = N'IX_Orders_TableId')
BEGIN
    CREATE INDEX IX_Orders_TableId ON dbo.Orders(TableId) WHERE TableId IS NOT NULL;
END
GO
