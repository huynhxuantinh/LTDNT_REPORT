using System.Security.Claims;
using FoodOrdering.Api.Auth;
using FoodOrdering.Api.Common;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace FoodOrdering.Api.Controllers;

[ApiController]
[Route("api/auth")]
[EnableRateLimiting("auth")]
public sealed class AuthController(AuthService authService, EmailVerificationService verificationService, PasswordResetService resetService) : ControllerBase
{
    [HttpPost("forgot-password")]
    public async Task<IActionResult> ForgotPassword(ForgotPasswordRequest request, CancellationToken ct)
    {
        await resetService.RequestAsync(request.Email, ct);
        return Ok(new { message = "Nếu tài khoản tồn tại, email hướng dẫn đã được gửi." });
    }

    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword(ResetPasswordRequest request, CancellationToken ct) =>
        await resetService.ResetAsync(request.Token, request.NewPassword, ct) ? NoContent() : BadRequest(ApiErrorResponse.Create("reset_failed", "Mã không hợp lệ, đã hết hạn hoặc mật khẩu không đúng quy định."));
    [HttpPost("register")]
    public async Task<IActionResult> Register(RegisterRequest request, CancellationToken cancellationToken)
    {
        var result = await authService.RegisterAsync(request, cancellationToken);
        if (!result.IsSuccess) return BadRequest(ApiErrorResponse.Create("registration_failed", result.Error!));
        try { await verificationService.SendAsync(result.Value, cancellationToken); }
        catch (Exception) { return StatusCode(201, new { userId = result.Value, emailSent = false, message = "Đăng ký thành công nhưng chưa gửi được email." }); }
        return StatusCode(201, new { userId = result.Value, emailSent = true, message = "Đăng ký thành công, hãy kiểm tra email." });
    }

    [HttpPost("verify-email")]
    public async Task<IActionResult> VerifyEmail(VerifyEmailRequest request, CancellationToken cancellationToken) =>
        await verificationService.VerifyAsync(request.Token, cancellationToken) ? Ok(new { message = "Xác thực email thành công." }) : BadRequest(ApiErrorResponse.Create("invalid_token", "Mã xác thực không hợp lệ hoặc đã hết hạn."));

    [HttpPost("login")]
    public async Task<IActionResult> Login(LoginRequest request, CancellationToken cancellationToken)
    {
        var result = await authService.LoginAsync(request, cancellationToken);
        return result.IsSuccess
            ? Ok(result.Value)
            : Unauthorized(ApiErrorResponse.Create("invalid_credentials", result.Error!));
    }

    [HttpPost("refresh")]
    public async Task<IActionResult> Refresh(RefreshTokenRequest request, CancellationToken cancellationToken)
    {
        var result = await authService.RefreshAsync(request, cancellationToken);
        return result.IsSuccess
            ? Ok(result.Value)
            : Unauthorized(ApiErrorResponse.Create("invalid_refresh_token", result.Error!));
    }

    [Authorize]
    [HttpPut("change-password")]
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
