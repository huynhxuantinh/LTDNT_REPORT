using System.Data;
using System.Globalization;
using System.Net;
using System.Net.Mail;
using System.Security.Cryptography;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace FoodOrdering.Api.Auth;

public sealed class RegistrationService(FoodOrderingDbContext db, IConfiguration config)
{
    public async Task<ServiceResult<bool>> StartAsync(StartRegistrationRequest request, CancellationToken ct)
    {
        var email = request.Email.Trim().ToLowerInvariant();
        var name = request.FullName.Trim();
        if (name.Length < 2) return ServiceResult<bool>.Failure("Họ tên phải có ít nhất 2 ký tự.");
        if (await db.Users.AnyAsync(x => x.Email == email, ct)) return ServiceResult<bool>.Failure("Email đã được sử dụng.");
        var code = RandomNumberGenerator.GetInt32(1_000_000).ToString("D6", CultureInfo.InvariantCulture);
        var pending = await db.PendingRegistrations.SingleOrDefaultAsync(x => x.Email == email, ct);
        if (pending is null)
        {
            pending = new PendingRegistration { PendingRegistrationId = Guid.NewGuid(), Email = email, FullName = name, TokenHash = BCrypt.Net.BCrypt.HashPassword(code) };
            db.PendingRegistrations.Add(pending);
        }
        else pending.TokenHash = BCrypt.Net.BCrypt.HashPassword(code);
        pending.FullName = name;
        pending.FailedAttempts = 0;
        pending.CreatedAt = DateTime.UtcNow;
        pending.ExpiresAt = pending.CreatedAt.AddMinutes(10);
        await db.SaveChangesAsync(ct);
        try
        {
            using var smtp = new SmtpClient(config["Smtp:Host"], int.Parse(config["Smtp:Port"] ?? "2525")) { EnableSsl = true, Credentials = new NetworkCredential(config["Smtp:User"], config["Smtp:Password"]) };
            var link = EmailLinks.Create(config, "/email/register", "").Split('?')[0];
            using var mail = new MailMessage(config["Smtp:From"] ?? "noreply@foodordering.local", email) { Subject = "Xác nhận đăng ký", SubjectEncoding = System.Text.Encoding.UTF8, BodyEncoding = System.Text.Encoding.UTF8, IsBodyHtml = true, Body = EmailLinks.Html("Xác nhận đăng ký", "Nhập mã 6 số trong ứng dụng. Mã hết hạn sau 10 phút.", link, code) };
            await smtp.SendMailAsync(mail, ct);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch (Exception) { return ServiceResult<bool>.Failure("Không gửi được email. Vui lòng thử lại."); }
        return ServiceResult<bool>.Success(true);
    }

    public async Task<bool> CheckAsync(string email, string code, CancellationToken ct)
    {
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        var pending = await FindAsync(email, ct);
        var valid = await CheckCodeAsync(pending, code, ct);
        await tx.CommitAsync(ct);
        return valid;
    }

    public async Task<ServiceResult<bool>> CompleteAsync(CompleteRegistrationRequest request, CancellationToken ct)
    {
        var password = request.Password;
        if (password.Length < 8 || !password.Any(char.IsUpper) || !password.Any(char.IsLower) || !password.Any(char.IsDigit))
            return ServiceResult<bool>.Failure("Mật khẩu cần ít nhất 8 ký tự, gồm chữ hoa, chữ thường và số.");
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        var pending = await FindAsync(request.Email, ct);
        if (pending is null || !await CheckCodeAsync(pending, request.Code, ct))
        {
            await tx.CommitAsync(ct);
            return ServiceResult<bool>.Failure("Mã không hợp lệ, đã hết hạn hoặc đã vượt số lần thử.");
        }
        if (await db.Users.AnyAsync(x => x.Email == pending.Email, ct)) return ServiceResult<bool>.Failure("Email đã được sử dụng.");
        var role = await db.Roles.SingleOrDefaultAsync(x => x.RoleName == "Member", ct);
        if (role is null) return ServiceResult<bool>.Failure("Hệ thống chưa có vai trò Member.");
        db.Users.Add(new User { UserId = Guid.NewGuid(), FullName = pending.FullName, Email = pending.Email, PasswordHash = BCrypt.Net.BCrypt.HashPassword(password), RoleId = role.RoleId, IsActive = true, IsEmailVerified = true, CreatedAt = DateTime.UtcNow });
        db.PendingRegistrations.Remove(pending);
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return ServiceResult<bool>.Success(true);
    }

    private Task<PendingRegistration?> FindAsync(string email, CancellationToken ct) =>
        db.PendingRegistrations.SingleOrDefaultAsync(x => x.Email == email.Trim().ToLowerInvariant(), ct);

    private async Task<bool> CheckCodeAsync(PendingRegistration? pending, string code, CancellationToken ct)
    {
        if (pending is null || pending.ExpiresAt <= DateTime.UtcNow || pending.FailedAttempts >= 5 || code.Length != 6 || !code.All(c => c >= '0' && c <= '9') || !pending.TokenHash.StartsWith("$2", StringComparison.Ordinal)) return false;
        if (BCrypt.Net.BCrypt.Verify(code, pending.TokenHash)) return true;
        pending.FailedAttempts++;
        await db.SaveChangesAsync(ct);
        return false;
    }
}
