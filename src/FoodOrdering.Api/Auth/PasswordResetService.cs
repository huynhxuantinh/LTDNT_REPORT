using System.Data;
using System.Net;
using System.Net.Mail;
using System.Security.Cryptography;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using Microsoft.AspNetCore.WebUtilities;
using Microsoft.EntityFrameworkCore;

namespace FoodOrdering.Api.Auth;

public sealed class PasswordResetService(FoodOrderingDbContext db, IConfiguration config, ILogger<PasswordResetService> logger)
{
    public async Task RequestAsync(string email, CancellationToken ct)
    {
        var user = await db.Users.SingleOrDefaultAsync(x => x.Email == email.Trim().ToLowerInvariant() && x.IsActive, ct);
        if (user is null) return;
        var now = DateTime.UtcNow;
        var previous = await db.PasswordResetTokens.Where(x => x.UserId == user.UserId && x.UsedAt == null).ToListAsync(ct);
        foreach (var item in previous) item.UsedAt = now;
        var token = WebEncoders.Base64UrlEncode(RandomNumberGenerator.GetBytes(32));
        db.PasswordResetTokens.Add(new PasswordResetToken { PasswordResetTokenId = Guid.NewGuid(), UserId = user.UserId, TokenHash = AuthService.HashToken(token), CreatedAt = now, ExpiresAt = now.AddMinutes(30) });
        await db.SaveChangesAsync(ct);
        try
        {
            using var client = new SmtpClient(config["Smtp:Host"], int.Parse(config["Smtp:Port"] ?? "2525")) { EnableSsl = true, Credentials = new NetworkCredential(config["Smtp:User"], config["Smtp:Password"]) };
            using var message = new MailMessage(config["Smtp:From"] ?? "noreply@foodordering.local", user.Email) { Subject = "Dat lai mat khau", Body = $"Ma dat lai mat khau (het han sau 30 phut): {token}" };
            await client.SendMailAsync(message, ct);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch (Exception ex) { logger.LogWarning(ex, "Unable to send password reset email"); }
    }

    public async Task<bool> ResetAsync(string token, string password, CancellationToken ct)
    {
        if (password.Length < 8 || !password.Any(char.IsUpper) || !password.Any(char.IsLower) || !password.Any(char.IsDigit)) return false;
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        var hash = AuthService.HashToken(token);
        var record = await db.PasswordResetTokens.Include(x => x.User).SingleOrDefaultAsync(x => x.TokenHash == hash, ct);
        if (record?.User is null || !record.User.IsActive || record.UsedAt != null || record.ExpiresAt <= DateTime.UtcNow) return false;
        var now = DateTime.UtcNow;
        record.User.PasswordHash = BCrypt.Net.BCrypt.HashPassword(password);
        record.User.UpdatedAt = now;
        var tokens = await db.PasswordResetTokens.Where(x => x.UserId == record.UserId && x.UsedAt == null).ToListAsync(ct);
        foreach (var item in tokens) item.UsedAt = now;
        var sessions = await db.RefreshTokens.Where(x => x.UserId == record.UserId && x.RevokedAt == null).ToListAsync(ct);
        foreach (var session in sessions) session.RevokedAt = now;
        await db.SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);
        return true;
    }
}
