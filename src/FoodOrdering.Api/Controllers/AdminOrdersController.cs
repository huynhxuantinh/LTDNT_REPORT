using FoodOrdering.Api.Common;
using FoodOrdering.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace FoodOrdering.Api.Controllers;

public sealed record UpdateOrderStatusRequest(string Status);

[ApiController, Route("api/admin/orders"), Authorize(Roles = "Admin")]
public sealed class AdminOrdersController(FoodOrderingDbContext db) : ControllerBase
{
    [HttpGet("{orderId:long}")]
    public async Task<IActionResult> GetDetail(long orderId, CancellationToken ct)
    {
        var order = await db.Orders.AsNoTracking().Where(x => x.OrderId == orderId).Select(x => new { x.OrderId, x.OrderCode, x.ReceiverName, x.ReceiverPhone, x.DeliveryAddress, x.Note, x.TotalAmount, x.PaymentStatus, x.CreatedAt, x.UpdatedAt, Status = x.OrderStatus!.Name, Items = x.OrderDetails.Select(d => new { d.FoodNameSnapshot, d.ImageUrlSnapshot, d.UnitPrice, d.Quantity }), Payments = x.Payments.Select(p => new { p.Method, p.Status, p.Amount, p.ProviderTxnCode, p.PaidAt, p.CreatedAt }) }).SingleOrDefaultAsync(ct);
        if (order is null) return NotFound(ApiErrorResponse.Create("order_not_found", "Không tìm thấy đơn hàng."));
        var history = await db.OrderStatusHistories.AsNoTracking().Where(x => x.OrderId == orderId).OrderByDescending(x => x.CreatedAt).Select(x => new { x.OrderStatusId, x.UpdatedByUserId, x.CreatedAt }).ToListAsync(ct);
        return Ok(new { order, history });
    }
    [HttpPut("{orderId:long}/status")]
    public async Task<IActionResult> UpdateStatus(long orderId, UpdateOrderStatusRequest request, CancellationToken ct)
    {
        var order = await db.Orders.Include(x => x.OrderStatus).SingleOrDefaultAsync(x => x.OrderId == orderId, ct);
        if (order is null) return NotFound(ApiErrorResponse.Create("order_not_found", "Không tìm thấy đơn hàng."));
        var current = order.OrderStatus!.Name;
        var allowed = order.OrderType == "Delivery"
            ? new Dictionary<string, string[]> { ["Pending"]=["Confirmed","Cancelled"], ["Confirmed"]=["Preparing","Cancelled"], ["Preparing"]=["Delivering","Cancelled"], ["Delivering"]=["Completed","Cancelled"] }
            : new Dictionary<string, string[]> { ["Pending"]=["Confirmed","Cancelled"], ["Confirmed"]=["Preparing","Cancelled"], ["Preparing"]=["Completed","Cancelled"] };
        if (!allowed.TryGetValue(current, out var next) || !next.Contains(request.Status)) return Conflict(ApiErrorResponse.Create("invalid_status_transition", "Không thể chuyển trạng thái theo luồng hiện tại."));
        var status = await db.OrderStatuses.SingleOrDefaultAsync(x => x.Name == request.Status, ct);
        if (status is null) return BadRequest(ApiErrorResponse.Create("invalid_status", "Trạng thái không hợp lệ."));
        order.OrderStatusId = status.OrderStatusId; order.UpdatedAt = DateTime.UtcNow; db.OrderStatusHistories.Add(new FoodOrdering.Api.Models.OrderStatusHistory { OrderId = orderId, OrderStatusId = status.OrderStatusId, UpdatedByUserId = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!), CreatedAt = DateTime.UtcNow }); await db.SaveChangesAsync(ct);
        if (order.OrderType == "DineIn" && request.Status is "Completed" or "Cancelled" && order.TableId is int tableId) { var table = await db.DiningTables.FindAsync([tableId], ct); if (table is not null) { table.Status = "Available"; table.UpdatedAt = DateTime.UtcNow; await db.SaveChangesAsync(ct); } }
        return Ok(new { orderId, status = request.Status });
    }
    [HttpGet]
    public async Task<ActionResult<PagedResponse<object>>> GetAll([FromQuery] PageRequest request, [FromQuery] string? search, [FromQuery] DateTime? fromDate, [FromQuery] DateTime? toDate, [FromQuery] string? status, [FromQuery] string? orderType, [FromQuery] string? paymentStatus, CancellationToken ct)
    {
        var page=request.ValidPage; var size=request.ValidPageSize; var query=db.Orders.AsNoTracking();
        if (!string.IsNullOrWhiteSpace(search)) { var keyword=search.Trim(); query=query.Where(x=>x.OrderCode.Contains(keyword)||(x.ReceiverName??"").Contains(keyword)||(x.ReceiverPhone??"").Contains(keyword)); }
        if (fromDate.HasValue) query=query.Where(x=>x.CreatedAt>=fromDate.Value.Date);
        if (toDate.HasValue) query=query.Where(x=>x.CreatedAt<toDate.Value.Date.AddDays(1));
        if (!string.IsNullOrWhiteSpace(status)) query=query.Where(x=>x.OrderStatus!.Name==status);
        if (!string.IsNullOrWhiteSpace(orderType)) query=query.Where(x=>x.OrderType==orderType);
        if (!string.IsNullOrWhiteSpace(paymentStatus)) query=query.Where(x=>x.PaymentStatus==paymentStatus);
        var total=await query.CountAsync(ct);
        var data=await query.OrderByDescending(x=>x.CreatedAt).Skip((page-1)*size).Take(size).Select(x=>(object)new {x.OrderId,x.OrderCode,x.ReceiverName,x.ReceiverPhone,x.TotalAmount,x.PaymentStatus,x.CreatedAt,Status=x.OrderStatus!.Name}).ToListAsync(ct);
        return Ok(PagedResponse<object>.Create(data,page,size,total));
    }
}
