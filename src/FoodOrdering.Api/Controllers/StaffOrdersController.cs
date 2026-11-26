using System.Security.Claims;
using System.Data;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using FoodOrdering.Api.Common;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
namespace FoodOrdering.Api.Controllers;
public sealed record StaffOrderLine(int FoodItemId,int Quantity);
public sealed record CreateStaffOrderRequest(string OrderType,int? TableId,List<StaffOrderLine> Items);
[ApiController,Route("api/staff/orders"),Authorize(Roles="Admin,Staff")]
public sealed class StaffOrdersController(FoodOrderingDbContext db):ControllerBase{
 [HttpPut("{id:long}/status")]
 public async Task<IActionResult> Status(long id, UpdateOrderStatusRequest request, CancellationToken ct)
 {
   var user=Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
   var order=await db.Orders.Include(x=>x.OrderStatus).SingleOrDefaultAsync(x=>x.OrderId==id && (x.OrderType=="DineIn" || x.OrderType=="TakeAway"),ct);
   if(order is null) return NotFound();
   var allowed=order.OrderStatus!.Name switch { "Pending" => new[]{"Confirmed","Cancelled"}, "Confirmed" => new[]{"Preparing","Cancelled"}, "Preparing" => new[]{"Completed","Cancelled"}, _ => Array.Empty<string>() };
   if(!allowed.Contains(request.Status)) return Conflict();
   var status=await db.OrderStatuses.SingleAsync(x=>x.Name==request.Status,ct);
   order.OrderStatusId=status.OrderStatusId; order.UpdatedAt=DateTime.UtcNow;
   db.OrderStatusHistories.Add(new OrderStatusHistory { OrderId=id, OrderStatusId=status.OrderStatusId, UpdatedByUserId=user, CreatedAt=DateTime.UtcNow });
   if(order.OrderType=="DineIn" && request.Status=="Cancelled" && order.PaymentStatus!="Paid" && order.TableId is int tableId) { var table=await db.DiningTables.FindAsync([tableId],ct); if(table is not null){table.Status="Available"; table.UpdatedAt=DateTime.UtcNow;} }
   await db.SaveChangesAsync(ct); return Ok(new { orderId=id, status=request.Status });
 }
 [HttpGet] public async Task<IActionResult> Get(CancellationToken ct){return Ok(await db.Orders.AsNoTracking().Where(x=>x.OrderType=="DineIn"||x.OrderType=="TakeAway").OrderByDescending(x=>x.CreatedAt).Select(x=>new{x.OrderId,x.OrderCode,x.OrderType,x.PaymentStatus,Status=x.OrderStatus!.Name,x.TotalAmount}).ToListAsync(ct));}
 [HttpPost]
 public async Task<IActionResult> Create(CreateStaffOrderRequest r, CancellationToken ct)
 {
   if (r.OrderType is not ("DineIn" or "TakeAway") || r.Items is null || r.Items.Count == 0)
     return BadRequest(ApiErrorResponse.Create("invalid_order", "Vui lòng chọn loại đơn và ít nhất một món."));
   if (r.Items.Any(x => x is null || x.FoodItemId <= 0 || x.Quantity is < 1 or > 99))
     return BadRequest(ApiErrorResponse.Create("invalid_quantity", "Mỗi món phải có số lượng từ 1 đến 99."));
   if (r.Items.Select(x => x.FoodItemId).Distinct().Count() != r.Items.Count)
     return BadRequest(ApiErrorResponse.Create("duplicate_food", "Mỗi món chỉ được xuất hiện một lần trong đơn."));

   await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
   if (r.OrderType == "DineIn")
   {
     var table = await db.DiningTables.SingleOrDefaultAsync(x => x.TableId == r.TableId && x.Status == "Available", ct);
     if (table is null) return Conflict(ApiErrorResponse.Create("table_unavailable", "Bàn không còn trống."));
     table.Status = "Occupied";
     table.UpdatedAt = DateTime.UtcNow;
   }
   var ids = r.Items.Select(x => x.FoodItemId).ToList();
   var foods = await db.FoodItems.Where(x => ids.Contains(x.FoodItemId) && x.IsAvailable).ToDictionaryAsync(x => x.FoodItemId, ct);
   if (foods.Count != ids.Count) return BadRequest(ApiErrorResponse.Create("food_not_available", "Có món không còn bán."));
   var user = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
   var order = new FoodOrder { OrderCode = $"OFF-{DateTime.UtcNow:yyyyMMddHHmmssfff}", UserId = user, OrderStatusId = 1,
     OrderType = r.OrderType, TableId = r.OrderType == "DineIn" ? r.TableId : null,
     TotalAmount = r.Items.Sum(x => foods[x.FoodItemId].Price * x.Quantity), PaymentStatus = "Unpaid", CreatedAt = DateTime.UtcNow };
   foreach (var line in r.Items)
   {
     var food = foods[line.FoodItemId];
     order.OrderDetails.Add(new OrderDetail { FoodItemId = food.FoodItemId, FoodNameSnapshot = food.Name, UnitPrice = food.Price, Quantity = line.Quantity });
   }
   db.Orders.Add(order);
   await db.SaveChangesAsync(ct);
   await tx.CommitAsync(ct);
   return Ok(new { orderId = order.OrderId, orderCode = order.OrderCode, orderType = order.OrderType,
     status = "Pending", paymentStatus = order.PaymentStatus, totalAmount = order.TotalAmount });
 }
}
