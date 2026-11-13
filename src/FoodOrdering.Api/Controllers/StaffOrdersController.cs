using System.Security.Claims;
using System.Data;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
namespace FoodOrdering.Api.Controllers;
public sealed record StaffOrderLine(int FoodItemId,int Quantity);
public sealed record CreateStaffOrderRequest(string OrderType,int? TableId,List<StaffOrderLine> Items);
[ApiController,Route("api/staff/orders"),Authorize(Roles="Admin,Staff")]
public sealed class StaffOrdersController(FoodOrderingDbContext db):ControllerBase{
 [HttpGet] public async Task<IActionResult> Get(CancellationToken ct){var user=Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);return Ok(await db.Orders.AsNoTracking().Where(x=>x.UserId==user&&(x.OrderType=="DineIn"||x.OrderType=="TakeAway")).OrderByDescending(x=>x.CreatedAt).Select(x=>new{x.OrderId,x.OrderCode,x.OrderType,x.PaymentStatus,Status=x.OrderStatus!.Name,x.TotalAmount}).ToListAsync(ct));}
 [HttpPost] public async Task<IActionResult> Create(CreateStaffOrderRequest r,CancellationToken ct){if(r.OrderType is not ("DineIn" or "TakeAway")||r.Items.Count==0)return BadRequest();await using var tx=await db.Database.BeginTransactionAsync(IsolationLevel.Serializable,ct);DiningTable? table=null;if(r.OrderType=="DineIn"){table=await db.DiningTables.SingleOrDefaultAsync(x=>x.TableId==r.TableId&&x.Status=="Available",ct);if(table is null)return Conflict(new{error="table_unavailable"});table.Status="Occupied";table.UpdatedAt=DateTime.UtcNow;}var ids=r.Items.Select(x=>x.FoodItemId).ToList();var foods=await db.FoodItems.Where(x=>ids.Contains(x.FoodItemId)&&x.IsAvailable).ToDictionaryAsync(x=>x.FoodItemId,ct);if(foods.Count!=ids.Count)return BadRequest();var user=Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);var o=new FoodOrder{OrderCode=$"OFF-{DateTime.UtcNow:yyyyMMddHHmmssfff}",UserId=user,OrderStatusId=1,OrderType=r.OrderType,TableId=r.TableId,TotalAmount=r.Items.Sum(x=>foods[x.FoodItemId].Price*x.Quantity),PaymentStatus="Unpaid",CreatedAt=DateTime.UtcNow};foreach(var x in r.Items){var f=foods[x.FoodItemId];o.OrderDetails.Add(new OrderDetail{FoodItemId=f.FoodItemId,FoodNameSnapshot=f.Name,UnitPrice=f.Price,Quantity=x.Quantity});}db.Orders.Add(o);await db.SaveChangesAsync(ct);await tx.CommitAsync(ct);return Ok(new{orderId=o.OrderId});}
}
