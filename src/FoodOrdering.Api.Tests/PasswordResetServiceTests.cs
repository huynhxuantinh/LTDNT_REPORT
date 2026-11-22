using FoodOrdering.Api.Auth;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace FoodOrdering.Api.Tests;

public sealed class PasswordResetServiceTests
{
    [Fact]
    public async Task Code_is_bound_to_email_limited_and_single_use()
    {
        await using var db = new FoodOrderingDbContext(new DbContextOptionsBuilder<FoodOrderingDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .ConfigureWarnings(w => w.Ignore(InMemoryEventId.TransactionIgnoredWarning)).Options);
        var user = new User { UserId = Guid.NewGuid(), FullName = "Test User", Email = "test@example.com", PasswordHash = "old", IsActive = true };
        db.Users.Add(user);
        var token = new PasswordResetToken { PasswordResetTokenId = Guid.NewGuid(), UserId = user.UserId, TokenHash = BCrypt.Net.BCrypt.HashPassword("012345"), CreatedAt = DateTime.UtcNow, ExpiresAt = DateTime.UtcNow.AddMinutes(10) };
        db.PasswordResetTokens.Add(token);
        await db.SaveChangesAsync();
        var service = new PasswordResetService(db, new ConfigurationBuilder().Build(), NullLogger<PasswordResetService>.Instance);

        Assert.False(await service.CheckCodeAsync("other@example.com", "012345", CancellationToken.None));
        Assert.False(await service.CheckCodeAsync(user.Email, "123456", CancellationToken.None));
        Assert.True(await service.CheckCodeAsync(user.Email, "012345", CancellationToken.None));
        Assert.True(await service.ResetAsync(user.Email, "012345", "NewPassword123", CancellationToken.None));
        Assert.True(BCrypt.Net.BCrypt.Verify("NewPassword123", user.PasswordHash));
        Assert.False(await service.ResetAsync(user.Email, "012345", "OtherPassword123", CancellationToken.None));
    }

    [Fact]
    public async Task Five_wrong_codes_lock_the_code()
    {
        await using var db = new FoodOrderingDbContext(new DbContextOptionsBuilder<FoodOrderingDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .ConfigureWarnings(w => w.Ignore(InMemoryEventId.TransactionIgnoredWarning)).Options);
        var user = new User { UserId = Guid.NewGuid(), FullName = "Test User", Email = "test@example.com", PasswordHash = "old", IsActive = true };
        db.Users.Add(user);
        db.PasswordResetTokens.Add(new PasswordResetToken { PasswordResetTokenId = Guid.NewGuid(), UserId = user.UserId, TokenHash = BCrypt.Net.BCrypt.HashPassword("012345"), CreatedAt = DateTime.UtcNow, ExpiresAt = DateTime.UtcNow.AddMinutes(10) });
        await db.SaveChangesAsync();
        var service = new PasswordResetService(db, new ConfigurationBuilder().Build(), NullLogger<PasswordResetService>.Instance);
        for (var i = 0; i < 5; i++) Assert.False(await service.CheckCodeAsync(user.Email, "111111", CancellationToken.None));
        Assert.False(await service.CheckCodeAsync(user.Email, "012345", CancellationToken.None));
    }
}
