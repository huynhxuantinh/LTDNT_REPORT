using System.Net;
using System.Net.Mail;
using System.Security.Cryptography;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using Microsoft.AspNetCore.WebUtilities;
using Microsoft.EntityFrameworkCore;

namespace FoodOrdering.Api.Auth;

public sealed class EmailVerificationService(FoodOrderingDbContext db, IConfiguration configuration)
{
    public async Task SendAsync(Guid userId, CancellationToken ct)
    {
        var user = await db.Users.SingleAsync(x => x.UserId == userId, ct);
        var token = WebEncoders.Base64UrlEncode(RandomNumberGenerator.GetBytes(32));
        db.EmailVerificationTokens.Add(new EmailVerificationToken { EmailVerificationTokenId = Guid.NewGuid(), UserId = userId, TokenHash = AuthService.HashToken(token), CreatedAt = DateTime.UtcNow, ExpiresAt = DateTime.UtcNow.AddHours(24) });
        await db.SaveChangesAsync(ct);
        using var client = new SmtpClient(configuration["Smtp:Host"], int.Parse(configuration["Smtp:Port"] ?? "2525")) { EnableSsl = true, Credentials = new NetworkCredential(configuration["Smtp:User"], configuration["Smtp:Password"]) };
        var link = EmailLinks.Create(configuration, "/email/verify", token);
        using var message = new MailMessage(configuration["Smtp:From"] ?? "noreply@foodordering.local", user.Email) { Subject = "Xác thực tài khoản", IsBodyHtml = true, Body = EmailLinks.Html("Xác thực email", "Bấm nút để xác thực tài khoản. Liên kết hết hạn sau 24 giờ.", link, token) };
        await client.SendMailAsync(message, ct);
    }

    public async Task<bool> VerifyAsync(string token, CancellationToken ct)
    {
        var hash = AuthService.HashToken(token);
        var record = await db.EmailVerificationTokens.Include(x => x.User).SingleOrDefaultAsync(x => x.TokenHash == hash, ct);
        if (record?.User is null || record.UsedAt != null || record.ExpiresAt <= DateTime.UtcNow) return false;
        record.UsedAt = DateTime.UtcNow;
        record.User.IsEmailVerified = true;
        await db.SaveChangesAsync(ct);
        return true;
    }
}
