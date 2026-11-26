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
    [HttpGet("{foodItemId:int}/related")]
    public async Task<ActionResult<PagedResponse<MemberFoodItem>>> Related(int foodItemId, [FromQuery] PageRequest pageRequest, CancellationToken cancellationToken)
    {
        var item = await foodService.GetByIdAsync(foodItemId, cancellationToken);
        if (item is null) return NotFound();
        var page = await foodService.GetAllAsync(pageRequest, item.CategoryId, null, cancellationToken, foodItemId);
        return Ok(page);
    }
    [HttpGet("{foodItemId:int}")]
    public async Task<ActionResult<MemberFoodItem>> GetById(int foodItemId, CancellationToken cancellationToken)
    {
        var item = await foodService.GetByIdAsync(foodItemId, cancellationToken);
        return item is null ? NotFound() : Ok(item);
    }
    [HttpGet]
    public async Task<ActionResult<PagedResponse<MemberFoodItem>>> GetAll(
        [FromQuery] PageRequest pageRequest,
        [FromQuery] int? categoryId,
        [FromQuery] string? search,
        CancellationToken cancellationToken) =>
        Ok(await foodService.GetAllAsync(pageRequest, categoryId, search, cancellationToken));
}
