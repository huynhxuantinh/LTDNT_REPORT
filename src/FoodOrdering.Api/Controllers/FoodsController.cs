using FoodOrdering.Api.Common;
using FoodOrdering.Api.FoodItems;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FoodOrdering.Api.Controllers;

[ApiController]
[Route("api/foods")]
[AllowAnonymous]
public sealed class FoodsController(MemberFoodService foodService) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<PagedResponse<MemberFoodItem>>> GetAll(
        [FromQuery] PageRequest pageRequest,
        [FromQuery] int? categoryId,
        [FromQuery] string? search,
        CancellationToken cancellationToken) =>
        Ok(await foodService.GetAllAsync(pageRequest, categoryId, search, cancellationToken));
}
