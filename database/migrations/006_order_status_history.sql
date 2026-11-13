USE FoodOrderingDb;
GO
CREATE TABLE dbo.OrderStatusHistories (OrderStatusHistoryId BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY, OrderId BIGINT NOT NULL, OrderStatusId TINYINT NOT NULL, UpdatedByUserId UNIQUEIDENTIFIER NOT NULL, CreatedAt DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(), CONSTRAINT FK_OrderStatusHistories_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders(OrderId), CONSTRAINT FK_OrderStatusHistories_OrderStatuses FOREIGN KEY (OrderStatusId) REFERENCES dbo.OrderStatuses(OrderStatusId), CONSTRAINT FK_OrderStatusHistories_Users FOREIGN KEY (UpdatedByUserId) REFERENCES dbo.Users(UserId));
GO
