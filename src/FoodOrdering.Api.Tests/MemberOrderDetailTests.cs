using System.Security.Claims;
using System.Text.Json;
using FoodOrdering.Api.Controllers;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace FoodOrdering.Api.Tests;

public sealed class MemberOrderDetailTests
{
    [Fact]
    public async Task DetailContainsDeliveryInformationOnlyForOwner()
    {
        await using var db = new FoodOrderingDbContext(new DbContextOptionsBuilder<FoodOrderingDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        var owner = Guid.NewGuid();
        db.OrderStatuses.Add(new OrderStatus { OrderStatusId = 1, Name = "Pending" });
        db.Orders.Add(new FoodOrder { OrderId = 1, UserId = owner, OrderCode = "DH1", OrderType = "Delivery", OrderStatusId = 1, ReceiverName = "An", ReceiverPhone = "0912345678", DeliveryAddress = "Hà Nội", Note = "Gọi trước", PaymentStatus = "Unpaid" });
        await db.SaveChangesAsync();
        var controller = new MemberOrdersController(db);
        void SetUser(Guid id) => controller.ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext { User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, id.ToString())], "test")) } };
        SetUser(owner);
        var result = Assert.IsType<OkObjectResult>(await controller.Get(1, CancellationToken.None));
        var data = JsonSerializer.SerializeToElement(result.Value);
        Assert.Equal("An", data.GetProperty("ReceiverName").GetString());
        Assert.Equal("0912345678", data.GetProperty("ReceiverPhone").GetString());
        Assert.Equal("Hà Nội", data.GetProperty("DeliveryAddress").GetString());
        Assert.Equal("Gọi trước", data.GetProperty("Note").GetString());
        SetUser(Guid.NewGuid());
        Assert.IsType<NotFoundResult>(await controller.Get(1, CancellationToken.None));
    }
}
