using FoodOrdering.Api.Categories;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace FoodOrdering.Api.Tests;

public sealed class AdminCategoryServiceTests
{
    [Fact]
    public async Task CreateUpdateDeleteAsync_ManagesEmptyCategory()
    {
        await using var context = CreateContext();
        var service = new AdminCategoryService(context);

        var created = await service.CreateAsync(new SaveCategoryRequest("Món thử", "Mô tả"), CancellationToken.None);
        var updated = await service.UpdateAsync(created.Value!.CategoryId, new SaveCategoryRequest("Món đã sửa", "Mới"), CancellationToken.None);
        var deleted = await service.DeleteAsync(created.Value.CategoryId, CancellationToken.None);

        Assert.True(created.IsSuccess, created.Error);
        Assert.True(updated.IsSuccess, updated.Error);
        Assert.Equal("Món đã sửa", updated.Value!.Name);
        Assert.True(deleted.IsSuccess, deleted.Error);
        Assert.Empty(context.Categories);
    }

    [Fact]
    public async Task DeleteAsync_RejectsCategoryContainingFoodItems()
    {
        await using var context = CreateContext();
        var category = new Category { Name = "Món chính", IsActive = true, CreatedAt = DateTime.UtcNow };
        context.Categories.Add(category);
        context.FoodItems.Add(new FoodItem
        {
            Category = category,
            Name = "Món A",
            Price = 10000,
            IsAvailable = true,
            CreatedAt = DateTime.UtcNow,
        });
        await context.SaveChangesAsync();
        var service = new AdminCategoryService(context);

        var result = await service.DeleteAsync(category.CategoryId, CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal("category_has_food_items", result.ErrorCode);
    }

    private static FoodOrderingDbContext CreateContext() => new(
        new DbContextOptionsBuilder<FoodOrderingDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options);
}
