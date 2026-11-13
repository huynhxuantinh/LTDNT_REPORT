/*
  Initial schema — Food Ordering application
  SQL Server 2022+
  Run this file once for a new local database.
*/

IF DB_ID(N'FoodOrderingDb') IS NULL
BEGIN
    CREATE DATABASE FoodOrderingDb;
END
GO

USE FoodOrderingDb;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE TABLE dbo.Roles
(
    RoleId      TINYINT       NOT NULL,
    RoleName    NVARCHAR(20)  NOT NULL,
    CONSTRAINT PK_Roles PRIMARY KEY (RoleId),
    CONSTRAINT UQ_Roles_RoleName UNIQUE (RoleName)
);
GO

CREATE TABLE dbo.Users
(
    UserId          UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_Users_UserId DEFAULT NEWSEQUENTIALID(),
    FullName        NVARCHAR(120)    NOT NULL,
    Email           NVARCHAR(254)    NOT NULL,
    PasswordHash    NVARCHAR(255)    NOT NULL,
    PhoneNumber     NVARCHAR(20)     NULL,
    RoleId          TINYINT          NOT NULL,
    IsEmailVerified BIT              NOT NULL CONSTRAINT DF_Users_IsEmailVerified DEFAULT 0,
    IsActive        BIT              NOT NULL CONSTRAINT DF_Users_IsActive DEFAULT 1,
    CreatedAt       DATETIME2(0)     NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT SYSUTCDATETIME(),
    UpdatedAt       DATETIME2(0)     NULL,
    CONSTRAINT PK_Users PRIMARY KEY (UserId),
    CONSTRAINT UQ_Users_Email UNIQUE (Email),
    CONSTRAINT FK_Users_Roles FOREIGN KEY (RoleId) REFERENCES dbo.Roles(RoleId)
);
GO

CREATE TABLE dbo.RefreshTokens
(
    RefreshTokenId UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_RefreshTokens_Id DEFAULT NEWSEQUENTIALID(),
    UserId         UNIQUEIDENTIFIER NOT NULL,
    TokenHash      NVARCHAR(255)    NOT NULL,
    ExpiresAt      DATETIME2(0)     NOT NULL,
    RevokedAt      DATETIME2(0)     NULL,
    CreatedAt      DATETIME2(0)     NOT NULL CONSTRAINT DF_RefreshTokens_CreatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_RefreshTokens PRIMARY KEY (RefreshTokenId),
    CONSTRAINT UQ_RefreshTokens_TokenHash UNIQUE (TokenHash),
    CONSTRAINT FK_RefreshTokens_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(UserId) ON DELETE CASCADE
);
GO

CREATE TABLE dbo.EmailVerificationTokens
(
    EmailVerificationTokenId UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_EmailVerificationTokens_Id DEFAULT NEWSEQUENTIALID(),
    UserId                   UNIQUEIDENTIFIER NOT NULL,
    TokenHash                NVARCHAR(255)    NOT NULL,
    ExpiresAt                DATETIME2(0)     NOT NULL,
    UsedAt                   DATETIME2(0)     NULL,
    CreatedAt                DATETIME2(0)     NOT NULL CONSTRAINT DF_EmailVerificationTokens_CreatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_EmailVerificationTokens PRIMARY KEY (EmailVerificationTokenId),
    CONSTRAINT UQ_EmailVerificationTokens_TokenHash UNIQUE (TokenHash),
    CONSTRAINT FK_EmailVerificationTokens_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(UserId) ON DELETE CASCADE
);
GO

CREATE TABLE dbo.PasswordResetTokens
(
    PasswordResetTokenId UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_PasswordResetTokens_Id DEFAULT NEWSEQUENTIALID(),
    UserId               UNIQUEIDENTIFIER NOT NULL,
    TokenHash            NVARCHAR(255)    NOT NULL,
    ExpiresAt            DATETIME2(0)     NOT NULL,
    UsedAt               DATETIME2(0)     NULL,
    CreatedAt            DATETIME2(0)     NOT NULL CONSTRAINT DF_PasswordResetTokens_CreatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_PasswordResetTokens PRIMARY KEY (PasswordResetTokenId),
    CONSTRAINT UQ_PasswordResetTokens_TokenHash UNIQUE (TokenHash),
    CONSTRAINT FK_PasswordResetTokens_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(UserId) ON DELETE CASCADE
);
GO

CREATE TABLE dbo.Categories
(
    CategoryId  INT IDENTITY(1,1) NOT NULL,
    Name        NVARCHAR(100)     NOT NULL,
    Description NVARCHAR(500)     NULL,
    ImageUrl    NVARCHAR(500)     NULL,
    IsActive    BIT               NOT NULL CONSTRAINT DF_Categories_IsActive DEFAULT 1,
    CreatedAt   DATETIME2(0)      NOT NULL CONSTRAINT DF_Categories_CreatedAt DEFAULT SYSUTCDATETIME(),
    UpdatedAt   DATETIME2(0)      NULL,
    CONSTRAINT PK_Categories PRIMARY KEY (CategoryId),
    CONSTRAINT UQ_Categories_Name UNIQUE (Name)
);
GO

CREATE TABLE dbo.FoodItems
(
    FoodItemId  INT IDENTITY(1,1) NOT NULL,
    CategoryId  INT               NOT NULL,
    Name        NVARCHAR(150)     NOT NULL,
    Description NVARCHAR(MAX)     NULL,
    Price       DECIMAL(18,2)     NOT NULL,
    ImageUrl    NVARCHAR(500)     NULL,
    IsAvailable BIT               NOT NULL CONSTRAINT DF_FoodItems_IsAvailable DEFAULT 1,
    CreatedAt   DATETIME2(0)      NOT NULL CONSTRAINT DF_FoodItems_CreatedAt DEFAULT SYSUTCDATETIME(),
    UpdatedAt   DATETIME2(0)      NULL,
    CONSTRAINT PK_FoodItems PRIMARY KEY (FoodItemId),
    CONSTRAINT CK_FoodItems_Price CHECK (Price >= 0),
    CONSTRAINT UQ_FoodItems_Category_Name UNIQUE (CategoryId, Name),
    CONSTRAINT FK_FoodItems_Categories FOREIGN KEY (CategoryId) REFERENCES dbo.Categories(CategoryId)
);
GO

CREATE TABLE dbo.Carts
(
    CartId    UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_Carts_CartId DEFAULT NEWSEQUENTIALID(),
    UserId    UNIQUEIDENTIFIER NOT NULL,
    UpdatedAt DATETIME2(0)     NOT NULL CONSTRAINT DF_Carts_UpdatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_Carts PRIMARY KEY (CartId),
    CONSTRAINT UQ_Carts_UserId UNIQUE (UserId),
    CONSTRAINT FK_Carts_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(UserId) ON DELETE CASCADE
);
GO

CREATE TABLE dbo.CartItems
(
    CartItemId INT IDENTITY(1,1)  NOT NULL,
    CartId     UNIQUEIDENTIFIER  NOT NULL,
    FoodItemId INT               NOT NULL,
    Quantity   INT               NOT NULL,
    UnitPrice  DECIMAL(18,2)     NOT NULL,
    CreatedAt  DATETIME2(0)      NOT NULL CONSTRAINT DF_CartItems_CreatedAt DEFAULT SYSUTCDATETIME(),
    UpdatedAt  DATETIME2(0)      NULL,
    CONSTRAINT PK_CartItems PRIMARY KEY (CartItemId),
    CONSTRAINT UQ_CartItems_Cart_Food UNIQUE (CartId, FoodItemId),
    CONSTRAINT CK_CartItems_Quantity CHECK (Quantity > 0),
    CONSTRAINT CK_CartItems_UnitPrice CHECK (UnitPrice >= 0),
    CONSTRAINT FK_CartItems_Carts FOREIGN KEY (CartId) REFERENCES dbo.Carts(CartId) ON DELETE CASCADE,
    CONSTRAINT FK_CartItems_FoodItems FOREIGN KEY (FoodItemId) REFERENCES dbo.FoodItems(FoodItemId)
);
GO

CREATE TABLE dbo.OrderStatuses
(
    OrderStatusId TINYINT       NOT NULL,
    Name          NVARCHAR(50)  NOT NULL,
    DisplayOrder  TINYINT       NOT NULL,
    CONSTRAINT PK_OrderStatuses PRIMARY KEY (OrderStatusId),
    CONSTRAINT UQ_OrderStatuses_Name UNIQUE (Name),
    CONSTRAINT UQ_OrderStatuses_DisplayOrder UNIQUE (DisplayOrder)
);
GO

CREATE TABLE dbo.Orders
(
    OrderId          BIGINT IDENTITY(1,1) NOT NULL,
    OrderCode        VARCHAR(30)          NOT NULL,
    UserId           UNIQUEIDENTIFIER     NOT NULL,
    OrderStatusId    TINYINT              NOT NULL,
    OrderType        VARCHAR(20)          NOT NULL,
    ReceiverName     NVARCHAR(120)        NULL,
    ReceiverPhone    NVARCHAR(20)         NULL,
    DeliveryAddress  NVARCHAR(500)        NULL,
    TableNumber      NVARCHAR(20)         NULL,
    Note             NVARCHAR(1000)       NULL,
    TotalAmount      DECIMAL(18,2)        NOT NULL CONSTRAINT DF_Orders_TotalAmount DEFAULT 0,
    PaymentStatus    VARCHAR(20)          NOT NULL CONSTRAINT DF_Orders_PaymentStatus DEFAULT 'Unpaid',
    CreatedAt        DATETIME2(0)         NOT NULL CONSTRAINT DF_Orders_CreatedAt DEFAULT SYSUTCDATETIME(),
    UpdatedAt        DATETIME2(0)         NULL,
    CONSTRAINT PK_Orders PRIMARY KEY (OrderId),
    CONSTRAINT UQ_Orders_OrderCode UNIQUE (OrderCode),
    CONSTRAINT CK_Orders_OrderType CHECK (OrderType IN ('Delivery', 'DineIn', 'TakeAway')),
    CONSTRAINT CK_Orders_PaymentStatus CHECK (PaymentStatus IN ('Unpaid', 'Paid', 'Failed', 'Refunded')),
    CONSTRAINT CK_Orders_TotalAmount CHECK (TotalAmount >= 0),
    CONSTRAINT FK_Orders_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(UserId),
    CONSTRAINT FK_Orders_OrderStatuses FOREIGN KEY (OrderStatusId) REFERENCES dbo.OrderStatuses(OrderStatusId)
);
GO

CREATE TABLE dbo.OrderDetails
(
    OrderDetailId    BIGINT IDENTITY(1,1) NOT NULL,
    OrderId          BIGINT               NOT NULL,
    FoodItemId       INT                  NOT NULL,
    FoodNameSnapshot NVARCHAR(150)        NOT NULL,
    ImageUrlSnapshot NVARCHAR(500)        NULL,
    UnitPrice        DECIMAL(18,2)        NOT NULL,
    Quantity         INT                  NOT NULL,
    LineTotal        AS (CONVERT(DECIMAL(18,2), UnitPrice * Quantity)) PERSISTED,
    CONSTRAINT PK_OrderDetails PRIMARY KEY (OrderDetailId),
    CONSTRAINT CK_OrderDetails_Quantity CHECK (Quantity > 0),
    CONSTRAINT CK_OrderDetails_UnitPrice CHECK (UnitPrice >= 0),
    CONSTRAINT FK_OrderDetails_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders(OrderId) ON DELETE CASCADE,
    CONSTRAINT FK_OrderDetails_FoodItems FOREIGN KEY (FoodItemId) REFERENCES dbo.FoodItems(FoodItemId)
);
GO

CREATE TABLE dbo.Payments
(
    PaymentId       BIGINT IDENTITY(1,1) NOT NULL,
    OrderId         BIGINT               NOT NULL,
    Method          VARCHAR(20)          NOT NULL,
    Status          VARCHAR(20)          NOT NULL CONSTRAINT DF_Payments_Status DEFAULT 'Pending',
    Amount          DECIMAL(18,2)        NOT NULL,
    ProviderTxnCode NVARCHAR(100)        NULL,
    PaymentUrl      NVARCHAR(1000)       NULL,
    PaidAt          DATETIME2(0)         NULL,
    CreatedAt       DATETIME2(0)         NOT NULL CONSTRAINT DF_Payments_CreatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_Payments PRIMARY KEY (PaymentId),
    CONSTRAINT CK_Payments_Method CHECK (Method IN ('Cash', 'VietQR', 'VNPay')),
    CONSTRAINT CK_Payments_Status CHECK (Status IN ('Pending', 'Paid', 'Failed', 'Refunded')),
    CONSTRAINT CK_Payments_Amount CHECK (Amount >= 0),
    CONSTRAINT FK_Payments_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders(OrderId)
);
GO

CREATE UNIQUE INDEX UX_Payments_ProviderTxnCode
    ON dbo.Payments(ProviderTxnCode)
    WHERE ProviderTxnCode IS NOT NULL;
GO

CREATE INDEX IX_FoodItems_CategoryId_IsAvailable ON dbo.FoodItems(CategoryId, IsAvailable);
CREATE INDEX IX_CartItems_CartId ON dbo.CartItems(CartId);
CREATE INDEX IX_Orders_UserId_CreatedAt ON dbo.Orders(UserId, CreatedAt DESC);
CREATE INDEX IX_Orders_OrderStatusId_CreatedAt ON dbo.Orders(OrderStatusId, CreatedAt DESC);
CREATE INDEX IX_OrderDetails_OrderId ON dbo.OrderDetails(OrderId);
CREATE INDEX IX_OrderDetails_FoodItemId ON dbo.OrderDetails(FoodItemId);
CREATE INDEX IX_Payments_OrderId ON dbo.Payments(OrderId);
GO
