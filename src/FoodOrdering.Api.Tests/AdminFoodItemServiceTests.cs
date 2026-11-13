using FoodOrdering.Api.Common;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.FoodItems;
using FoodOrdering.Api.Models;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace FoodOrdering.Api.Tests;

public sealed class AdminFoodItemServiceTests
{
    [Fact]
    public async Task GetAllAsync_FiltersByCategoryAndSearchWithPagination()
    {
        await using var context = new FoodOrderingDbContext(
            new DbContextOptionsBuilder<FoodOrderingDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .Options);
        var main = new Category { Name = "Món chính", IsActive = true, CreatedAt = DateTime.UtcNow };
        var drinks = new Category { Name = "Đồ uống", IsActive = true, CreatedAt = DateTime.UtcNow };
        context.Categories.AddRange(main, drinks);
        context.FoodItems.AddRange(
            Food(main, "Cơm Gà", DateTime.UtcNow.AddMinutes(-2)),
            Food(main, "Gà rán", DateTime.UtcNow.AddMinutes(-1)),
            Food(drinks, "Trà đào", DateTime.UtcNow));
        await context.SaveChangesAsync();
        var service = new AdminFoodItemService(context);

        var result = await service.GetAllAsync(new PageRequest(1, 1), main.CategoryId, "Gà", CancellationToken.None);

        Assert.Single(result.Data);
        Assert.Equal(2, result.Meta.TotalItems);
        Assert.Equal(2, result.Meta.TotalPages);
        Assert.Equal("Gà rán", result.Data[0].Name);
        Assert.Equal("Món chính", result.Data[0].CategoryName);
    }

    [Fact]
    public async Task CreateAsync_AddsFoodItemWithUploadedImageUrl()
    {
        await using var context = new FoodOrderingDbContext(
            new DbContextOptionsBuilder<FoodOrderingDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .Options);
        var category = new Category { Name = "Món chính", IsActive = true, CreatedAt = DateTime.UtcNow };
        context.Categories.Add(category);
        await context.SaveChangesAsync();
        var service = new AdminFoodItemService(context);

        var result = await service.CreateAsync(
            new CreateFoodItemData(category.CategoryId, "Cơm gà", "Mô tả", 55000, "/uploads/foods/food.jpg"),
            CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error);
        Assert.Equal("/uploads/foods/food.jpg", result.Value!.ImageUrl);
        Assert.Single(context.FoodItems);
    }

    [Fact]
    public async Task UpdateAsync_ReplacesFoodDataAndReturnsPreviousImageUrl()
    {
        await using var context = new FoodOrderingDbContext(
            new DbContextOptionsBuilder<FoodOrderingDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .Options);
        var category = new Category { Name = "Món chính", IsActive = true, CreatedAt = DateTime.UtcNow };
        context.Categories.Add(category);
        var food = Food(category, "Món cũ", DateTime.UtcNow);
        food.ImageUrl = "/uploads/foods/old.png";
        context.FoodItems.Add(food);
        await context.SaveChangesAsync();
        var service = new AdminFoodItemService(context);

        var result = await service.UpdateAsync(
            food.FoodItemId,
            new UpdateFoodItemData(category.CategoryId, "Món mới", "Mô tả mới", 65000, "/uploads/foods/new.png"),
            CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error);
        Assert.Equal("/uploads/foods/old.png", result.Value!.PreviousImageUrl);
        Assert.Equal("/uploads/foods/new.png", result.Value.Item.ImageUrl);
        Assert.Equal("Món mới", food.Name);
    }

    [Fact]
    public async Task DeleteAsync_HardDeletesFoodAndReturnsImageUrl()
    {
        await using var context = new FoodOrderingDbContext(
            new DbContextOptionsBuilder<FoodOrderingDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .Options);
        var category = new Category { Name = "Món chính", IsActive = true, CreatedAt = DateTime.UtcNow };
        context.Categories.Add(category);
        var food = Food(category, "Món xóa", DateTime.UtcNow);
        food.ImageUrl = "/uploads/foods/delete.png";
        context.FoodItems.Add(food);
        await context.SaveChangesAsync();
        var service = new AdminFoodItemService(context);

        var result = await service.DeleteAsync(food.FoodItemId, CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error);
        Assert.Equal("/uploads/foods/delete.png", result.Value);
        Assert.Empty(context.FoodItems);
    }

    [Fact]
    public async Task DeleteAsync_RejectsFoodIncludedInOrderDetails()
    {
        await using var context = new FoodOrderingDbContext(
            new DbContextOptionsBuilder<FoodOrderingDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .Options);
        var category = new Category { Name = "Món chính", IsActive = true, CreatedAt = DateTime.UtcNow };
        context.Categories.Add(category);
        var food = Food(category, "Món đã đặt", DateTime.UtcNow);
        context.FoodItems.Add(food);
        await context.SaveChangesAsync();
        context.OrderDetails.Add(new OrderDetail
        {
            OrderId = 1,
            FoodItemId = food.FoodItemId,
            FoodNameSnapshot = food.Name,
            UnitPrice = food.Price,
            Quantity = 1,
        });
        await context.SaveChangesAsync();
        var service = new AdminFoodItemService(context);

        var result = await service.DeleteAsync(food.FoodItemId, CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal("food_has_order_details", result.ErrorCode);
        Assert.Single(context.FoodItems);
    }

    [Fact]
    public async Task HideAsync_MarksFoodInOrderDetailsAsUnavailable()
    {
        await using var context = new FoodOrderingDbContext(
            new DbContextOptionsBuilder<FoodOrderingDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .Options);
        var category = new Category { Name = "Món chính", IsActive = true, CreatedAt = DateTime.UtcNow };
        context.Categories.Add(category);
        var food = Food(category, "Món cần ẩn", DateTime.UtcNow);
        context.FoodItems.Add(food);
        await context.SaveChangesAsync();
        context.OrderDetails.Add(new OrderDetail
        {
            OrderId = 1,
            FoodItemId = food.FoodItemId,
            FoodNameSnapshot = food.Name,
            UnitPrice = food.Price,
            Quantity = 1,
        });
        await context.SaveChangesAsync();
        var service = new AdminFoodItemService(context);

        var result = await service.HideAsync(food.FoodItemId, CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error);
        Assert.False(result.Value!.IsAvailable);
        Assert.False(food.IsAvailable);
    }

    private static FoodItem Food(Category category, string name, DateTime createdAt) => new()
    {
        Category = category,
        Name = name,
        Price = 10000,
        IsAvailable = true,
        CreatedAt = createdAt,
    };
}
