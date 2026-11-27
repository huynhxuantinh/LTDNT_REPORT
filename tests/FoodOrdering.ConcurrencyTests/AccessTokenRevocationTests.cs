using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using FoodOrdering.Api.Auth;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using FoodOrdering.Api.Users;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Xunit;

namespace FoodOrdering.ConcurrencyTests;

public sealed class AccessTokenRevocationTests
{
    [SqlServerFact]
    public async Task RoleChangesAndLocksInvalidateOldTokensAndRefreshSessions()
    {
        var connection = new SqlConnectionStringBuilder(Environment.GetEnvironmentVariable("FOOD_ORDERING_TEST_CONNECTION")!)
        {
            InitialCatalog = "codex_auth_test_" + Guid.NewGuid().ToString("N")[..12],
            Pooling = false,
        };
        var options = new DbContextOptionsBuilder<FoodOrderingDbContext>().UseSqlServer(connection.ConnectionString).Options;
        await using var db = new FoodOrderingDbContext(options);
        var created = false;
        try
        {
            if (await db.Database.CanConnectAsync()) throw new InvalidOperationException("Generated test database already exists.");
            created = await db.Database.EnsureCreatedAsync();
            if (!created) throw new InvalidOperationException("Could not create the isolated test database.");

            var memberRole = new Role { RoleId = 1, RoleName = "Member" };
            var staffRole = new Role { RoleId = 2, RoleName = "Staff" };
            db.Roles.AddRange(memberRole, staffRole);
            await db.SaveChangesAsync();
            var user = new User { UserId = Guid.NewGuid(), FullName = "Test", Email = "auth@example.test", PasswordHash = "test", RoleId = memberRole.RoleId, IsActive = true, CreatedAt = DateTime.UtcNow };
            db.Users.Add(user);
            db.RefreshTokens.Add(new RefreshToken { RefreshTokenId = Guid.NewGuid(), UserId = user.UserId, TokenHash = "refresh-hash", CreatedAt = DateTime.UtcNow, ExpiresAt = DateTime.UtcNow.AddDays(1) });
            await db.SaveChangesAsync();

            var jwt = new JwtOptions { Issuer = "test-issuer", Audience = "test-audience", Key = new string('K', 48) };
            var tokenService = new JwtTokenService(jwt);
            ClaimsPrincipal principal(User tokenUser) => new JwtSecurityTokenHandler().ValidateToken(
                tokenService.CreateAccessToken(tokenUser),
                new TokenValidationParameters { ValidIssuer = jwt.Issuer, ValidAudience = jwt.Audience, IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.Key)), ValidateIssuerSigningKey = true }, out _);

            user.Role = memberRole;
            var oldPrincipal = principal(user);
            Assert.True(await AccessTokenValidator.IsCurrentAsync(oldPrincipal, db, default));
            var admin = new AdminUserService(db);
            Assert.True((await admin.ChangeRoleAsync(Guid.NewGuid(), user.UserId, new ChangeUserRoleRequest("Staff"), default)).IsSuccess);
            Assert.False(await AccessTokenValidator.IsCurrentAsync(oldPrincipal, db, default));
            Assert.NotNull((await db.RefreshTokens.SingleAsync()).RevokedAt);

            db.ChangeTracker.Clear();
            user = await db.Users.Include(x => x.Role).SingleAsync();
            var staffPrincipal = principal(user);
            Assert.True(await AccessTokenValidator.IsCurrentAsync(staffPrincipal, db, default));
            Assert.True((await admin.ChangeRoleAsync(Guid.NewGuid(), user.UserId, new ChangeUserRoleRequest("Member"), default)).IsSuccess);
            Assert.False(await AccessTokenValidator.IsCurrentAsync(oldPrincipal, db, default));
            Assert.False(await AccessTokenValidator.IsCurrentAsync(staffPrincipal, db, default));

            db.ChangeTracker.Clear();
            user = await db.Users.Include(x => x.Role).SingleAsync();
            var currentPrincipal = principal(user);
            Assert.True((await admin.ChangeActiveStatusAsync(Guid.NewGuid(), user.UserId, new ChangeUserActiveStatusRequest(false), default)).IsSuccess);
            Assert.False(await AccessTokenValidator.IsCurrentAsync(currentPrincipal, db, default));
            Assert.True((await admin.ChangeActiveStatusAsync(Guid.NewGuid(), user.UserId, new ChangeUserActiveStatusRequest(true), default)).IsSuccess);
            Assert.False(await AccessTokenValidator.IsCurrentAsync(currentPrincipal, db, default));
            Assert.False(await AccessTokenValidator.IsCurrentAsync(new ClaimsPrincipal(new ClaimsIdentity()), db, default));
        }
        finally
        {
            if (created) await db.Database.EnsureDeletedAsync();
        }
    }
}
