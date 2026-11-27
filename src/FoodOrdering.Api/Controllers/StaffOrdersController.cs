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
public sealed record CreateStaffOrderRequest(string OrderType, int? TableId, List<StaffOrderLine> Items, string? ReceiverName = null);
public sealed record ExpectedStaffOrderLine(long OrderDetailId, int Quantity);
public sealed record UpdateStaffOrderItemsRequest(List<StaffOrderLine> Items, List<ExpectedStaffOrderLine> ExpectedItems);
[ApiController,Route("api/staff/orders"),Authorize(Roles="Admin,Staff")]
public sealed class StaffOrdersController(FoodOrderingDbContext db):ControllerBase{
 [HttpPut("{id:long}/status")]
 public async Task<IActionResult> Status(long id, UpdateOrderStatusRequest request, CancellationToken ct)
 {
   await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
   var user=Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
   var order=await db.Orders.Include(x=>x.OrderStatus).SingleOrDefaultAsync(x=>x.OrderId==id && (x.OrderType=="DineIn" || x.OrderType=="TakeAway"),ct);
   if(order is null) return NotFound();
   if (request.Status == "Cancelled" && order.PaymentStatus == "Paid") return Conflict(ApiErrorResponse.Create("paid_order_cannot_cancel", "Không thể hủy đơn đã thanh toán khi chưa có quy trình hoàn tiền."));
   var allowed=order.OrderStatus!.Name switch { "Pending" => new[]{"Confirmed","Cancelled"}, "Confirmed" => new[]{"Preparing","Cancelled"}, "Preparing" => new[]{"Completed","Cancelled"}, _ => Array.Empty<string>() };
   if(!allowed.Contains(request.Status)) return Conflict();
   var status=await db.OrderStatuses.SingleAsync(x=>x.Name==request.Status,ct);
   order.OrderStatusId=status.OrderStatusId; order.UpdatedAt=DateTime.UtcNow;
   db.OrderStatusHistories.Add(new OrderStatusHistory { OrderId=id, OrderStatusId=status.OrderStatusId, UpdatedByUserId=user, CreatedAt=DateTime.UtcNow });
   await db.SaveChangesAsync(ct);
   if (request.Status is "Completed" or "Cancelled") await DiningTableRelease.ReleaseIfUnoccupiedAsync(db, order, ct);
   await tx.CommitAsync(ct);
   return Ok(new { orderId=id, status=request.Status });
 }
 [HttpGet]
 public async Task<IActionResult> Get(CancellationToken ct) => Ok(await db.Orders.AsNoTracking()
   .Where(x => x.OrderType == "DineIn" || x.OrderType == "TakeAway")
   .OrderByDescending(x => x.CreatedAt)
   .Select(x => new { x.OrderId, x.OrderCode, x.OrderType, x.PaymentStatus, Status = x.OrderStatus!.Name,
     x.TotalAmount, x.CreatedAt, TableCode = x.DiningTable != null ? x.DiningTable.TableCode : null,
     CreatedBy = x.User != null ? x.User.FullName : null, x.ReceiverName })
   .ToListAsync(ct));

 [HttpGet("{id:long}")]
 public async Task<IActionResult> GetDetail(long id, CancellationToken ct)
 {
   var order = await db.Orders.AsNoTracking()
     .Where(x => x.OrderId == id && (x.OrderType == "DineIn" || x.OrderType == "TakeAway"))
     .Select(x => new { x.OrderId, x.OrderCode, x.OrderType, x.PaymentStatus, Status = x.OrderStatus!.Name,
       x.TotalAmount, x.CreatedAt, x.Note, x.ReceiverName,
       TableCode = x.DiningTable != null ? x.DiningTable.TableCode : null,
       CreatedBy = x.User != null ? x.User.FullName : null,
       Items = x.OrderDetails.OrderBy(d => d.OrderDetailId).Select(d => new {
         d.OrderDetailId, d.FoodItemId, d.FoodNameSnapshot, d.UnitPrice, d.Quantity
       }).ToList() })
     .SingleOrDefaultAsync(ct);
   return order is null ? NotFound(ApiErrorResponse.Create("order_not_found", "Không tìm thấy đơn tại quán.")) : Ok(order);
 }
 [HttpPut("{id:long}/items")]
 public async Task<IActionResult> UpdateItems(long id, UpdateStaffOrderItemsRequest request, CancellationToken ct)
 {
   if (request.Items is null || request.ExpectedItems is null || request.Items.Count == 0 || request.Items.Count > 100 || request.ExpectedItems.Count > 100 ||
       request.Items.Any(x => x is null || x.FoodItemId <= 0 || x.Quantity is < 1 or > 99) ||
       request.Items.Select(x => x.FoodItemId).Distinct().Count() != request.Items.Count ||
       request.ExpectedItems.Any(x => x is null || x.OrderDetailId <= 0 || x.Quantity is < 1 or > 99) ||
       request.ExpectedItems.Select(x => x.OrderDetailId).Distinct().Count() != request.ExpectedItems.Count)
     return BadRequest(ApiErrorResponse.Create("invalid_items", "Danh sách món hoặc số lượng không hợp lệ."));

   await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
   var order = await db.Orders
     .FromSqlInterpolated($"SELECT * FROM dbo.Orders WITH (UPDLOCK, HOLDLOCK) WHERE OrderId = {id}")
     .Include(x => x.OrderStatus).Include(x => x.OrderDetails)
     .SingleOrDefaultAsync(ct);
   if (order is null || order.OrderType is not ("DineIn" or "TakeAway"))
     return NotFound(ApiErrorResponse.Create("order_not_found", "Không tìm thấy đơn tại quán."));
   if (order.PaymentStatus != "Unpaid" || order.OrderStatus!.Name is "Completed" or "Cancelled")
     return Conflict(ApiErrorResponse.Create("order_not_editable", "Đơn đã thanh toán hoặc kết thúc nên không thể sửa món."));
   if (await db.Payments.AnyAsync(x => x.OrderId == id && x.Status == "Pending" && (x.Method == "VietQR" || x.Method == "VNPay"), ct))
     return Conflict(ApiErrorResponse.Create("payment_pending", "Đơn đã tạo yêu cầu thanh toán. Hãy xử lý thanh toán trước khi sửa món."));
   var current = order.OrderDetails.ToDictionary(x => x.OrderDetailId, x => x.Quantity);
   if (current.Count != request.ExpectedItems.Count || request.ExpectedItems.Any(x => !current.TryGetValue(x.OrderDetailId, out var quantity) || quantity != x.Quantity))
     return Conflict(ApiErrorResponse.Create("order_changed", "Đơn đã được thay đổi. Vui lòng tải lại trước khi sửa."));

   if (order.OrderDetails.GroupBy(x => x.FoodItemId).Any(x => x.Count() > 1))
     return Conflict(ApiErrorResponse.Create("duplicate_order_lines", "Đơn có nhiều dòng cùng món; vui lòng kiểm tra trước khi sửa."));
   var oldItems = order.OrderDetails.ToDictionary(x => x.FoodItemId);
   var newIds = request.Items.Where(x => !oldItems.ContainsKey(x.FoodItemId)).Select(x => x.FoodItemId).ToList();
   var newFoods = await db.FoodItems.Where(x => newIds.Contains(x.FoodItemId) && x.IsAvailable).ToDictionaryAsync(x => x.FoodItemId, ct);
   if (newFoods.Count != newIds.Count)
     return Conflict(ApiErrorResponse.Create("food_not_available", "Có món mới không còn bán."));
   var increasedIds = request.Items.Where(x => oldItems.TryGetValue(x.FoodItemId, out var old) && x.Quantity > old.Quantity).Select(x => x.FoodItemId).ToList();
   if (await db.FoodItems.CountAsync(x => increasedIds.Contains(x.FoodItemId) && x.IsAvailable, ct) != increasedIds.Count)
     return Conflict(ApiErrorResponse.Create("food_not_available", "Không thể tăng số lượng món đã ngừng bán."));
   var selected = request.Items.ToDictionary(x => x.FoodItemId);
   foreach (var detail in order.OrderDetails.ToList())
   {
     if (selected.TryGetValue(detail.FoodItemId, out var line)) detail.Quantity = line.Quantity;
     else db.OrderDetails.Remove(detail);
   }
   foreach (var line in request.Items.Where(x => !oldItems.ContainsKey(x.FoodItemId)))
   {
     var food = newFoods[line.FoodItemId];
     order.OrderDetails.Add(new OrderDetail { FoodItemId = food.FoodItemId, FoodNameSnapshot = food.Name, UnitPrice = food.Price, Quantity = line.Quantity, ImageUrlSnapshot = food.ImageUrl });
   }
   order.TotalAmount = request.Items.Sum(line => oldItems.TryGetValue(line.FoodItemId, out var previous) ? previous.UnitPrice * line.Quantity : newFoods[line.FoodItemId].Price * line.Quantity);
   order.UpdatedAt = DateTime.UtcNow;
   await db.SaveChangesAsync(ct);
   await tx.CommitAsync(ct);
   return Ok(new { orderId = order.OrderId, totalAmount = order.TotalAmount });
 }
 [HttpPost]
 public async Task<IActionResult> Create(CreateStaffOrderRequest r, CancellationToken ct)
 {
   if (r.OrderType is not ("DineIn" or "TakeAway") || r.Items is null || r.Items.Count == 0)
     return BadRequest(ApiErrorResponse.Create("invalid_order", "Vui lòng chọn loại đơn và ít nhất một món."));
   if (r.Items.Any(x => x is null || x.FoodItemId <= 0 || x.Quantity is < 1 or > 99))
     return BadRequest(ApiErrorResponse.Create("invalid_quantity", "Mỗi món phải có số lượng từ 1 đến 99."));
   if (r.Items.Select(x => x.FoodItemId).Distinct().Count() != r.Items.Count)
     return BadRequest(ApiErrorResponse.Create("duplicate_food", "Mỗi món chỉ được xuất hiện một lần trong đơn."));
   if (r.ReceiverName?.Trim().Length > 120)
     return BadRequest(ApiErrorResponse.Create("invalid_customer_name", "Tên khách không được vượt quá 120 ký tự."));

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
     ReceiverName = string.IsNullOrWhiteSpace(r.ReceiverName) ? null : r.ReceiverName.Trim(),
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
