using FoodOrdering.Api.Categories;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FoodOrdering.Api.Controllers;

[ApiController]
[Route("api/categories")]
[AllowAnonymous]
public sealed class CategoriesController(MemberCategoryService categoryService) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<MemberCategoryItem>>> GetAll(CancellationToken cancellationToken) =>
        Ok(await categoryService.GetActiveAsync(cancellationToken));
}
