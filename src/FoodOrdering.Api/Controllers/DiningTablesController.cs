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
 [HttpPost] public async Task<IActionResult> Create(SaveTableRequest r,CancellationToken ct){var x=new DiningTable{TableCode=r.TableCode.Trim(),Capacity=r.Capacity,Status="Available",CreatedAt=DateTime.UtcNow};db.DiningTables.Add(x);await db.SaveChangesAsync(ct);return Ok(x);}
 [HttpPut("{id:int}")] public async Task<IActionResult> Update(int id,SaveTableRequest r,CancellationToken ct){var x=await db.DiningTables.FindAsync([id],ct);if(x is null)return NotFound();x.TableCode=r.TableCode.Trim();x.Capacity=r.Capacity;x.UpdatedAt=DateTime.UtcNow;await db.SaveChangesAsync(ct);return Ok(x);}
 [HttpDelete("{id:int}")] public async Task<IActionResult> Delete(int id,CancellationToken ct){var x=await db.DiningTables.FindAsync([id],ct);if(x is null)return NotFound();if(await db.Orders.AnyAsync(o=>o.TableId==id&&o.OrderStatus!.Name!="Completed"&&o.OrderStatus.Name!="Cancelled",ct))return Conflict(ApiErrorResponse.Create("table_has_open_order","Bàn đang có đơn mở."));db.DiningTables.Remove(x);await db.SaveChangesAsync(ct);return NoContent();}
}
