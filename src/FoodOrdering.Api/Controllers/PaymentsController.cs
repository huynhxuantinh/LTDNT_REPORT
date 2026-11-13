using FoodOrdering.Api.Common;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FoodOrdering.Api.Controllers;

[ApiController, Route("api/orders"), Authorize(Roles = "Admin,Staff")]
public sealed class PaymentsController(FoodOrderingDbContext db) : ControllerBase
{
    [HttpPost("{orderId:long}/collect-cash")]
    public async Task<IActionResult> CollectCash(long orderId, CancellationToken ct)
    {
        var order = await db.Orders.SingleOrDefaultAsync(x => x.OrderId == orderId, ct);
        if (order is null) return NotFound(ApiErrorResponse.Create("order_not_found", "Không tìm thấy đơn hàng."));
        if (order.PaymentStatus == "Paid") return Conflict(ApiErrorResponse.Create("order_already_paid", "Đơn hàng đã thanh toán."));
        order.PaymentStatus = "Paid"; order.UpdatedAt = DateTime.UtcNow;
        if (order.OrderType == "DineIn" && order.TableId is int tableId) { var table = await db.DiningTables.FindAsync([tableId], ct); if (table is not null) { table.Status = "Available"; table.UpdatedAt = DateTime.UtcNow; } }
        db.Payments.Add(new Payment { OrderId = orderId, Method = "Cash", Status = "Paid", Amount = order.TotalAmount, PaidAt = DateTime.UtcNow, CreatedAt = DateTime.UtcNow });
        await db.SaveChangesAsync(ct);
        return Ok(new { orderId, paymentStatus = order.PaymentStatus });
    }
}
