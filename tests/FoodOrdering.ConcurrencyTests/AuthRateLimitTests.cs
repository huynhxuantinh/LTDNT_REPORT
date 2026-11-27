using System.Diagnostics;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Net.Sockets;
using FoodOrdering.Api.Auth;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace FoodOrdering.ConcurrencyTests;

public sealed class AuthRateLimitTests
{
    [SqlServerFact]
    public async Task LoginRefreshRecoveryAndLogoutHaveIndependentLimits()
    {
        var connection = new SqlConnectionStringBuilder(Environment.GetEnvironmentVariable("FOOD_ORDERING_TEST_CONNECTION")!)
        {
            InitialCatalog = "codex_limit_test_" + Guid.NewGuid().ToString("N")[..12],
            Pooling = false,
        };
        var options = new DbContextOptionsBuilder<FoodOrderingDbContext>().UseSqlServer(connection.ConnectionString).Options;
        await using var db = new FoodOrderingDbContext(options);
        var created = false;
        Process? api = null;
        try
        {
            if (await db.Database.CanConnectAsync()) throw new InvalidOperationException("Generated test database already exists.");
            created = await db.Database.EnsureCreatedAsync();
            if (!created) throw new InvalidOperationException("Could not create the isolated test database.");

            var role = new Role { RoleId = 1, RoleName = "Member" };
            db.Roles.Add(role);
            var first = new User { UserId = Guid.NewGuid(), FullName = "First", Email = "first@example.test", PasswordHash = "test", Role = role, RoleId = 1, IsActive = true, CreatedAt = DateTime.UtcNow };
            var second = new User { UserId = Guid.NewGuid(), FullName = "Second", Email = "second@example.test", PasswordHash = "test", Role = role, RoleId = 1, IsActive = true, CreatedAt = DateTime.UtcNow };
            db.Users.AddRange(first, second);
            await db.SaveChangesAsync();

            using var listener = new TcpListener(IPAddress.Loopback, 0);
            listener.Start();
            var port = ((IPEndPoint)listener.LocalEndpoint).Port;
            listener.Stop();
            var jwt = new JwtOptions { Issuer = "test-issuer", Audience = "test-audience", Key = new string('K', 48) };
            var apiDll = typeof(FoodOrderingDbContext).Assembly.Location;
            var start = new ProcessStartInfo("dotnet") { UseShellExecute = false, CreateNoWindow = true, WorkingDirectory = Path.GetTempPath() };
            start.ArgumentList.Add(apiDll);
            start.Environment["ASPNETCORE_ENVIRONMENT"] = "Production";
            start.Environment["ASPNETCORE_URLS"] = $"http://127.0.0.1:{port}";
            start.Environment["ConnectionStrings__FoodOrdering"] = connection.ConnectionString;
            start.Environment["Jwt__Issuer"] = jwt.Issuer;
            start.Environment["Jwt__Audience"] = jwt.Audience;
            start.Environment["Jwt__Key"] = jwt.Key;
            foreach (var key in new[] { "LoginPerMinute", "SensitivePerMinute", "RefreshPerMinute", "SessionPerMinute" })
                start.Environment[$"AuthRateLimits__{key}"] = "2";
            api = Process.Start(start) ?? throw new InvalidOperationException("Could not start test API.");
            using var client = new HttpClient { BaseAddress = new Uri($"http://127.0.0.1:{port}"), Timeout = TimeSpan.FromSeconds(15) };
            var ready = false;
            for (var attempt = 0; attempt < 100 && !ready; attempt++)
            {
                if (api.HasExited) throw new InvalidOperationException("Test API exited before startup.");
                try { await client.GetAsync("/api/categories"); ready = true; }
                catch (HttpRequestException) { await Task.Delay(100); }
            }
            Assert.True(ready, "Test API did not start.");

            async Task<HttpStatusCode> Post(string path, object body, string? token = null)
            {
                using var request = new HttpRequestMessage(HttpMethod.Post, path) { Content = JsonContent.Create(body) };
                if (token is not null) request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
                using var response = await client.SendAsync(request);
                return response.StatusCode;
            }

            Assert.Equal(HttpStatusCode.BadRequest, await Post("/api/auth/login", new { }));
            Assert.Equal(HttpStatusCode.BadRequest, await Post("/api/auth/login", new { }));
            Assert.Equal(HttpStatusCode.TooManyRequests, await Post("/api/auth/login", new { }));

            var invalidRefresh = new { refreshToken = new string('r', 40) };
            Assert.Equal(HttpStatusCode.Unauthorized, await Post("/api/auth/refresh", invalidRefresh));
            Assert.Equal(HttpStatusCode.Unauthorized, await Post("/api/auth/refresh", invalidRefresh));
            Assert.Equal(HttpStatusCode.TooManyRequests, await Post("/api/auth/refresh", invalidRefresh));

            Assert.Equal(HttpStatusCode.BadRequest, await Post("/api/auth/register/start", new { }));
            Assert.Equal(HttpStatusCode.BadRequest, await Post("/api/auth/register/start", new { }));
            Assert.Equal(HttpStatusCode.TooManyRequests, await Post("/api/auth/register/start", new { }));

            var tokenService = new JwtTokenService(jwt);
            var firstToken = tokenService.CreateAccessToken(first);
            var secondToken = tokenService.CreateAccessToken(second);
            Assert.Equal(HttpStatusCode.NoContent, await Post("/api/auth/logout", invalidRefresh, firstToken));
            Assert.Equal(HttpStatusCode.NoContent, await Post("/api/auth/logout", invalidRefresh, firstToken));
            Assert.Equal(HttpStatusCode.TooManyRequests, await Post("/api/auth/logout", invalidRefresh, firstToken));
            Assert.Equal(HttpStatusCode.NoContent, await Post("/api/auth/logout", invalidRefresh, secondToken));
        }
        finally
        {
            if (api is not null)
            {
                if (!api.HasExited) { api.Kill(entireProcessTree: true); await api.WaitForExitAsync(); }
                api.Dispose();
            }
            if (created) await db.Database.EnsureDeletedAsync();
        }
    }
}
