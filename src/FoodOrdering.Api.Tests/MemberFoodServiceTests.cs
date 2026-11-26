using FoodOrdering.Api.Common;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.FoodItems;
using FoodOrdering.Api.Models;
using FoodOrdering.Api.Controllers;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace FoodOrdering.Api.Tests;

public sealed class MemberFoodServiceTests
{
    [Fact]
    public async Task RelatedExcludesCurrentFoodBeforeCountingAndPaging()
    {
        await using var context = new FoodOrderingDbContext(new DbContextOptionsBuilder<FoodOrderingDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        var category = new Category { Name = "Món chính", IsActive = true };
        var otherCategory = new Category { Name = "Đồ uống", IsActive = true };
        var current = new FoodItem { Category = category, Name = "Món đang xem", Price = 1, IsAvailable = true, CreatedAt = new DateTime(2026, 1, 2) };
        context.FoodItems.Add(current);
        for (var i = 0; i < 6; i++) context.FoodItems.Add(new FoodItem { Category = category, Name = $"Món {i}", Price = 1, IsAvailable = true, CreatedAt = new DateTime(2026, 1, 1) });
        context.FoodItems.Add(new FoodItem { Category = category, Name = "Đã ẩn", Price = 1, IsAvailable = false });
        context.FoodItems.Add(new FoodItem { Category = otherCategory, Name = "Nước", Price = 1, IsAvailable = true });
        await context.SaveChangesAsync();
        var controller = new FoodsController(new MemberFoodService(context));
        var result1 = await controller.Related(current.FoodItemId, new PageRequest(1, 3), CancellationToken.None);
        var result2 = await controller.Related(current.FoodItemId, new PageRequest(2, 3), CancellationToken.None);
        var first = Assert.IsType<PagedResponse<MemberFoodItem>>(Assert.IsType<OkObjectResult>(result1.Result).Value);
        var second = Assert.IsType<PagedResponse<MemberFoodItem>>(Assert.IsType<OkObjectResult>(result2.Result).Value);
        Assert.Equal(6, first.Meta.TotalItems);
        Assert.Equal(2, first.Meta.TotalPages);
        Assert.Equal(3, first.Data.Count);
        Assert.Equal(3, second.Data.Count);
        Assert.DoesNotContain(first.Data.Concat(second.Data), x => x.FoodItemId == current.FoodItemId || x.Name is "Đã ẩn" or "Nước");
        Assert.Equal(6, first.Data.Concat(second.Data).Select(x => x.FoodItemId).Distinct().Count());
        var missing = await controller.Related(9999, new PageRequest(1, 3), CancellationToken.None);
        Assert.IsType<NotFoundResult>(missing.Result);
    }

    [Fact]
    public async Task GetAllAsync_ReturnsNewestFoodFirstWithPagination()
    {
        await using var context = new FoodOrderingDbContext(
            new DbContextOptionsBuilder<FoodOrderingDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .Options);
        var category = new Category { Name = "Món chính", IsActive = true, CreatedAt = DateTime.UtcNow };
        context.Categories.Add(category);
        context.FoodItems.AddRange(
            new FoodItem { Category = category, Name = "Món cũ", Price = 30000, IsAvailable = true, CreatedAt = DateTime.UtcNow.AddDays(-1) },
            new FoodItem { Category = category, Name = "Món mới", Price = 40000, IsAvailable = true, CreatedAt = DateTime.UtcNow });
        await context.SaveChangesAsync();
        var service = new MemberFoodService(context);

        var result = await service.GetAllAsync(new PageRequest(1, 1), null, null, CancellationToken.None);

        Assert.Single(result.Data);
        Assert.Equal("Món mới", result.Data[0].Name);
        Assert.Equal(2, result.Meta.TotalItems);
        Assert.Equal(2, result.Meta.TotalPages);
    }

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
