using FoodOrdering.Api.Categories;
using FoodOrdering.Api.Common;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using FoodOrdering.Api.Uploads;

namespace FoodOrdering.Api.Controllers;

[ApiController]
[Route("api/admin/categories")]
[Authorize(Roles = "Admin")]
public sealed class AdminCategoriesController(AdminCategoryService categoryService, IFoodImageStorage storage) : ControllerBase
{
    [HttpPost("{categoryId:int}/image")]
    public async Task<IActionResult> UploadImage(int categoryId,IFormFile image,CancellationToken ct){var url=await storage.SaveAsync(image,ct);var result=await categoryService.SetImageAsync(categoryId,url,ct);if(!result.IsSuccess){await storage.DeleteAsync(url,ct);return NotFound();}await storage.DeleteAsync(result.Value,ct);return Ok(new{imageUrl=url});}
    [HttpDelete("{categoryId:int}/image")]
    public async Task<IActionResult> DeleteImage(int categoryId,CancellationToken ct){var result=await categoryService.SetImageAsync(categoryId,null,ct);if(!result.IsSuccess)return NotFound();await storage.DeleteAsync(result.Value,ct);return NoContent();}
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
