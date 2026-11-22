using System.ComponentModel.DataAnnotations;

namespace FoodOrdering.Api.Auth;

public sealed record RegisterRequest(
    [param: Required, StringLength(120, MinimumLength = 2)] string FullName,
    [param: Required, EmailAddress, StringLength(254)] string Email,
    [param: Required, StringLength(128, MinimumLength = 8)] string Password);

public sealed record LoginRequest(
    [param: Required, EmailAddress, StringLength(254)] string Email,
    [param: Required, StringLength(128, MinimumLength = 8)] string Password);

public sealed record ChangePasswordRequest(
    [param: Required, StringLength(128, MinimumLength = 8)] string CurrentPassword,
    [param: Required, StringLength(128, MinimumLength = 8)] string NewPassword);

public sealed record LogoutRequest([param: Required, StringLength(512, MinimumLength = 32)] string RefreshToken);

public sealed record RefreshTokenRequest([param: Required, StringLength(512, MinimumLength = 32)] string RefreshToken);
public sealed record VerifyEmailRequest([param: Required, StringLength(128, MinimumLength = 32)] string Token);
public sealed record ForgotPasswordRequest([param: Required, EmailAddress, StringLength(254)] string Email);
public sealed record ResetPasswordRequest([param: Required, StringLength(128, MinimumLength = 32)] string Token, [param: Required, StringLength(128, MinimumLength = 8)] string NewPassword);

public sealed record AuthResponse(Guid UserId, string FullName, string Email, string Role, string AccessToken, string RefreshToken, DateTime AccessTokenExpiresAt);

public sealed record ServiceResult<T>(bool IsSuccess, T? Value, string? Error)
{
    public static ServiceResult<T> Success(T value) => new(true, value, null);
    public static ServiceResult<T> Failure(string error) => new(false, default, error);
}
