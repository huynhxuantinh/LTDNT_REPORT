using FoodOrdering.Api.Categories;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace FoodOrdering.Api.Tests;

public sealed class MemberCategoryServiceTests
{
    [Fact]
    public async Task GetActiveAsync_ReturnsOnlyActiveCategories()
    {
        await using var context = new FoodOrderingDbContext(
            new DbContextOptionsBuilder<FoodOrderingDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .Options);
        context.Categories.AddRange(
            new Category { Name = "Món chính", IsActive = true, CreatedAt = DateTime.UtcNow },
            new Category { Name = "Đã ẩn", IsActive = false, CreatedAt = DateTime.UtcNow });
        await context.SaveChangesAsync();
        var service = new MemberCategoryService(context);

        var result = await service.GetActiveAsync(CancellationToken.None);

        Assert.Single(result);
        Assert.Equal("Món chính", result[0].Name);
    }
}
