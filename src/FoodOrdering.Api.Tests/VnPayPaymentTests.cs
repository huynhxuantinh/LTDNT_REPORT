using System.Net;
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

public sealed class VnPayPaymentTests
{
    private readonly VnPayOptions _options = new()
    {
        TmnCode = "DEMOVNPAY",
        HashSecret = "SECRETKEYVNPAYDEMO1234567890ABCD",
        BaseUrl = "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html",
        ReturnUrl = "http://localhost:5000/api/orders/vnpay-return"
    };

    private static (FoodOrderingDbContext db, PaymentsController controller, Guid userId) CreateController(VnPayOptions vnPayOptions, string role = "Member")
    {
        var db = new FoodOrderingDbContext(
            new DbContextOptionsBuilder<FoodOrderingDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .Options);

        var userId = Guid.NewGuid();
        var controller = new PaymentsController(db, new VietQrOptions(), vnPayOptions);

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
    public async Task GetVnPayUrl_GeneratesValidUrlWithHmacSha512Hash()
    {
        var (db, controller, userId) = CreateController(_options);
        var order = new FoodOrder
        {
            OrderId = 500,
            OrderCode = "DLV-VNPAY-001",
            UserId = userId,
            OrderStatusId = 1,
            OrderType = "Delivery",
            TotalAmount = 250000m,
            PaymentStatus = "Unpaid",
            CreatedAt = DateTime.UtcNow
        };
        db.Orders.Add(order);
        await db.SaveChangesAsync();

        var result = await controller.GetVnPayUrl(500, CancellationToken.None);

        var okResult = Assert.IsType<OkObjectResult>(result);
        var dto = Assert.IsType<VnPayPaymentDto>(okResult.Value);

        Assert.Equal(500, dto.OrderId);
        Assert.Equal("DLV-VNPAY-001", dto.OrderCode);
        Assert.Equal(250000m, dto.Amount);
        Assert.StartsWith(_options.BaseUrl, dto.PaymentUrl);
        Assert.Contains("vnp_Amount=25000000", dto.PaymentUrl);
        Assert.Contains("vnp_TxnRef=500", dto.PaymentUrl);
        Assert.Contains("vnp_SecureHash=", dto.PaymentUrl);

        // Kiểm tra chữ ký tính ra từ URL có hợp lệ không
        var uri = new Uri(dto.PaymentUrl);
        var queryParams = System.Web.HttpUtility.ParseQueryString(uri.Query);
        var dict = queryParams.AllKeys.Where(k => k != null).ToDictionary(k => k!, k => queryParams[k]!);

        Assert.True(VnPayHelper.ValidateSignature(dict, _options.HashSecret));

        // Kiểm tra bản ghi Payment
        var payment = await db.Payments.SingleOrDefaultAsync(p => p.OrderId == 500 && p.Method == "VNPay");
        Assert.NotNull(payment);
        Assert.Equal("Pending", payment.Status);
    }

    [Fact]
    public async Task VnPayReturn_WithSuccessCode_UpdatesOrderAndPaymentToPaid()
    {
        var (db, controller, userId) = CreateController(_options);
        var order = new FoodOrder
        {
            OrderId = 600,
            OrderCode = "DLV-VNPAY-002",
            UserId = userId,
            OrderStatusId = 1,
            OrderType = "Delivery",
            TotalAmount = 100000m,
            PaymentStatus = "Unpaid",
            CreatedAt = DateTime.UtcNow
        };
        db.Orders.Add(order);
        await db.SaveChangesAsync();

        // Tạo param callback giả lập từ VNPay trả về
        var callbackParams = new SortedDictionary<string, string>(StringComparer.Ordinal)
        {
            ["vnp_Amount"] = "10000000",
            ["vnp_BankCode"] = "NCB",
            ["vnp_OrderInfo"] = "Thanh toan don hang DLV-VNPAY-002",
            ["vnp_ResponseCode"] = "00", // Thành công
            ["vnp_TmnCode"] = _options.TmnCode,
            ["vnp_TransactionNo"] = "14000123",
            ["vnp_TxnRef"] = "600"
        };

        // Tính hash đúng theo quy tắc
        var rawData = string.Join('&', callbackParams.Select(x => $"{WebUtility.UrlEncode(x.Key)}={WebUtility.UrlEncode(x.Value)}"));
        var secureHash = VnPayHelper.HmacSha512(_options.HashSecret, rawData);
        callbackParams["vnp_SecureHash"] = secureHash;

        // Giả lập HttpContext query
        var queryCollection = new QueryCollection(callbackParams.ToDictionary(k => k.Key, v => new Microsoft.Extensions.Primitives.StringValues(v.Value)));
        controller.ControllerContext.HttpContext.Request.Query = queryCollection;

        var actionResult = await controller.VnPayReturn(CancellationToken.None);
        var contentResult = Assert.IsType<ContentResult>(actionResult);
        Assert.Contains("Thanh toán VNPay thành công", contentResult.Content);

        var updatedOrder = await db.Orders.FindAsync([600L]);
        Assert.NotNull(updatedOrder);
        Assert.Equal("Paid", updatedOrder.PaymentStatus);

        var payment = await db.Payments.SingleOrDefaultAsync(p => p.OrderId == 600 && p.Method == "VNPay");
        Assert.NotNull(payment);
        Assert.Equal("Paid", payment.Status);
        Assert.Equal("14000123", payment.ProviderTxnCode);
    }

    [Fact]
    public async Task SimulateVnPaySuccess_UpdatesOrderToPaid()
    {
        var (db, controller, userId) = CreateController(_options);
        var order = new FoodOrder
        {
            OrderId = 700,
            OrderCode = "DLV-VNPAY-003",
            UserId = userId,
            OrderStatusId = 1,
            OrderType = "Delivery",
            TotalAmount = 180000m,
            PaymentStatus = "Unpaid",
            CreatedAt = DateTime.UtcNow
        };
        db.Orders.Add(order);
        await db.SaveChangesAsync();

        var result = await controller.SimulateVnPaySuccess(700, CancellationToken.None);
        Assert.IsType<OkObjectResult>(result);

        var updatedOrder = await db.Orders.FindAsync([700L]);
        Assert.NotNull(updatedOrder);
        Assert.Equal("Paid", updatedOrder.PaymentStatus);
    }
}

