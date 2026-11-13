using System.Security.Cryptography;
using System.Text;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using Microsoft.AspNetCore.WebUtilities;
using Microsoft.EntityFrameworkCore;

namespace FoodOrdering.Api.Auth;

public sealed class AuthService(FoodOrderingDbContext dbContext, ITokenService tokenService)
{
    private const int RefreshTokenDays = 30;

    public async Task<ServiceResult<Guid>> RegisterAsync(RegisterRequest request, CancellationToken cancellationToken)
    {
        var passwordError = ValidatePassword(request.Password);
        if (passwordError is not null)
        {
            return ServiceResult<Guid>.Failure(passwordError);
        }

        var email = NormalizeEmail(request.Email);
        if (await dbContext.Users.AnyAsync(user => user.Email == email, cancellationToken))
        {
            return ServiceResult<Guid>.Failure("Email đã được sử dụng.");
        }

        var memberRole = await dbContext.Roles.SingleOrDefaultAsync(role => role.RoleName == "Member", cancellationToken);
        if (memberRole is null)
        {
            return ServiceResult<Guid>.Failure("Chưa có role Member trong hệ thống.");
        }

        var user = new User
        {
            UserId = Guid.NewGuid(),
            FullName = request.FullName.Trim(),
            Email = email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password),
            RoleId = memberRole.RoleId,
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
        };

        dbContext.Users.Add(user);
        await dbContext.SaveChangesAsync(cancellationToken);
        return ServiceResult<Guid>.Success(user.UserId);
    }

    public async Task<ServiceResult<AuthResponse>> LoginAsync(LoginRequest request, CancellationToken cancellationToken)
    {
        var email = NormalizeEmail(request.Email);
        var user = await dbContext.Users
            .Include(item => item.Role)
            .SingleOrDefaultAsync(item => item.Email == email, cancellationToken);

        if (user is null || !user.IsActive || !BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash))
        {
            return ServiceResult<AuthResponse>.Failure("Email hoặc mật khẩu không đúng.");
        }

        var refreshToken = WebEncoders.Base64UrlEncode(RandomNumberGenerator.GetBytes(64));
        dbContext.RefreshTokens.Add(new RefreshToken
        {
            RefreshTokenId = Guid.NewGuid(),
            UserId = user.UserId,
            TokenHash = HashToken(refreshToken),
            ExpiresAt = DateTime.UtcNow.AddDays(RefreshTokenDays),
            CreatedAt = DateTime.UtcNow,
        });
        await dbContext.SaveChangesAsync(cancellationToken);

        return ServiceResult<AuthResponse>.Success(new AuthResponse(
            user.UserId,
            user.FullName,
            user.Email,
            user.Role?.RoleName ?? "Member",
            tokenService.CreateAccessToken(user),
            refreshToken,
            DateTime.UtcNow.AddMinutes(30)));
    }

    public async Task<ServiceResult<bool>> ChangePasswordAsync(Guid userId, ChangePasswordRequest request, CancellationToken cancellationToken)
    {
        var passwordError = ValidatePassword(request.NewPassword);
        if (passwordError is not null)
        {
            return ServiceResult<bool>.Failure(passwordError);
        }

        var user = await dbContext.Users.SingleOrDefaultAsync(item => item.UserId == userId, cancellationToken);
        if (user is null || !user.IsActive || !BCrypt.Net.BCrypt.Verify(request.CurrentPassword, user.PasswordHash))
        {
            return ServiceResult<bool>.Failure("Mật khẩu hiện tại không đúng.");
        }

        user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.NewPassword);
        user.UpdatedAt = DateTime.UtcNow;
        var activeRefreshTokens = await dbContext.RefreshTokens
            .Where(item => item.UserId == userId && item.RevokedAt == null)
            .ToListAsync(cancellationToken);
        foreach (var refreshToken in activeRefreshTokens)
        {
            refreshToken.RevokedAt = DateTime.UtcNow;
        }
        await dbContext.SaveChangesAsync(cancellationToken);
        return ServiceResult<bool>.Success(true);
    }

    public async Task LogoutAsync(Guid userId, LogoutRequest request, CancellationToken cancellationToken)
    {
        var tokenHash = HashToken(request.RefreshToken);
        var refreshToken = await dbContext.RefreshTokens.SingleOrDefaultAsync(
            item => item.UserId == userId && item.TokenHash == tokenHash && item.RevokedAt == null,
            cancellationToken);

        if (refreshToken is not null)
        {
            refreshToken.RevokedAt = DateTime.UtcNow;
            await dbContext.SaveChangesAsync(cancellationToken);
        }
    }

    public static string HashToken(string token) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));

    private static string NormalizeEmail(string email) => email.Trim().ToLowerInvariant();

    private static string? ValidatePassword(string password)
    {
        if (password.Length < 8 || !password.Any(char.IsUpper) || !password.Any(char.IsLower) || !password.Any(char.IsDigit))
        {
            return "Mật khẩu phải có ít nhất 8 ký tự, gồm chữ hoa, chữ thường và chữ số.";
        }

        return null;
    }
}
