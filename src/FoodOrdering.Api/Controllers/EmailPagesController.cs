using System.Net;
using FoodOrdering.Api.Auth;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace FoodOrdering.Api.Controllers;

[Route("email")]
[EnableRateLimiting("auth")]
public sealed class EmailPagesController(EmailVerificationService verification, PasswordResetService reset, RegistrationService registration) : Controller
{
    private IActionResult Page(string title, string content)
    {
        Response.Headers.CacheControl = "no-store";
        Response.Headers["Referrer-Policy"] = "no-referrer";
        return Content($"<!doctype html><html lang=\"vi\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>{WebUtility.HtmlEncode(title)}</title></head><body style=\"font-family:Arial,sans-serif;max-width:480px;margin:48px auto;padding:16px;line-height:1.6\"><h1>{WebUtility.HtmlEncode(title)}</h1>{content}</body></html>", "text/html; charset=utf-8");
    }

    [HttpGet("verify")]
    public IActionResult VerifyForm([FromQuery] string? token) => ValidToken(token)
        ? Page("Xác thực email", $"<p>Nhấn nút để xác nhận tài khoản.</p><form method=\"post\" action=\"/email/verify\"><input type=\"hidden\" name=\"token\" value=\"{WebUtility.HtmlEncode(token)}\"><button type=\"submit\">Xác thực</button></form>")
        : Page("Liên kết không hợp lệ", "<p>Vui lòng kiểm tra lại liên kết.</p>");

    [HttpPost("verify")]
    public async Task<IActionResult> Verify([FromForm] string? token, CancellationToken ct) =>
        ValidToken(token) && await verification.VerifyAsync(token!, ct)
            ? Page("Xác thực thành công", "<p>Bạn có thể quay lại ứng dụng để đăng nhập.</p>")
            : Page("Không thể xác thực", "<p>Liên kết không hợp lệ, đã dùng hoặc hết hạn.</p>");

    [HttpGet("register")]
    public async Task<IActionResult> RegisterForm([FromQuery] string? token, CancellationToken ct)
    {
        if (!ValidToken(token) || !await registration.CheckAsync(token!, ct)) return Page("Liên kết không hợp lệ", "<p>Mã đã hết hạn hoặc không hợp lệ.</p>");
        return Page("Email đã được xác nhận", $"<p>Đặt mật khẩu để hoàn tất đăng ký.</p><form method=\"post\" action=\"/email/register\"><input type=\"hidden\" name=\"token\" value=\"{WebUtility.HtmlEncode(token)}\"><label>Mật khẩu mới<br><input type=\"password\" name=\"password\" minlength=\"8\" maxlength=\"128\" required autocomplete=\"new-password\"></label><p>Ít nhất 8 ký tự, gồm chữ hoa, chữ thường và số.</p><button type=\"submit\">Hoàn tất đăng ký</button></form>");
    }

    [HttpPost("register")]
    public async Task<IActionResult> Register([FromForm] string? token, [FromForm] string? password, CancellationToken ct)
    {
        if (!ValidToken(token) || password is not { Length: >= 8 and <= 128 }) return Page("Không thể đăng ký", "<p>Mã hoặc mật khẩu không hợp lệ.</p>");
        var result = await registration.CompleteAsync(new CompleteRegistrationRequest(token!, password), ct);
        return result.IsSuccess ? Page("Đăng ký thành công", "<p>Bạn có thể quay lại ứng dụng để đăng nhập.</p>") : Page("Không thể đăng ký", $"<p>{WebUtility.HtmlEncode(result.Error)}</p>");
    }

    [HttpGet("reset-password")]
    public IActionResult ResetForm([FromQuery] string? token) => ValidToken(token)
        ? Page("Đặt lại mật khẩu", $"<form method=\"post\" action=\"/email/reset-password\"><input type=\"hidden\" name=\"token\" value=\"{WebUtility.HtmlEncode(token)}\"><label>Mật khẩu mới (ít nhất 8 ký tự, gồm chữ hoa, chữ thường và số)<br><input type=\"password\" name=\"password\" minlength=\"8\" maxlength=\"128\" required autocomplete=\"new-password\"></label><p><button type=\"submit\">Đặt lại mật khẩu</button></p></form>")
        : Page("Liên kết không hợp lệ", "<p>Vui lòng kiểm tra lại liên kết.</p>");

    [HttpPost("reset-password")]
    public async Task<IActionResult> Reset([FromForm] string? token, [FromForm] string? password, CancellationToken ct) =>
        ValidToken(token) && password is { Length: >= 8 and <= 128 } && await reset.ResetAsync(token!, password, ct)
            ? Page("Đặt lại mật khẩu thành công", "<p>Bạn có thể quay lại ứng dụng để đăng nhập.</p>")
            : Page("Không thể đặt lại mật khẩu", "<p>Liên kết không hợp lệ, đã dùng hoặc hết hạn, hoặc mật khẩu chưa đúng yêu cầu.</p>");

    private static bool ValidToken(string? token) => token is { Length: >= 32 and <= 128 };
}
