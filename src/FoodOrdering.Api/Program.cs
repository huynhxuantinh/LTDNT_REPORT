using System.Text;
using System.Threading.RateLimiting;
using System.Security.Claims;
using FoodOrdering.Api.Auth;
using FoodOrdering.Api.Categories;
using FoodOrdering.Api.Carts;
using FoodOrdering.Api.Common;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.FoodItems;
using FoodOrdering.Api.Uploads;
using FoodOrdering.Api.Users;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.FileProviders;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);
var connectionString = builder.Configuration.GetConnectionString("FoodOrdering")
    ?? throw new InvalidOperationException("Thiếu ConnectionStrings:FoodOrdering.");
var jwtOptions = builder.Configuration.GetSection("Jwt").Get<JwtOptions>()
    ?? throw new InvalidOperationException("Thiếu cấu hình Jwt.");

if (Encoding.UTF8.GetByteCount(jwtOptions.Key) < 32)
{
    throw new InvalidOperationException("Jwt:Key phải có ít nhất 32 bytes.");
}

builder.Services.AddDbContext<FoodOrderingDbContext>(options => options.UseSqlServer(connectionString));
builder.Services.AddScoped<AuthService>();
builder.Services.AddScoped<EmailVerificationService>();
builder.Services.AddScoped<PasswordResetService>();
builder.Services.AddScoped<RegistrationService>();
builder.Services.AddScoped<AdminUserService>();
builder.Services.AddScoped<AdminCategoryService>();
builder.Services.AddScoped<MemberCategoryService>();
builder.Services.AddScoped<AdminFoodItemService>();
builder.Services.AddScoped<MemberFoodService>();
builder.Services.AddScoped<CartService>();
builder.Services.AddSingleton<IFoodImageStorage, FoodImageStorage>();
builder.Services.AddScoped<UserProfileService>();
var vietQrOptions = builder.Configuration.GetSection("VietQR").Get<VietQrOptions>() ?? new VietQrOptions();
builder.Services.AddSingleton(vietQrOptions);
var vnPayOptions = builder.Configuration.GetSection("VNPay").Get<VnPayOptions>() ?? new VnPayOptions();
builder.Services.AddSingleton(vnPayOptions);
builder.Services.AddSingleton(jwtOptions);
builder.Services.AddSingleton<ITokenService, JwtTokenService>();
builder.Services.AddControllers();
builder.Services.Configure<ApiBehaviorOptions>(options =>
{
    options.InvalidModelStateResponseFactory = context =>
    {
        var details = context.ModelState
            .Where(item => item.Value?.Errors.Count > 0)
            .ToDictionary(
                item => item.Key,
                item => item.Value!.Errors.Select(_ => "Giá trị không hợp lệ hoặc không đúng định dạng.").ToArray());
        return new BadRequestObjectResult(ApiErrorResponse.Validation(details));
    };
});
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    int Limit(string name, int fallback) => Math.Clamp(builder.Configuration.GetValue<int?>($"AuthRateLimits:{name}") ?? fallback, 1, 10000);
    FixedWindowRateLimiterOptions Window(int limit) => new()
        {
            PermitLimit = limit,
            Window = TimeSpan.FromMinutes(1),
            QueueLimit = 0,
            AutoReplenishment = true,
        };
    string Ip(HttpContext context) => context.Connection.RemoteIpAddress?.MapToIPv6().ToString() ?? "unknown";
    string UserOrIp(HttpContext context) => context.User.FindFirstValue(ClaimTypes.NameIdentifier) is { Length: > 0 } id
        ? $"user:{id}" : $"ip:{Ip(context)}";

    options.AddPolicy("auth-login", context => RateLimitPartition.GetFixedWindowLimiter(
        $"login:{Ip(context)}", _ => Window(Limit("LoginPerMinute", 60))));
    options.AddPolicy("auth-sensitive", context => RateLimitPartition.GetFixedWindowLimiter(
        $"sensitive:{Ip(context)}", _ => Window(Limit("SensitivePerMinute", 30))));
    options.AddPolicy("auth-refresh", context => RateLimitPartition.GetFixedWindowLimiter(
        $"refresh:{Ip(context)}", _ => Window(Limit("RefreshPerMinute", 300))));
    options.AddPolicy("auth-session", context => RateLimitPartition.GetFixedWindowLimiter(
        $"session:{UserOrIp(context)}", _ => Window(Limit("SessionPerMinute", 30))));
    options.OnRejected = async (context, cancellationToken) =>
    {
        context.HttpContext.Response.Headers.RetryAfter = "60";
        await context.HttpContext.Response.WriteAsJsonAsync(
            ApiErrorResponse.Create("rate_limit_exceeded", "Quá nhiều yêu cầu. Vui lòng thử lại sau."),
            cancellationToken);
    };
});
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwtOptions.Issuer,
            ValidateAudience = true,
            ValidAudience = jwtOptions.Audience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtOptions.Key)),
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromSeconds(30),
        };
        options.Events = new JwtBearerEvents
        {
            OnTokenValidated = async context =>
            {
                var db = context.HttpContext.RequestServices.GetRequiredService<FoodOrderingDbContext>();
                if (!await AccessTokenValidator.IsCurrentAsync(context.Principal, db, context.HttpContext.RequestAborted))
                    context.Fail("Phiên đăng nhập không còn hợp lệ.");
            }
        };
    });
builder.Services.AddAuthorization();
builder.Services.AddCors();

var webRootPath = builder.Environment.WebRootPath ?? Path.Combine(builder.Environment.ContentRootPath, "wwwroot");
Directory.CreateDirectory(webRootPath);

var app = builder.Build();
if (app.Environment.IsDevelopment())
{
    app.UseCors(policy => policy
        .SetIsOriginAllowed(origin => Uri.TryCreate(origin, UriKind.Absolute, out var uri)
            && (uri.Host.Equals("localhost", StringComparison.OrdinalIgnoreCase)
                || uri.Host.Equals("127.0.0.1", StringComparison.OrdinalIgnoreCase)))
        .AllowAnyHeader()
        .AllowAnyMethod());
}
app.UseExceptionHandler(exceptionApp => exceptionApp.Run(async context =>
{
    context.Response.StatusCode = StatusCodes.Status500InternalServerError;
    var error = context.Features.Get<Microsoft.AspNetCore.Diagnostics.IExceptionHandlerFeature>()?.Error;
    if (error is not null) app.Logger.LogError(error, "Đã xảy ra lỗi hệ thống.");
    await context.Response.WriteAsJsonAsync(ApiErrorResponse.Create("internal_error", "Đã xảy ra lỗi hệ thống. Vui lòng thử lại."));
}));
app.UseAuthentication();
app.UseAuthorization();
app.UseRateLimiter();
app.UseStaticFiles(new StaticFileOptions { FileProvider = new PhysicalFileProvider(webRootPath) });
app.MapControllers();
app.Run();

public partial class Program;
