using System.Data;
using System.Globalization;
using System.Net;
using System.Net.Mail;
using System.Security.Cryptography;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace FoodOrdering.Api.Auth;

public sealed class PasswordResetService(FoodOrderingDbContext db, IConfiguration config, ILogger<PasswordResetService> logger)
{
    private const int MaxAttempts = 5;

    public async Task RequestAsync(string email, CancellationToken ct)
    {
        var user = await db.Users.SingleOrDefaultAsync(x => x.Email == email.Trim().ToLowerInvariant() && x.IsActive, ct);
        if (user is null) return;
        var now = DateTime.UtcNow;
        var previous = await db.PasswordResetTokens.Where(x => x.UserId == user.UserId && x.UsedAt == null).ToListAsync(ct);
        foreach (var item in previous) item.UsedAt = now;
        var code = RandomNumberGenerator.GetInt32(1_000_000).ToString("D6", CultureInfo.InvariantCulture);
        db.PasswordResetTokens.Add(new PasswordResetToken { PasswordResetTokenId = Guid.NewGuid(), UserId = user.UserId, TokenHash = BCrypt.Net.BCrypt.HashPassword(code), CreatedAt = now, ExpiresAt = now.AddMinutes(10) });
        await db.SaveChangesAsync(ct);
        try
        {
            using var client = new SmtpClient(config["Smtp:Host"], int.Parse(config["Smtp:Port"] ?? "2525")) { EnableSsl = true, Credentials = new NetworkCredential(config["Smtp:User"], config["Smtp:Password"]) };
            var link = EmailLinks.Create(config, "/email/reset-password", "").Split('?')[0];
            using var message = new MailMessage(config["Smtp:From"] ?? "noreply@foodordering.local", user.Email) { Subject = "Mã đặt lại mật khẩu", IsBodyHtml = true, Body = EmailLinks.Html("Đặt lại mật khẩu", "Nhập mã 6 số trong ứng dụng. Mã hết hạn sau 10 phút.", link, code) };
            await client.SendMailAsync(message, ct);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch (Exception ex) { logger.LogWarning(ex, "Unable to send password reset email"); }
    }

    public async Task<bool> CheckCodeAsync(string email, string code, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        var record = await FindAsync(email, ct);
        var valid = await CheckAsync(record, code, ct);
        await transaction.CommitAsync(ct);
        return valid;
    }

    public async Task<bool> ResetAsync(string email, string code, string password, CancellationToken ct)
    {
        if (password.Length is < 8 or > 128 || !password.Any(char.IsUpper) || !password.Any(char.IsLower) || !password.Any(char.IsDigit)) return false;
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        var record = await FindAsync(email, ct);
        if (!await CheckAsync(record, code, ct)) { await transaction.CommitAsync(ct); return false; }
        var now = DateTime.UtcNow;
        record!.User!.PasswordHash = BCrypt.Net.BCrypt.HashPassword(password);
        record.User.UpdatedAt = now;
        var tokens = await db.PasswordResetTokens.Where(x => x.UserId == record.UserId && x.UsedAt == null).ToListAsync(ct);
        foreach (var item in tokens) item.UsedAt = now;
        var sessions = await db.RefreshTokens.Where(x => x.UserId == record.UserId && x.RevokedAt == null).ToListAsync(ct);
        foreach (var session in sessions) session.RevokedAt = now;
        await db.SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);
        return true;
    }

    private Task<PasswordResetToken?> FindAsync(string email, CancellationToken ct) =>
        db.PasswordResetTokens.Include(x => x.User)
            .Where(x => x.User != null && x.User.Email == email.Trim().ToLowerInvariant() && x.User.IsActive && x.UsedAt == null)
            .OrderByDescending(x => x.CreatedAt).FirstOrDefaultAsync(ct);

    private async Task<bool> CheckAsync(PasswordResetToken? record, string code, CancellationToken ct)
    {
        if (record is null || record.ExpiresAt <= DateTime.UtcNow || record.FailedAttempts >= MaxAttempts || code.Length != 6 || !code.All(c => c >= '0' && c <= '9')) return false;
        // Legacy links use SHA-256 instead of BCrypt and cannot be used as codes.
        if (!record.TokenHash.StartsWith("$2", StringComparison.Ordinal)) return false;
        if (BCrypt.Net.BCrypt.Verify(code, record.TokenHash)) return true;
        record.FailedAttempts++;
        await db.SaveChangesAsync(ct);
        return false;
    }
}
