/*
  Reference and demo data. Run after 001_initial_schema.sql.
  This file is idempotent: it can be run repeatedly in local development.
*/

USE FoodOrderingDb;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleId = 1)
    INSERT INTO dbo.Roles(RoleId, RoleName) VALUES (1, N'Member');
IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleId = 2)
    INSERT INTO dbo.Roles(RoleId, RoleName) VALUES (2, N'Admin');
GO

-- Local demo accounts. Change/remove these before production deployment.
IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Email = N'admin@foodordering.local')
    INSERT INTO dbo.Users(UserId, FullName, Email, PasswordHash, PhoneNumber, RoleId, IsEmailVerified)
    VALUES ('11111111-1111-4111-8111-111111111111', N'Quản trị viên', N'admin@foodordering.local',
            N'$2b$12$t/og5lldUv2gVFk8YhyMd.vFNn6hTCC4DzClqq/pUwnhwSfUnOayC', N'0900000001', 2, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Email = N'member@foodordering.local')
    INSERT INTO dbo.Users(UserId, FullName, Email, PasswordHash, PhoneNumber, RoleId, IsEmailVerified)
    VALUES ('22222222-2222-4222-8222-222222222222', N'Khách hàng demo', N'member@foodordering.local',
            N'$2b$12$T9rsJcct5M5qzsvkXFoZuuCBch4rV8aES.URNyM61oqTQSlWtzydy', N'0900000002', 1, 1);
GO

IF NOT EXISTS (SELECT 1 FROM dbo.OrderStatuses WHERE OrderStatusId = 1)
    INSERT INTO dbo.OrderStatuses(OrderStatusId, Name, DisplayOrder) VALUES (1, N'Pending', 1);
IF NOT EXISTS (SELECT 1 FROM dbo.OrderStatuses WHERE OrderStatusId = 2)
    INSERT INTO dbo.OrderStatuses(OrderStatusId, Name, DisplayOrder) VALUES (2, N'Confirmed', 2);
IF NOT EXISTS (SELECT 1 FROM dbo.OrderStatuses WHERE OrderStatusId = 3)
    INSERT INTO dbo.OrderStatuses(OrderStatusId, Name, DisplayOrder) VALUES (3, N'Preparing', 3);
IF NOT EXISTS (SELECT 1 FROM dbo.OrderStatuses WHERE OrderStatusId = 4)
    INSERT INTO dbo.OrderStatuses(OrderStatusId, Name, DisplayOrder) VALUES (4, N'Delivering', 4);
IF NOT EXISTS (SELECT 1 FROM dbo.OrderStatuses WHERE OrderStatusId = 5)
    INSERT INTO dbo.OrderStatuses(OrderStatusId, Name, DisplayOrder) VALUES (5, N'Completed', 5);
IF NOT EXISTS (SELECT 1 FROM dbo.OrderStatuses WHERE OrderStatusId = 6)
    INSERT INTO dbo.OrderStatuses(OrderStatusId, Name, DisplayOrder) VALUES (6, N'Cancelled', 6);
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Categories WHERE Name = N'Món chính')
    INSERT INTO dbo.Categories(Name, Description) VALUES (N'Món chính', N'Các món ăn no cho bữa chính.');
IF NOT EXISTS (SELECT 1 FROM dbo.Categories WHERE Name = N'Món ăn nhẹ')
    INSERT INTO dbo.Categories(Name, Description) VALUES (N'Món ăn nhẹ', N'Các món dùng kèm và ăn vặt.');
IF NOT EXISTS (SELECT 1 FROM dbo.Categories WHERE Name = N'Đồ uống')
    INSERT INTO dbo.Categories(Name, Description) VALUES (N'Đồ uống', N'Nước giải khát, trà và cà phê.');
IF NOT EXISTS (SELECT 1 FROM dbo.Categories WHERE Name = N'Tráng miệng')
    INSERT INTO dbo.Categories(Name, Description) VALUES (N'Tráng miệng', N'Các món ngọt sau bữa ăn.');
GO

INSERT INTO dbo.FoodItems(CategoryId, Name, Description, Price)
SELECT c.CategoryId, N'Cơm gà xối mỡ', N'Cơm gà giòn dùng kèm rau và nước chấm.', 55000
FROM dbo.Categories c
WHERE c.Name = N'Món chính'
  AND NOT EXISTS (SELECT 1 FROM dbo.FoodItems f WHERE f.CategoryId = c.CategoryId AND f.Name = N'Cơm gà xối mỡ');

INSERT INTO dbo.FoodItems(CategoryId, Name, Description, Price)
SELECT c.CategoryId, N'Bún bò Huế', N'Bún bò vị đậm đà.', 50000
FROM dbo.Categories c
WHERE c.Name = N'Món chính'
  AND NOT EXISTS (SELECT 1 FROM dbo.FoodItems f WHERE f.CategoryId = c.CategoryId AND f.Name = N'Bún bò Huế');

INSERT INTO dbo.FoodItems(CategoryId, Name, Description, Price)
SELECT c.CategoryId, N'Khoai tây chiên', N'Khoai tây chiên giòn.', 35000
FROM dbo.Categories c
WHERE c.Name = N'Món ăn nhẹ'
  AND NOT EXISTS (SELECT 1 FROM dbo.FoodItems f WHERE f.CategoryId = c.CategoryId AND f.Name = N'Khoai tây chiên');

INSERT INTO dbo.FoodItems(CategoryId, Name, Description, Price)
SELECT c.CategoryId, N'Trà đào cam sả', N'Trà đào thanh mát.', 35000
FROM dbo.Categories c
WHERE c.Name = N'Đồ uống'
  AND NOT EXISTS (SELECT 1 FROM dbo.FoodItems f WHERE f.CategoryId = c.CategoryId AND f.Name = N'Trà đào cam sả');

INSERT INTO dbo.FoodItems(CategoryId, Name, Description, Price)
SELECT c.CategoryId, N'Bánh flan', N'Bánh flan mềm, dùng lạnh.', 25000
FROM dbo.Categories c
WHERE c.Name = N'Tráng miệng'
  AND NOT EXISTS (SELECT 1 FROM dbo.FoodItems f WHERE f.CategoryId = c.CategoryId AND f.Name = N'Bánh flan');
GO

DECLARE @MainCategoryId INT = (SELECT CategoryId FROM dbo.Categories WHERE Name = N'Món chính');
DECLARE @SnackCategoryId INT = (SELECT CategoryId FROM dbo.Categories WHERE Name = N'Món ăn nhẹ');
DECLARE @DrinkCategoryId INT = (SELECT CategoryId FROM dbo.Categories WHERE Name = N'Đồ uống');
DECLARE @DessertCategoryId INT = (SELECT CategoryId FROM dbo.Categories WHERE Name = N'Tráng miệng');

INSERT INTO dbo.FoodItems(CategoryId, Name, Description, Price)
SELECT @MainCategoryId, N'Phở bò tái', N'Phở bò nóng hổi.', 50000
WHERE NOT EXISTS (SELECT 1 FROM dbo.FoodItems WHERE CategoryId = @MainCategoryId AND Name = N'Phở bò tái');
INSERT INTO dbo.FoodItems(CategoryId, Name, Description, Price)
SELECT @MainCategoryId, N'Cơm sườn nướng', N'Cơm sườn kèm đồ chua.', 55000
WHERE NOT EXISTS (SELECT 1 FROM dbo.FoodItems WHERE CategoryId = @MainCategoryId AND Name = N'Cơm sườn nướng');
INSERT INTO dbo.FoodItems(CategoryId, Name, Description, Price)
SELECT @MainCategoryId, N'Mì xào bò', N'Mì xào rau củ và thịt bò.', 50000
WHERE NOT EXISTS (SELECT 1 FROM dbo.FoodItems WHERE CategoryId = @MainCategoryId AND Name = N'Mì xào bò');
INSERT INTO dbo.FoodItems(CategoryId, Name, Description, Price)
SELECT @SnackCategoryId, N'Gà viên chiên', N'Gà viên chiên giòn.', 40000
WHERE NOT EXISTS (SELECT 1 FROM dbo.FoodItems WHERE CategoryId = @SnackCategoryId AND Name = N'Gà viên chiên');
INSERT INTO dbo.FoodItems(CategoryId, Name, Description, Price)
SELECT @SnackCategoryId, N'Nem chua rán', N'Nem chua rán dùng kèm tương ớt.', 35000
WHERE NOT EXISTS (SELECT 1 FROM dbo.FoodItems WHERE CategoryId = @SnackCategoryId AND Name = N'Nem chua rán');
INSERT INTO dbo.FoodItems(CategoryId, Name, Description, Price)
SELECT @DrinkCategoryId, N'Trà sữa trân châu', N'Trà sữa truyền thống.', 35000
WHERE NOT EXISTS (SELECT 1 FROM dbo.FoodItems WHERE CategoryId = @DrinkCategoryId AND Name = N'Trà sữa trân châu');
INSERT INTO dbo.FoodItems(CategoryId, Name, Description, Price)
SELECT @DrinkCategoryId, N'Cà phê sữa đá', N'Cà phê pha phin.', 30000
WHERE NOT EXISTS (SELECT 1 FROM dbo.FoodItems WHERE CategoryId = @DrinkCategoryId AND Name = N'Cà phê sữa đá');
INSERT INTO dbo.FoodItems(CategoryId, Name, Description, Price)
SELECT @DrinkCategoryId, N'Nước cam', N'Nước cam tươi.', 35000
WHERE NOT EXISTS (SELECT 1 FROM dbo.FoodItems WHERE CategoryId = @DrinkCategoryId AND Name = N'Nước cam');
INSERT INTO dbo.FoodItems(CategoryId, Name, Description, Price)
SELECT @DessertCategoryId, N'Chè khúc bạch', N'Chè khúc bạch thanh mát.', 30000
WHERE NOT EXISTS (SELECT 1 FROM dbo.FoodItems WHERE CategoryId = @DessertCategoryId AND Name = N'Chè khúc bạch');
INSERT INTO dbo.FoodItems(CategoryId, Name, Description, Price)
SELECT @DessertCategoryId, N'Bánh tiramisu', N'Bánh tiramisu vị cacao.', 35000
WHERE NOT EXISTS (SELECT 1 FROM dbo.FoodItems WHERE CategoryId = @DessertCategoryId AND Name = N'Bánh tiramisu');
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Carts WHERE UserId = '22222222-2222-4222-8222-222222222222')
    INSERT INTO dbo.Carts(CartId, UserId)
    VALUES ('33333333-3333-4333-8333-333333333333', '22222222-2222-4222-8222-222222222222');
GO

INSERT INTO dbo.CartItems(CartId, FoodItemId, Quantity, UnitPrice)
SELECT '33333333-3333-4333-8333-333333333333', FoodItemId, 1, Price
FROM dbo.FoodItems
WHERE Name = N'Cơm gà xối mỡ'
  AND NOT EXISTS (SELECT 1 FROM dbo.CartItems WHERE CartId = '33333333-3333-4333-8333-333333333333' AND FoodItemId = dbo.FoodItems.FoodItemId);
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Orders WHERE OrderCode = 'DEMO-000001')
    INSERT INTO dbo.Orders(OrderCode, UserId, OrderStatusId, OrderType, ReceiverName, ReceiverPhone, DeliveryAddress, TotalAmount, PaymentStatus)
    VALUES ('DEMO-000001', '22222222-2222-4222-8222-222222222222', 5, 'Delivery', N'Khách hàng demo', N'0900000002', N'123 Đường Demo, Quận 1, TP.HCM', 90000, 'Paid');
GO

DECLARE @DemoOrderId BIGINT = (SELECT OrderId FROM dbo.Orders WHERE OrderCode = 'DEMO-000001');

INSERT INTO dbo.OrderDetails(OrderId, FoodItemId, FoodNameSnapshot, ImageUrlSnapshot, UnitPrice, Quantity)
SELECT @DemoOrderId, FoodItemId, Name, ImageUrl, Price, 1
FROM dbo.FoodItems
WHERE Name IN (N'Cơm gà xối mỡ', N'Trà đào cam sả')
  AND NOT EXISTS (SELECT 1 FROM dbo.OrderDetails od WHERE od.OrderId = @DemoOrderId AND od.FoodItemId = dbo.FoodItems.FoodItemId);
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Payments WHERE ProviderTxnCode = N'DEMO-VIETQR-000001')
    INSERT INTO dbo.Payments(OrderId, Method, Status, Amount, ProviderTxnCode, PaidAt)
    SELECT OrderId, 'VietQR', 'Paid', TotalAmount, N'DEMO-VIETQR-000001', SYSUTCDATETIME()
    FROM dbo.Orders
    WHERE OrderCode = 'DEMO-000001';
GO

/* Demo credentials (local only)
   Admin:  admin@foodordering.local / Admin@123
   Member: member@foodordering.local / Member@123
*/
