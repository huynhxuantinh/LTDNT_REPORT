/*
  Data migration: Staff role/account and restaurant tables for local demo.
  Safe to run repeatedly in local development.
*/

USE FoodOrderingDb;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleId = 3)
    INSERT INTO dbo.Roles(RoleId, RoleName) VALUES (3, N'Staff');
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Email = N'staff@foodordering.local')
    INSERT INTO dbo.Users(UserId, FullName, Email, PasswordHash, PhoneNumber, RoleId, IsEmailVerified)
    VALUES ('44444444-4444-4444-8444-444444444444', N'Nhân viên demo', N'staff@foodordering.local',
            N'$2b$12$S60gaQ2.qddbngNvVTHYd.NMWHAatL8R7nA.YKoTgtzuip57QykIa', N'0900000003', 3, 1);
GO

IF NOT EXISTS (SELECT 1 FROM dbo.DiningTables WHERE TableCode = N'B01')
    INSERT INTO dbo.DiningTables(TableCode, Capacity) VALUES (N'B01', 2);
IF NOT EXISTS (SELECT 1 FROM dbo.DiningTables WHERE TableCode = N'B02')
    INSERT INTO dbo.DiningTables(TableCode, Capacity) VALUES (N'B02', 2);
IF NOT EXISTS (SELECT 1 FROM dbo.DiningTables WHERE TableCode = N'B03')
    INSERT INTO dbo.DiningTables(TableCode, Capacity) VALUES (N'B03', 4);
IF NOT EXISTS (SELECT 1 FROM dbo.DiningTables WHERE TableCode = N'B04')
    INSERT INTO dbo.DiningTables(TableCode, Capacity) VALUES (N'B04', 4);
IF NOT EXISTS (SELECT 1 FROM dbo.DiningTables WHERE TableCode = N'B05')
    INSERT INTO dbo.DiningTables(TableCode, Capacity) VALUES (N'B05', 6);
GO

/* Demo credentials (local only)
   Admin:  admin@foodordering.local / Admin@123
   Staff:  staff@foodordering.local / Staff@123
   Member: member@foodordering.local / Member@123
*/
