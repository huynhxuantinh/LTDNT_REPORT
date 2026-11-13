using FoodOrdering.Api.Common;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.FoodItems;
using FoodOrdering.Api.Models;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace FoodOrdering.Api.Tests;

public sealed class MemberFoodServiceTests
{
    [Fact]
    public async Task GetAllAsync_ReturnsOnlyAvailableFoodItems()
    {
        await using var context = new FoodOrderingDbContext(
            new DbContextOptionsBuilder<FoodOrderingDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .Options);
        var category = new Category { Name = "Món chính", IsActive = true, CreatedAt = DateTime.UtcNow };
        context.Categories.Add(category);
        context.FoodItems.AddRange(
            new FoodItem { Category = category, Name = "Món đang bán", Price = 30000, IsAvailable = true, CreatedAt = DateTime.UtcNow },
            new FoodItem { Category = category, Name = "Món đã ẩn", Price = 40000, IsAvailable = false, CreatedAt = DateTime.UtcNow });
        await context.SaveChangesAsync();
        var service = new MemberFoodService(context);

        var result = await service.GetAllAsync(new PageRequest(1, 20), null, null, CancellationToken.None);

        Assert.Single(result.Data);
        Assert.Equal("Món đang bán", result.Data[0].Name);
        Assert.Equal(1, result.Meta.TotalItems);
    }
}
