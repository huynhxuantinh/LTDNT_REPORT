using FoodOrdering.Api.Carts;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace FoodOrdering.Api.Tests;

public sealed class CartServiceTests
{
    private static FoodOrderingDbContext CreateContext() => new(new DbContextOptionsBuilder<FoodOrderingDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);

    [Fact]
    public async Task AddUpdateRemove_ChangesOnlyAuthenticatedUsersCart()
    {
        await using var db = CreateContext();
        db.FoodItems.Add(new FoodItem { FoodItemId = 1, CategoryId = 1, Name = "Food", Price = 25000, IsAvailable = true });
        await db.SaveChangesAsync();
        var owner = Guid.NewGuid(); var other = Guid.NewGuid(); var service = new CartService(db);
        var added = await service.AddAsync(owner, 1, 2, CancellationToken.None);
        Assert.True(added.IsSuccess);
        Assert.Equal(50000, added.Value!.TotalAmount);
        var id = Assert.Single(added.Value.Items).CartItemId;
        Assert.Empty((await service.GetAsync(other, CancellationToken.None)).Items);
        Assert.False((await service.SetQuantityAsync(other, id, 5, CancellationToken.None)).IsSuccess);
        Assert.False((await service.RemoveAsync(other, id, CancellationToken.None)).IsSuccess);
        var updated = await service.SetQuantityAsync(owner, id, 3, CancellationToken.None);
        Assert.Equal(3, updated.Value!.TotalQuantity);
        Assert.Equal(75000, updated.Value.TotalAmount);
        var removed = await service.RemoveAsync(owner, id, CancellationToken.None);
        Assert.Empty(removed.Value!.Items);
    }

    [Fact]
    public async Task Add_RejectsUnavailableFood()
    {
        await using var db = CreateContext();
        db.FoodItems.Add(new FoodItem { FoodItemId = 1, CategoryId = 1, Name = "Hidden", Price = 1000, IsAvailable = false });
        await db.SaveChangesAsync();
        var result = await new CartService(db).AddAsync(Guid.NewGuid(), 1, 1, CancellationToken.None);
        Assert.False(result.IsSuccess);
        Assert.Equal("food_not_available", result.ErrorCode);
        Assert.Empty(db.CartItems);
    }
}
