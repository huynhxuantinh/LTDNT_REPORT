using FoodOrdering.Api.Auth;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace FoodOrdering.Api.Tests;

public sealed class AuthServiceTests
{
    [Fact]
    public async Task RegisterAsync_CreatesMemberWithHashedPassword()
    {
        await using var context = CreateContext();
        context.Roles.Add(new Role { RoleId = 1, RoleName = "Member" });
        await context.SaveChangesAsync();
        var service = CreateService(context);

        var result = await service.RegisterAsync(new RegisterRequest("Nguyen Van A", "a@example.com", "Password1"), CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error);
        var user = await context.Users.SingleAsync();
        Assert.Equal("a@example.com", user.Email);
        Assert.NotEqual("Password1", user.PasswordHash);
        Assert.True(BCrypt.Net.BCrypt.Verify("Password1", user.PasswordHash));
    }

    [Fact]
    public async Task LoginAsync_ReturnsTokensForCorrectCredentials()
    {
        await using var context = CreateContext();
        context.Roles.Add(new Role { RoleId = 1, RoleName = "Member" });
        var user = AddMember(context, "a@example.com", "Password1");
        await context.SaveChangesAsync();
        Assert.True(BCrypt.Net.BCrypt.Verify("Password1", user.PasswordHash));
        Assert.NotNull(await context.Users.SingleOrDefaultAsync(item => item.Email == "a@example.com"));
        var service = CreateService(context);

        var result = await service.LoginAsync(new LoginRequest("a@example.com", "Password1"), CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error);
        Assert.Equal("access-token", result.Value!.AccessToken);
        Assert.NotEmpty(result.Value.RefreshToken);
        Assert.Single(context.RefreshTokens);
        Assert.Equal(user.UserId, context.RefreshTokens.Single().UserId);
    }

    [Fact]
    public async Task ChangePasswordAsync_RevokesRefreshTokensAndAcceptsNewPassword()
    {
        await using var context = CreateContext();
        var user = AddMember(context, "a@example.com", "Password1");
        context.RefreshTokens.Add(new RefreshToken { UserId = user.UserId, TokenHash = "old", ExpiresAt = DateTime.UtcNow.AddDays(1) });
        await context.SaveChangesAsync();
        var service = CreateService(context);

        var result = await service.ChangePasswordAsync(user.UserId, new ChangePasswordRequest("Password1", "NewPassword1"), CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.True(BCrypt.Net.BCrypt.Verify("NewPassword1", user.PasswordHash));
        Assert.NotNull(context.RefreshTokens.Single().RevokedAt);
    }

    [Fact]
    public async Task LogoutAsync_RevokesOnlyProvidedRefreshToken()
    {
        await using var context = CreateContext();
        var user = AddMember(context, "a@example.com", "Password1");
        context.RefreshTokens.Add(new RefreshToken { UserId = user.UserId, TokenHash = AuthService.HashToken("refresh-token"), ExpiresAt = DateTime.UtcNow.AddDays(1) });
        await context.SaveChangesAsync();
        var service = CreateService(context);

        await service.LogoutAsync(user.UserId, new LogoutRequest("refresh-token"), CancellationToken.None);

        Assert.NotNull(context.RefreshTokens.Single().RevokedAt);
    }

    private static FoodOrderingDbContext CreateContext() => new(
        new DbContextOptionsBuilder<FoodOrderingDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options);

    private static AuthService CreateService(FoodOrderingDbContext context) => new(context, new FakeTokenService());

    private static User AddMember(FoodOrderingDbContext context, string email, string password)
    {
        var user = new User
        {
            UserId = Guid.NewGuid(),
            FullName = "Member",
            Email = email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(password),
            RoleId = 1,
            IsActive = true,
        };
        context.Users.Add(user);
        return user;
    }

    private sealed class FakeTokenService : ITokenService
    {
        public string CreateAccessToken(User user) => "access-token";
    }
}
