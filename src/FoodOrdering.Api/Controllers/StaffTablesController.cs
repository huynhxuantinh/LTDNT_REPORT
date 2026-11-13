using FoodOrdering.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
namespace FoodOrdering.Api.Controllers;
[ApiController,Route("api/staff/tables"),Authorize(Roles="Admin,Staff")]
public sealed class StaffTablesController(FoodOrderingDbContext db):ControllerBase{
 [HttpGet("available")] public async Task<IActionResult> Available(CancellationToken ct)=>Ok(await db.DiningTables.AsNoTracking().Where(x=>x.Status=="Available").OrderBy(x=>x.TableCode).Select(x=>new{x.TableId,x.TableCode,x.Capacity}).ToListAsync(ct));
}
