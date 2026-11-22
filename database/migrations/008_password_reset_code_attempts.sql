USE FoodOrderingDb;
GO
IF COL_LENGTH('dbo.PasswordResetTokens', 'FailedAttempts') IS NULL
BEGIN
    ALTER TABLE dbo.PasswordResetTokens ADD FailedAttempts int NOT NULL CONSTRAINT DF_PasswordResetTokens_FailedAttempts DEFAULT 0;
    -- Các liên kết đặt lại mật khẩu cũ không tương thích với mã sáu số.
    UPDATE dbo.PasswordResetTokens SET UsedAt = SYSUTCDATETIME() WHERE UsedAt IS NULL;
END;
GO
