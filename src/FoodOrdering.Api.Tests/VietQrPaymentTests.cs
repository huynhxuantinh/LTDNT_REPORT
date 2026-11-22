using System.Security.Claims;
using FoodOrdering.Api.Common;
using FoodOrdering.Api.Controllers;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace FoodOrdering.Api.Tests;

public sealed class VietQrPaymentTests
{
    private readonly VietQrOptions _options = new()
    {
        BankId = "MB",
        AccountNo = "0987654321",
        AccountName = "QUAN AN DEMO",
        Template = "compact2"
    };

    private static (FoodOrderingDbContext db, PaymentsController controller, Guid userId) CreateController(VietQrOptions options, string role = "Member")
    {
        var db = new FoodOrderingDbContext(
            new DbContextOptionsBuilder<FoodOrderingDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .Options);

        var userId = Guid.NewGuid();
        var controller = new PaymentsController(db, options, new VnPayOptions());

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, userId.ToString()),
            new(ClaimTypes.Role, role)
        };
        var identity = new ClaimsIdentity(claims, "TestAuth");
        var principal = new ClaimsPrincipal(identity);

        controller.ControllerContext = new ControllerContext
        {
            HttpContext = new DefaultHttpContext { User = principal }
        };

        return (db, controller, userId);
    }

    [Fact]
    public async Task GetVietQr_ReturnsValidQrUrl_AndCreatesPendingPayment()
    {
        var (db, controller, userId) = CreateController(_options);
        var order = new FoodOrder
        {
            OrderId = 100,
            OrderCode = "DLV-20261122001",
            UserId = userId,
            OrderStatusId = 1,
            OrderType = "Delivery",
            TotalAmount = 150000m,
            PaymentStatus = "Unpaid",
            CreatedAt = DateTime.UtcNow
        };
        db.Orders.Add(order);
        await db.SaveChangesAsync();

        var result = await controller.GetVietQr(100, CancellationToken.None);

        var okResult = Assert.IsType<OkObjectResult>(result);
        var dto = Assert.IsType<VietQrPaymentDto>(okResult.Value);

        Assert.Equal(100, dto.OrderId);
        Assert.Equal("DLV-20261122001", dto.OrderCode);
        Assert.Equal(150000m, dto.Amount);
        Assert.Equal("MB", dto.BankId);
        Assert.Equal("0987654321", dto.AccountNo);
        Assert.Equal("DLV-20261122001", dto.TransferContent);
        Assert.Contains("img.vietqr.io/image/MB-0987654321-compact2.png", dto.QrImageUrl);
        Assert.Contains("amount=150000", dto.QrImageUrl);
        Assert.Contains("DLV-20261122001", dto.QrImageUrl);

        var payment = await db.Payments.SingleOrDefaultAsync(p => p.OrderId == 100 && p.Method == "VietQR");
        Assert.NotNull(payment);
        Assert.Equal("Pending", payment.Status);
        Assert.Equal(150000m, payment.Amount);
    }

    [Fact]
    public async Task ConfirmVietQr_UpdatesOrderAndPaymentToPaid()
    {
        var (db, controller, userId) = CreateController(_options);
        var order = new FoodOrder
        {
            OrderId = 200,
            OrderCode = "DLV-20261122002",
            UserId = userId,
            OrderStatusId = 1,
            OrderType = "Delivery",
            TotalAmount = 200000m,
            PaymentStatus = "Unpaid",
            CreatedAt = DateTime.UtcNow
        };
        db.Orders.Add(order);
        await db.SaveChangesAsync();

        // Khách lấy mã trước
        await controller.GetVietQr(200, CancellationToken.None);

        // Xác nhận thanh toán
        var result = await controller.ConfirmVietQr(200, CancellationToken.None);

        var okResult = Assert.IsType<OkObjectResult>(result);
        Assert.NotNull(okResult.Value);

        var updatedOrder = await db.Orders.FindAsync([200L]);
        Assert.NotNull(updatedOrder);
        Assert.Equal("Paid", updatedOrder.PaymentStatus);

        var payment = await db.Payments.SingleOrDefaultAsync(p => p.OrderId == 200 && p.Method == "VietQR");
        Assert.NotNull(payment);
        Assert.Equal("Paid", payment.Status);
        Assert.NotNull(payment.PaidAt);
    }

    [Fact]
    public async Task ConfirmVietQr_WhenDineIn_ReleasesTable()
    {
        var (db, controller, userId) = CreateController(_options, role: "Staff");
        var table = new DiningTable
        {
            TableId = 5,
            TableCode = "B05",
            Capacity = 4,
            Status = "Occupied",
            CreatedAt = DateTime.UtcNow
        };
        db.DiningTables.Add(table);

        var order = new FoodOrder
        {
            OrderId = 300,
            OrderCode = "OFF-20261122003",
            UserId = userId,
            OrderStatusId = 1,
            OrderType = "DineIn",
            TableId = 5,
            TotalAmount = 300000m,
            PaymentStatus = "Unpaid",
            CreatedAt = DateTime.UtcNow
        };
        db.Orders.Add(order);
        await db.SaveChangesAsync();

        var result = await controller.ConfirmVietQr(300, CancellationToken.None);
        Assert.IsType<OkObjectResult>(result);

        var updatedTable = await db.DiningTables.FindAsync([5]);
        Assert.NotNull(updatedTable);
        Assert.Equal("Available", updatedTable.Status);
    }
}
