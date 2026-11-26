using System.Security.Claims;
using FoodOrdering.Api.Carts;
using FoodOrdering.Api.Common;
using FoodOrdering.Api.Controllers;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Xunit;

namespace FoodOrdering.Api.Tests;

public sealed class QuantityValidationTests
{
    private static FoodOrderingDbContext CreateDb() => new(new DbContextOptionsBuilder<FoodOrderingDbContext>()
        .UseInMemoryDatabase(Guid.NewGuid().ToString())
        .ConfigureWarnings(w => w.Ignore(InMemoryEventId.TransactionIgnoredWarning)).Options);

    [Theory]
    [InlineData(-1)]
    [InlineData(0)]
    [InlineData(100)]
    [InlineData(int.MaxValue)]
    public async Task StaffOrderRejectsOutOfRangeQuantityBeforeTouchingTable(int quantity)
    {
        await using var db = CreateDb();
        db.DiningTables.Add(new DiningTable { TableId = 1, TableCode = "B01", Status = "Available" });
        await db.SaveChangesAsync();
        var result = await new StaffOrdersController(db).Create(new("DineIn", 1, [new(1, quantity)]), CancellationToken.None);
        var bad = Assert.IsType<BadRequestObjectResult>(result);
        Assert.Equal("invalid_quantity", Assert.IsType<ApiErrorResponse>(bad.Value).Error.Code);
        Assert.Equal("Available", (await db.DiningTables.FindAsync(1))!.Status);
        Assert.Empty(db.Orders);
    }

    [Fact]
    public async Task StaffOrderRejectsDuplicateFoodLines()
    {
        await using var db = CreateDb();
        var result = await new StaffOrdersController(db).Create(new("TakeAway", null, [new(1, 60), new(1, 60)]), CancellationToken.None);
        Assert.Equal("duplicate_food", Assert.IsType<ApiErrorResponse>(Assert.IsType<BadRequestObjectResult>(result).Value).Error.Code);
        Assert.Empty(db.Orders);
    }

    [Theory]
    [InlineData(1)]
    [InlineData(99)]
    public async Task StaffOrderAcceptsBoundaryQuantities(int quantity)
    {
        await using var db = CreateDb();
        db.FoodItems.Add(new FoodItem { FoodItemId = 1, CategoryId = 1, Name = "Món", Price = 10000, IsAvailable = true });
        await db.SaveChangesAsync();
        var controller = new StaffOrdersController(db) { ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext {
            User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, Guid.NewGuid().ToString())])) } } };
        Assert.IsType<OkObjectResult>(await controller.Create(new("TakeAway", null, [new(1, quantity)]), CancellationToken.None));
        Assert.Equal(quantity, Assert.Single(db.OrderDetails).Quantity);
    }

    [Fact]
    public async Task CartAddRejectsInvalidAndExcessTotalWithoutChangingCart()
    {
        await using var db = CreateDb();
        db.FoodItems.Add(new FoodItem { FoodItemId = 1, CategoryId = 1, Name = "Món", Price = 10000, IsAvailable = true });
        await db.SaveChangesAsync();
        var user = Guid.NewGuid();
        var service = new CartService(db);
        Assert.Equal("quantity_limit", (await service.AddAsync(user, 1, 0, CancellationToken.None)).ErrorCode);
        Assert.Equal("quantity_limit", (await service.AddAsync(user, 1, 100, CancellationToken.None)).ErrorCode);
        Assert.True((await service.AddAsync(user, 1, 98, CancellationToken.None)).IsSuccess);
        Assert.True((await service.AddAsync(user, 1, 1, CancellationToken.None)).IsSuccess);
        Assert.Equal("quantity_limit", (await service.AddAsync(user, 1, 1, CancellationToken.None)).ErrorCode);
        Assert.Equal("quantity_limit", (await service.SetQuantityAsync(user, Assert.Single(db.CartItems).CartItemId, 100, CancellationToken.None)).ErrorCode);
        Assert.Equal("quantity_limit", (await service.ApplySyncAsync(user, Guid.NewGuid(), 1, "add", 100, CancellationToken.None)).ErrorCode);
        Assert.Equal("quantity_limit", (await service.ApplySyncAsync(user, Guid.NewGuid(), 1, "set", 0, CancellationToken.None)).ErrorCode);
        Assert.Equal(99, Assert.Single(db.CartItems).Quantity);

        var controller = new CartController(service) { ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext {
            User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, user.ToString())])) } } };
        var response = await controller.Add(new AddCartItemRequest(1, 1), CancellationToken.None);
        Assert.Equal("quantity_limit", Assert.IsType<ApiErrorResponse>(Assert.IsType<BadRequestObjectResult>(response.Result).Value).Error.Code);
        Assert.Equal(99, Assert.Single(db.CartItems).Quantity);
    }
}
