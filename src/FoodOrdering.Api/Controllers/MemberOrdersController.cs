using System.Security.Claims;
using FoodOrdering.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FoodOrdering.Api.Controllers;

[ApiController, Route("api/orders"), Authorize]
public sealed class MemberOrdersController(FoodOrderingDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetAll(CancellationToken ct) { var userId=Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!); return Ok(await db.Orders.AsNoTracking().Where(x=>x.UserId==userId).OrderByDescending(x=>x.CreatedAt).Select(x=>new {x.OrderId,x.OrderCode,x.TotalAmount,x.PaymentStatus,x.CreatedAt,Status=x.OrderStatus!.Name}).ToListAsync(ct)); }
    [HttpGet("{orderId:long}")]
    public async Task<IActionResult> Get(long orderId,CancellationToken ct) { var userId=Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!); var order=await db.Orders.AsNoTracking().Where(x=>x.OrderId==orderId&&x.UserId==userId).Select(x=>new {x.OrderId,x.OrderCode,x.TotalAmount,x.PaymentStatus,x.CreatedAt,Status=x.OrderStatus!.Name,Items=x.OrderDetails.Select(d=>new {d.FoodNameSnapshot,d.UnitPrice,d.Quantity})}).SingleOrDefaultAsync(ct); return order is null?NotFound():Ok(order); }
}
