using FoodOrdering.Api.Common;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using FoodOrdering.Api.Users;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace FoodOrdering.Api.Tests;

public sealed class AdminUserServiceTests
{
    [Fact]
    public async Task GetUsersAsync_SearchesAndPaginatesWithoutPasswordHash()
    {
        await using var context = new FoodOrderingDbContext(
            new DbContextOptionsBuilder<FoodOrderingDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .Options);
        context.Roles.AddRange(
            new Role { RoleId = 1, RoleName = "Member" },
            new Role { RoleId = 2, RoleName = "Admin" });
        context.Users.AddRange(
            CreateUser("Alice One", "alice.one@example.com", 1, DateTime.UtcNow.AddMinutes(-2)),
            CreateUser("Alice Two", "alice.two@example.com", 2, DateTime.UtcNow.AddMinutes(-1)),
            CreateUser("Bob", "bob@example.com", 1, DateTime.UtcNow));
        await context.SaveChangesAsync();
        var service = new AdminUserService(context);

        var result = await service.GetUsersAsync(new PageRequest(1, 1), "alice", CancellationToken.None);

        Assert.Single(result.Data);
        Assert.Equal(2, result.Meta.TotalItems);
        Assert.Equal(2, result.Meta.TotalPages);
        Assert.Equal("alice.two@example.com", result.Data[0].Email);
        Assert.DoesNotContain("PasswordHash", typeof(AdminUserListItem).GetProperties().Select(x => x.Name));
    }

    [Fact]
    public async Task ChangeRoleAsync_UpdatesUserToStaff()
    {
        await using var context = new FoodOrderingDbContext(
            new DbContextOptionsBuilder<FoodOrderingDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .Options);
        context.Roles.AddRange(
            new Role { RoleId = 1, RoleName = "Member" },
            new Role { RoleId = 2, RoleName = "Admin" },
            new Role { RoleId = 3, RoleName = "Staff" });
        var admin = CreateUser("Admin", "admin@example.com", 2, DateTime.UtcNow);
        var member = CreateUser("Member", "member@example.com", 1, DateTime.UtcNow);
        context.Users.AddRange(admin, member);
        await context.SaveChangesAsync();
        var service = new AdminUserService(context);

        var result = await service.ChangeRoleAsync(admin.UserId, member.UserId, new ChangeUserRoleRequest("Staff"), CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error);
        Assert.Equal("Staff", result.Value!.Role);
        Assert.Equal((byte)3, member.RoleId);
    }

    [Fact]
    public async Task ChangeActiveStatusAsync_LocksUserAndRevokesRefreshTokens()
    {
        await using var context = new FoodOrderingDbContext(
            new DbContextOptionsBuilder<FoodOrderingDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .Options);
        context.Roles.AddRange(
            new Role { RoleId = 1, RoleName = "Member" },
            new Role { RoleId = 2, RoleName = "Admin" });
        var admin = CreateUser("Admin", "admin@example.com", 2, DateTime.UtcNow);
        var member = CreateUser("Member", "member@example.com", 1, DateTime.UtcNow);
        context.Users.AddRange(admin, member);
        context.RefreshTokens.Add(new RefreshToken
        {
            RefreshTokenId = Guid.NewGuid(),
            UserId = member.UserId,
            TokenHash = "active-token",
            ExpiresAt = DateTime.UtcNow.AddDays(1),
            CreatedAt = DateTime.UtcNow,
        });
        await context.SaveChangesAsync();
        var service = new AdminUserService(context);

        var result = await service.ChangeActiveStatusAsync(admin.UserId, member.UserId, new ChangeUserActiveStatusRequest(false), CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error);
        Assert.False(result.Value!.IsActive);
        Assert.False(member.IsActive);
        Assert.NotNull(context.RefreshTokens.Single().RevokedAt);
    }

    private static User CreateUser(string fullName, string email, byte roleId, DateTime createdAt) => new()
    {
        UserId = Guid.NewGuid(),
        FullName = fullName,
        Email = email,
        PasswordHash = "never-expose-this",
        RoleId = roleId,
        IsActive = true,
        CreatedAt = createdAt,
    };
}
