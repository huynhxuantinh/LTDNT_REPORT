using System.Data;
using System.Net;
using System.Net.Mail;
using System.Security.Cryptography;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using Microsoft.AspNetCore.WebUtilities;
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
        var token = WebEncoders.Base64UrlEncode(RandomNumberGenerator.GetBytes(32));
        var pending = await db.PendingRegistrations.SingleOrDefaultAsync(x => x.Email == email, ct);
        if (pending is null)
        {
            pending = new PendingRegistration { PendingRegistrationId = Guid.NewGuid(), Email = email, FullName = name, TokenHash = AuthService.HashToken(token) };
            db.PendingRegistrations.Add(pending);
        }
        pending.FullName = name;
        pending.TokenHash = AuthService.HashToken(token);
        pending.CreatedAt = DateTime.UtcNow;
        pending.ExpiresAt = pending.CreatedAt.AddMinutes(30);
        await db.SaveChangesAsync(ct);
        try
        {
            using var smtp = new SmtpClient(config["Smtp:Host"], int.Parse(config["Smtp:Port"] ?? "2525")) { EnableSsl = true, Credentials = new NetworkCredential(config["Smtp:User"], config["Smtp:Password"]) };
            var link = EmailLinks.Create(config, "/email/register", token);
            using var mail = new MailMessage(config["Smtp:From"] ?? "noreply@foodordering.local", email) { Subject = "Xác nhận đăng ký", IsBodyHtml = true, Body = EmailLinks.Html("Xác nhận đăng ký", "Bấm nút để tiếp tục đặt mật khẩu hoặc nhập mã trong ứng dụng. Mã hết hạn sau 30 phút.", link, token) };
            await smtp.SendMailAsync(mail, ct);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch (Exception) { return ServiceResult<bool>.Failure("Không gửi được email. Vui lòng thử lại."); }
        return ServiceResult<bool>.Success(true);
    }

    public async Task<bool> CheckAsync(string token, CancellationToken ct) =>
        await db.PendingRegistrations.AsNoTracking().AnyAsync(x => x.TokenHash == AuthService.HashToken(token) && x.ExpiresAt > DateTime.UtcNow, ct);

    public async Task<ServiceResult<bool>> CompleteAsync(CompleteRegistrationRequest request, CancellationToken ct)
    {
        var password = request.Password;
        if (password.Length < 8 || !password.Any(char.IsUpper) || !password.Any(char.IsLower) || !password.Any(char.IsDigit))
            return ServiceResult<bool>.Failure("Mật khẩu cần ít nhất 8 ký tự, gồm chữ hoa, chữ thường và số.");
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        var hash = AuthService.HashToken(request.Token);
        var pending = await db.PendingRegistrations.SingleOrDefaultAsync(x => x.TokenHash == hash, ct);
        if (pending is null || pending.ExpiresAt <= DateTime.UtcNow) return ServiceResult<bool>.Failure("Mã không hợp lệ hoặc đã hết hạn.");
        if (await db.Users.AnyAsync(x => x.Email == pending.Email, ct)) return ServiceResult<bool>.Failure("Email đã được sử dụng.");
        var role = await db.Roles.SingleOrDefaultAsync(x => x.RoleName == "Member", ct);
        if (role is null) return ServiceResult<bool>.Failure("Hệ thống chưa có vai trò Member.");
        db.Users.Add(new User { UserId = Guid.NewGuid(), FullName = pending.FullName, Email = pending.Email, PasswordHash = BCrypt.Net.BCrypt.HashPassword(password), RoleId = role.RoleId, IsActive = true, IsEmailVerified = true, CreatedAt = DateTime.UtcNow });
        db.PendingRegistrations.Remove(pending);
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return ServiceResult<bool>.Success(true);
    }
}
