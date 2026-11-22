using FoodOrdering.Api.Auth;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace FoodOrdering.Api.Tests;

public sealed class RegistrationServiceTests
{
    [Fact]
    public async Task RegistrationRequiresValidCodeAndCannotReuseIt()
    {
        await using var db = CreateDb();
        db.Roles.Add(new Role { RoleId = 1, RoleName = "Member" });
        var pending = CreatePending("test@example.com");
        db.PendingRegistrations.Add(pending);
        await db.SaveChangesAsync();
        var service = new RegistrationService(db, new ConfigurationBuilder().Build());

        Assert.False(await service.CheckAsync("other@example.com", "012345", CancellationToken.None));
        Assert.False(await service.CheckAsync(pending.Email, "111111", CancellationToken.None));
        Assert.True(await service.CheckAsync(pending.Email, "012345", CancellationToken.None));
        Assert.False((await service.CompleteAsync(new(pending.Email, "111111", "Password123"), CancellationToken.None)).IsSuccess);
        Assert.Empty(db.Users);
        Assert.True((await service.CompleteAsync(new(pending.Email, "012345", "Password123"), CancellationToken.None)).IsSuccess);
        Assert.True((await db.Users.SingleAsync()).IsEmailVerified);
        Assert.False((await service.CompleteAsync(new(pending.Email, "012345", "Password123"), CancellationToken.None)).IsSuccess);
    }

    [Fact]
    public async Task ExpiredOrLockedCodeIsRejected()
    {
        await using var db = CreateDb();
        var expired = CreatePending("expired@example.com");
        expired.ExpiresAt = DateTime.UtcNow.AddMinutes(-1);
        var locked = CreatePending("locked@example.com");
        db.PendingRegistrations.AddRange(expired, locked);
        await db.SaveChangesAsync();
        var service = new RegistrationService(db, new ConfigurationBuilder().Build());

        Assert.False(await service.CheckAsync(expired.Email, "012345", CancellationToken.None));
        for (var i = 0; i < 5; i++) Assert.False(await service.CheckAsync(locked.Email, "111111", CancellationToken.None));
        Assert.False(await service.CheckAsync(locked.Email, "012345", CancellationToken.None));
    }

    private static FoodOrderingDbContext CreateDb() => new(new DbContextOptionsBuilder<FoodOrderingDbContext>()
        .UseInMemoryDatabase(Guid.NewGuid().ToString()).ConfigureWarnings(w => w.Ignore(InMemoryEventId.TransactionIgnoredWarning)).Options);

    private static PendingRegistration CreatePending(string email) => new()
    {
        PendingRegistrationId = Guid.NewGuid(), Email = email, FullName = "Test User",
        TokenHash = BCrypt.Net.BCrypt.HashPassword("012345"), CreatedAt = DateTime.UtcNow, ExpiresAt = DateTime.UtcNow.AddMinutes(10)
    };
}
