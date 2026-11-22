USE FoodOrderingDb;
GO
IF COL_LENGTH('dbo.PendingRegistrations', 'FailedAttempts') IS NULL
BEGIN
    ALTER TABLE dbo.PendingRegistrations ADD FailedAttempts int NOT NULL CONSTRAINT DF_PendingRegistrations_FailedAttempts DEFAULT 0;
    -- Mã đăng ký cũ không tương thích với mã sáu số.
    UPDATE dbo.PendingRegistrations SET ExpiresAt = SYSUTCDATETIME();
END;
GO
