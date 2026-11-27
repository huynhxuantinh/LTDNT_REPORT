using System.Security.Claims;
using FoodOrdering.Api.Auth;
using FoodOrdering.Api.Common;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace FoodOrdering.Api.Controllers;

[ApiController]
[Route("api/auth")]
public sealed class AuthController(AuthService authService, EmailVerificationService verificationService, PasswordResetService resetService, RegistrationService registrationService, IWebHostEnvironment environment) : ControllerBase
{
    [HttpPost("register/start")]
    [EnableRateLimiting("auth-sensitive")]
    public async Task<IActionResult> StartRegistration(StartRegistrationRequest request, CancellationToken ct)
    {
        var result = await registrationService.StartAsync(request, ct);
        return result.IsSuccess ? Ok(new { message = "Đã gửi mã xác nhận." }) : BadRequest(ApiErrorResponse.Create("registration_failed", result.Error!));
    }

    [HttpPost("register/check-code")]
    [EnableRateLimiting("auth-sensitive")]
    public async Task<IActionResult> CheckRegistrationCode(CheckResetCodeRequest request, CancellationToken ct) =>
        await registrationService.CheckAsync(request.Email, request.Code, ct) ? Ok(new { message = "Mã hợp lệ." }) : BadRequest(ApiErrorResponse.Create("invalid_code", "Mã không hợp lệ, đã hết hạn hoặc đã vượt số lần thử."));

    [HttpPost("register/complete")]
    [EnableRateLimiting("auth-sensitive")]
    public async Task<IActionResult> CompleteRegistration(CompleteRegistrationRequest request, CancellationToken ct)
    {
        var result = await registrationService.CompleteAsync(request, ct);
        return result.IsSuccess ? StatusCode(201, new { message = "Đăng ký thành công." }) : BadRequest(ApiErrorResponse.Create("registration_failed", result.Error!));
    }
    [HttpPost("forgot-password")]
    [EnableRateLimiting("auth-sensitive")]
    public async Task<IActionResult> ForgotPassword(ForgotPasswordRequest request, CancellationToken ct)
    {
        await resetService.RequestAsync(request.Email, ct);
        return Ok(new { message = "Nếu tài khoản tồn tại, email hướng dẫn đã được gửi." });
    }

    [HttpPost("reset-password")]
    [EnableRateLimiting("auth-sensitive")]
    public async Task<IActionResult> ResetPassword(ResetPasswordRequest request, CancellationToken ct) =>
        await resetService.ResetAsync(request.Email, request.Code, request.NewPassword, ct) ? NoContent() : BadRequest(ApiErrorResponse.Create("reset_failed", "Mã không hợp lệ, đã hết hạn hoặc mật khẩu không đúng quy định."));

    [HttpPost("forgot-password/check-code")]
    [EnableRateLimiting("auth-sensitive")]
    public async Task<IActionResult> CheckResetCode(CheckResetCodeRequest request, CancellationToken ct) =>
        await resetService.CheckCodeAsync(request.Email, request.Code, ct) ? Ok(new { message = "Mã hợp lệ." }) : BadRequest(ApiErrorResponse.Create("invalid_code", "Mã không hợp lệ, đã hết hạn hoặc đã vượt số lần thử."));
    [HttpPost("register")]
    [EnableRateLimiting("auth-sensitive")]
    public async Task<IActionResult> Register(RegisterRequest request, CancellationToken cancellationToken)
    {
        await Task.CompletedTask;
        return StatusCode(StatusCodes.Status410Gone, ApiErrorResponse.Create("registration_changed", "Vui lòng cập nhật ứng dụng để xác nhận email trước khi đăng ký."));
    }

    [HttpPost("verify-email")]
    [EnableRateLimiting("auth-sensitive")]
    public async Task<IActionResult> VerifyEmail(VerifyEmailRequest request, CancellationToken cancellationToken) =>
        await verificationService.VerifyAsync(request.Token, cancellationToken) ? Ok(new { message = "Xác thực email thành công." }) : BadRequest(ApiErrorResponse.Create("invalid_token", "Mã xác thực không hợp lệ hoặc đã hết hạn."));

    [HttpPost("login")]
    [EnableRateLimiting("auth-login")]
    public async Task<IActionResult> Login(LoginRequest request, CancellationToken cancellationToken)
    {
        var identifier = request.Email.Trim();
        var demoEmail = environment.IsDevelopment() ? identifier.ToLowerInvariant() switch
        {
            "admin" => "admin@foodordering.local",
            "nhanvien" => "staff@foodordering.local",
            "user" => "member@foodordering.local",
            _ => null,
        } : null;

        if (demoEmail is not null)
            request = request with { Email = demoEmail };
        else if (request.Password.Length < 8 || !new System.ComponentModel.DataAnnotations.EmailAddressAttribute().IsValid(identifier))
            return Unauthorized(ApiErrorResponse.Create("invalid_credentials", "Email hoặc mật khẩu không đúng."));

        var result = await authService.LoginAsync(request, cancellationToken);
        return result.IsSuccess
            ? Ok(result.Value)
            : Unauthorized(ApiErrorResponse.Create("invalid_credentials", result.Error!));
    }

    [HttpPost("refresh")]
    [EnableRateLimiting("auth-refresh")]
    public async Task<IActionResult> Refresh(RefreshTokenRequest request, CancellationToken cancellationToken)
    {
        var result = await authService.RefreshAsync(request, cancellationToken);
        return result.IsSuccess
            ? Ok(result.Value)
            : Unauthorized(ApiErrorResponse.Create("invalid_refresh_token", result.Error!));
    }

    [Authorize]
    [HttpPut("change-password")]
    [EnableRateLimiting("auth-session")]
    public async Task<IActionResult> ChangePassword(ChangePasswordRequest request, CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var userId))
        {
            return Unauthorized();
        }

        var result = await authService.ChangePasswordAsync(userId, request, cancellationToken);
        return result.IsSuccess ? NoContent() : BadRequest(ApiErrorResponse.Create("change_password_failed", result.Error!));
    }

    [Authorize]
    [HttpPost("logout")]
    [EnableRateLimiting("auth-session")]
    public async Task<IActionResult> Logout(LogoutRequest request, CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var userId))
        {
            return Unauthorized();
        }

        await authService.LogoutAsync(userId, request, cancellationToken);
        return NoContent();
    }
}
