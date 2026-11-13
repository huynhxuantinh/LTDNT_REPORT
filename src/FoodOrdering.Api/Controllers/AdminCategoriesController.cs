using FoodOrdering.Api.Categories;
using FoodOrdering.Api.Common;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FoodOrdering.Api.Controllers;

[ApiController]
[Route("api/admin/categories")]
[Authorize(Roles = "Admin")]
public sealed class AdminCategoriesController(AdminCategoryService categoryService) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<CategoryItem>>> GetAll(CancellationToken cancellationToken) =>
        Ok(await categoryService.GetAllAsync(cancellationToken));

    [HttpPost]
    public async Task<ActionResult<CategoryItem>> Create(SaveCategoryRequest request, CancellationToken cancellationToken)
    {
        var result = await categoryService.CreateAsync(request, cancellationToken);
        return result.IsSuccess
            ? CreatedAtAction(nameof(GetAll), result.Value)
            : Conflict(ApiErrorResponse.Create(result.ErrorCode!, result.Error!));
    }

    [HttpPut("{categoryId:int}")]
    public async Task<ActionResult<CategoryItem>> Update(int categoryId, SaveCategoryRequest request, CancellationToken cancellationToken)
    {
        var result = await categoryService.UpdateAsync(categoryId, request, cancellationToken);
        if (result.IsSuccess) return Ok(result.Value);
        return result.ErrorCode == "category_not_found"
            ? NotFound(ApiErrorResponse.Create(result.ErrorCode, result.Error!))
            : Conflict(ApiErrorResponse.Create(result.ErrorCode!, result.Error!));
    }

    [HttpDelete("{categoryId:int}")]
    public async Task<IActionResult> Delete(int categoryId, CancellationToken cancellationToken)
    {
        var result = await categoryService.DeleteAsync(categoryId, cancellationToken);
        if (result.IsSuccess) return NoContent();
        return result.ErrorCode == "category_not_found"
            ? NotFound(ApiErrorResponse.Create(result.ErrorCode, result.Error!))
            : Conflict(ApiErrorResponse.Create(result.ErrorCode!, result.Error!));
    }
}
