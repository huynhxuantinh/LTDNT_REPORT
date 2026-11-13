using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using FoodOrdering.Api.Users;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace FoodOrdering.Api.Tests;

public sealed class UserProfileServiceTests
{
    [Fact]
    public async Task UpdateProfileAsync_ChangesOnlyAuthenticatedUsersProfile()
    {
        await using var context = new FoodOrderingDbContext(
            new DbContextOptionsBuilder<FoodOrderingDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .Options);
        context.Roles.Add(new Role { RoleId = 1, RoleName = "Member" });
        var memberA = CreateUser("Member A", "a@example.com");
        var memberB = CreateUser("Member B", "b@example.com");
        context.Users.AddRange(memberA, memberB);
        await context.SaveChangesAsync();
        var service = new UserProfileService(context);

        var result = await service.UpdateProfileAsync(memberA.UserId, new UpdateMyProfileRequest("New Name", "0900000009"), CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error);
        Assert.Equal("New Name", memberA.FullName);
        Assert.Equal("0900000009", memberA.PhoneNumber);
        Assert.Equal("Member B", memberB.FullName);
    }

    private static User CreateUser(string fullName, string email) => new()
    {
        UserId = Guid.NewGuid(),
        FullName = fullName,
        Email = email,
        PasswordHash = "not-returned",
        RoleId = 1,
        IsActive = true,
        CreatedAt = DateTime.UtcNow,
    };
}
