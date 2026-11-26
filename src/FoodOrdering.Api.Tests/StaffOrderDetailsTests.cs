using System.Security.Claims;
using System.Text.Json;
using FoodOrdering.Api.Controllers;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Xunit;

namespace FoodOrdering.Api.Tests;

public sealed class StaffOrderDetailsTests
{
    private static FoodOrderingDbContext CreateDb() => new(new DbContextOptionsBuilder<FoodOrderingDbContext>()
        .UseInMemoryDatabase(Guid.NewGuid().ToString())
        .ConfigureWarnings(w => w.Ignore(InMemoryEventId.TransactionIgnoredWarning)).Options);

    [Fact]
    public async Task DetailShowsTableCreatorAndHistoricalFoodPricesButRejectsDelivery()
    {
        await using var db = CreateDb();
        var user = new User { UserId = Guid.NewGuid(), FullName = "Nhân viên An", Email = "an@example.com", PasswordHash = "hash" };
        var table = new DiningTable { TableCode = "B01", Status = "Occupied" };
        var status = new OrderStatus { Name = "Pending" };
        var offline = new FoodOrder { OrderCode = "OFF-1", User = user, DiningTable = table, ReceiverName = "Khách Bình", OrderType = "DineIn", PaymentStatus = "Unpaid", OrderStatus = status, TotalAmount = 70000 };
        offline.OrderDetails.Add(new OrderDetail { FoodItemId = 1, FoodNameSnapshot = "Phở", UnitPrice = 35000, Quantity = 2 });
        var delivery = new FoodOrder { OrderCode = "DLV-1", User = user, OrderType = "Delivery", PaymentStatus = "Unpaid", OrderStatus = status };
        db.Orders.AddRange(offline, delivery);
        await db.SaveChangesAsync();

        var controller = new StaffOrdersController(db);
        var result = Assert.IsType<OkObjectResult>(await controller.GetDetail(offline.OrderId, CancellationToken.None));
        var json = JsonSerializer.SerializeToElement(result.Value, new JsonSerializerOptions(JsonSerializerDefaults.Web));
        Assert.Equal("B01", json.GetProperty("tableCode").GetString());
        Assert.Equal("Nhân viên An", json.GetProperty("createdBy").GetString());
        Assert.Equal("Khách Bình", json.GetProperty("receiverName").GetString());
        var item = Assert.Single(json.GetProperty("items").EnumerateArray());
        Assert.Equal("Phở", item.GetProperty("foodNameSnapshot").GetString());
        Assert.Equal(35000, item.GetProperty("unitPrice").GetDecimal());
        Assert.Equal(2, item.GetProperty("quantity").GetInt32());
        Assert.IsType<NotFoundObjectResult>(await controller.GetDetail(delivery.OrderId, CancellationToken.None));
    }

    [Fact]
    public async Task CreatingOfflineOrderStoresOptionalCustomerName()
    {
        await using var db = CreateDb();
        db.FoodItems.Add(new FoodItem { FoodItemId = 1, Name = "Phở", Price = 35000, IsAvailable = true });
        await db.SaveChangesAsync();
        var controller = new StaffOrdersController(db) { ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext {
            User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, Guid.NewGuid().ToString())])) } } };
        Assert.IsType<OkObjectResult>(await controller.Create(new("TakeAway", null, [new(1, 1)], "  Khách Bình  "), CancellationToken.None));
        Assert.Equal("Khách Bình", Assert.Single(db.Orders).ReceiverName);
    }
}
