using System.Security.Claims;
using FoodOrdering.Api.Carts;
using FoodOrdering.Api.Common;
using FoodOrdering.Api.Controllers;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.FoodItems;
using FoodOrdering.Api.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Xunit;

namespace FoodOrdering.Api.Tests;

public sealed class OrderingRegressionTests
{
    private static FoodOrderingDbContext CreateDb() => new(new DbContextOptionsBuilder<FoodOrderingDbContext>()
        .UseInMemoryDatabase(Guid.NewGuid().ToString())
        .ConfigureWarnings(w => w.Ignore(InMemoryEventId.TransactionIgnoredWarning)).Options);

    [Fact]
    public async Task PriceChangeRequiresReviewBeforeCreatingOrderAtNewPrice()
    {
        await using var db = CreateDb();
        var food = new FoodItem { Name = "Phở", Price = 20000, IsAvailable = true };
        db.FoodItems.Add(food);
        await db.SaveChangesAsync();
        var user = Guid.NewGuid();
        var service = new CartService(db);
        await service.AddAsync(user, food.FoodItemId, 2, CancellationToken.None);
        food.Price = 30000;
        await db.SaveChangesAsync();
        Assert.Equal(60000, (await service.GetAsync(user, CancellationToken.None)).TotalAmount);
        var first = await service.CheckoutAsync(user, "An", "0123", "Địa chỉ", null, CancellationToken.None);
        Assert.Equal("cart_price_changed", first.ErrorCode);
        Assert.Empty(db.Orders);
        Assert.Single(db.CartItems);
        var second = await service.CheckoutAsync(user, "An", "0123", "Địa chỉ", null, CancellationToken.None);
        Assert.True(second.IsSuccess);
        var order = Assert.Single(db.Orders);
        Assert.Equal(60000, order.TotalAmount);
        Assert.Equal(30000, Assert.Single(order.OrderDetails).UnitPrice);
        Assert.Empty(db.CartItems);
    }

    [Fact]
    public async Task FoodInCartCannotBeDeletedButCanBeHiddenAndRestored()
    {
        await using var db = CreateDb();
        var category = new Category { Name = "Món", IsActive = true };
        var food = new FoodItem { Name = "Phở", Category = category, Price = 10000, IsAvailable = true };
        db.FoodItems.Add(food);
        await db.SaveChangesAsync();
        var user = Guid.NewGuid();
        await new CartService(db).AddAsync(user, food.FoodItemId, 1, CancellationToken.None);
        var service = new AdminFoodItemService(db);
        Assert.Equal("food_in_carts", (await service.DeleteAsync(food.FoodItemId, CancellationToken.None)).ErrorCode);
        Assert.True((await service.HideAsync(food.FoodItemId, CancellationToken.None)).IsSuccess);
        Assert.False(food.IsAvailable);
        var checkout = await new CartService(db).CheckoutAsync(user, "An", "0123", "Địa chỉ", null, CancellationToken.None);
        Assert.Equal("food_not_available", checkout.ErrorCode);
        Assert.True((await service.RestoreAsync(food.FoodItemId, CancellationToken.None)).IsSuccess);
        Assert.True(food.IsAvailable);
        category.IsActive = false;
        await db.SaveChangesAsync();
        Assert.Equal("category_inactive", (await service.RestoreAsync(food.FoodItemId, CancellationToken.None)).ErrorCode);
    }

    [Fact]
    public async Task TableWithClosedOrderIsRejectedWithoutDeletingHistory()
    {
        await using var db = CreateDb();
        var table = new DiningTable { TableCode = "B01", Status = "Available" };
        var status = new OrderStatus { Name = "Completed" };
        db.Orders.Add(new FoodOrder { OrderCode = "O1", OrderType = "DineIn", PaymentStatus = "Paid", DiningTable = table, OrderStatus = status });
        await db.SaveChangesAsync();
        var result = await new DiningTablesController(db).Delete(table.TableId, CancellationToken.None);
        var conflict = Assert.IsType<ConflictObjectResult>(result);
        Assert.Equal("table_has_order_history", Assert.IsType<ApiErrorResponse>(conflict.Value).Error.Code);
        Assert.Single(db.Orders);
        Assert.Single(db.DiningTables);
    }

    [Fact]
    public async Task StaffCanProcessAnotherStaffsOfflineOrderButNotDelivery()
    {
        await using var db = CreateDb();
        var pending = new OrderStatus { Name = "Pending", OrderStatusId = 1 };
        var confirmed = new OrderStatus { Name = "Confirmed", OrderStatusId = 2 };
        var creator = Guid.NewGuid(); var actor = Guid.NewGuid();
        db.Users.Add(new User { UserId = creator, FullName = "Nhân viên", Email = "staff@example.com", PasswordHash = "hash" });
        db.OrderStatuses.AddRange(pending, confirmed);
        db.Orders.AddRange(
            new FoodOrder { OrderCode = "OFF-1", PaymentStatus = "Unpaid", UserId = creator, OrderType = "TakeAway", OrderStatus = pending },
            new FoodOrder { OrderCode = "DLV-1", PaymentStatus = "Unpaid", UserId = creator, OrderType = "Delivery", OrderStatus = pending });
        await db.SaveChangesAsync();
        var controller = new StaffOrdersController(db) { ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext { User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, actor.ToString())])) } } };
        var offline = db.Orders.Single(o => o.OrderCode == "OFF-1");
        var delivery = db.Orders.Single(o => o.OrderCode == "DLV-1");
        var list = Assert.IsType<OkObjectResult>(await controller.Get(CancellationToken.None));
        Assert.Single(Assert.IsAssignableFrom<System.Collections.IEnumerable>(list.Value).Cast<object>());
        Assert.IsType<OkObjectResult>(await controller.Status(offline.OrderId, new("Confirmed"), CancellationToken.None));
        Assert.Equal(actor, Assert.Single(db.OrderStatusHistories).UpdatedByUserId);
        Assert.IsType<NotFoundResult>(await controller.Status(delivery.OrderId, new("Confirmed"), CancellationToken.None));
    }

    [Fact]
    public async Task AdminDateFilterUsesVietnamCalendarBoundaries()
    {
        await using var db = CreateDb();
        var status = new OrderStatus { Name = "Pending" };
        db.Orders.AddRange(new[] {
            new DateTime(2026, 7, 1, 16, 59, 59, DateTimeKind.Utc),
            new DateTime(2026, 7, 1, 17, 0, 0, DateTimeKind.Utc),
            new DateTime(2026, 7, 2, 16, 59, 59, DateTimeKind.Utc),
            new DateTime(2026, 7, 2, 17, 0, 0, DateTimeKind.Utc),
        }.Select((time, i) => new FoodOrder { OrderCode = $"O{i}", OrderType = "Delivery", PaymentStatus = "Unpaid", OrderStatus = status, CreatedAt = time }));
        await db.SaveChangesAsync();
        var result = await new AdminOrdersController(db).GetAll(new PageRequest(1, 20), null, new DateTime(2026, 7, 2), new DateTime(2026, 7, 2), null, null, null, CancellationToken.None);
        var body = Assert.IsType<PagedResponse<object>>(Assert.IsType<OkObjectResult>(result.Result).Value);
        Assert.Equal(2, body.Meta.TotalItems);
    }
}
