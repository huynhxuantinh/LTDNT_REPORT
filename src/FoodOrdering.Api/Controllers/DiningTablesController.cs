using System.ComponentModel.DataAnnotations;
using FoodOrdering.Api.Common;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
namespace FoodOrdering.Api.Controllers;
public sealed record SaveTableRequest([Required,StringLength(20)] string TableCode,[Range(1,50)] byte Capacity);
[ApiController,Route("api/admin/tables"),Authorize(Roles="Admin")]
public sealed class DiningTablesController(FoodOrderingDbContext db):ControllerBase{
 [HttpGet] public async Task<IActionResult> Get(CancellationToken ct)=>Ok(await db.DiningTables.AsNoTracking().OrderBy(x=>x.TableCode).ToListAsync(ct));
 [HttpPost]
 public async Task<IActionResult> Create(SaveTableRequest request, CancellationToken ct)
 {
   var code = request.TableCode?.Trim();
   if (string.IsNullOrWhiteSpace(code)) return BadRequest(ApiErrorResponse.Create("invalid_table_code", "Vui lòng nhập mã bàn."));
   var table = new DiningTable { TableCode = code, Capacity = request.Capacity, Status = "Available", CreatedAt = DateTime.UtcNow };
   db.DiningTables.Add(table);
   try { await db.SaveChangesAsync(ct); }
   catch (DbUpdateException error) when (IsDuplicateCode(error))
   {
     return Conflict(ApiErrorResponse.Create("table_code_exists", "Mã bàn đã tồn tại. Vui lòng chọn mã khác."));
   }
   return Ok(table);
 }

 [HttpPut("{id:int}")]
 public async Task<IActionResult> Update(int id, SaveTableRequest request, CancellationToken ct)
 {
   var table = await db.DiningTables.FindAsync([id], ct);
   if (table is null) return NotFound();
   var code = request.TableCode?.Trim();
   if (string.IsNullOrWhiteSpace(code)) return BadRequest(ApiErrorResponse.Create("invalid_table_code", "Vui lòng nhập mã bàn."));
   table.TableCode = code;
   table.Capacity = request.Capacity;
   table.UpdatedAt = DateTime.UtcNow;
   try { await db.SaveChangesAsync(ct); }
   catch (DbUpdateException error) when (IsDuplicateCode(error))
   {
     return Conflict(ApiErrorResponse.Create("table_code_exists", "Mã bàn đã tồn tại. Vui lòng chọn mã khác."));
   }
   return Ok(table);
 }

 private static bool IsDuplicateCode(DbUpdateException error) =>
   error.InnerException is Microsoft.Data.SqlClient.SqlException { Number: 2601 or 2627 };
 [HttpDelete("{id:int}")] public async Task<IActionResult> Delete(int id,CancellationToken ct){var x=await db.DiningTables.FindAsync([id],ct);if(x is null)return NotFound();if(await db.Orders.AnyAsync(o=>o.TableId==id&&o.OrderStatus!.Name!="Completed"&&o.OrderStatus.Name!="Cancelled",ct))return Conflict(ApiErrorResponse.Create("table_has_open_order","Bàn đang có đơn mở."));if(await db.Orders.AnyAsync(o=>o.TableId==id,ct))return Conflict(ApiErrorResponse.Create("table_has_order_history","Bàn đã có lịch sử đơn hàng nên không thể xóa."));db.DiningTables.Remove(x);try{await db.SaveChangesAsync(ct);}catch(DbUpdateException error) when(error.InnerException is Microsoft.Data.SqlClient.SqlException {Number:547}){return Conflict(ApiErrorResponse.Create("table_has_order_history","Bàn đã có đơn hàng nên không thể xóa."));}return NoContent();}
}
