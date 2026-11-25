using FoodOrdering.Api.Categories;
using FoodOrdering.Api.Common;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using FoodOrdering.Api.Uploads;

namespace FoodOrdering.Api.Controllers;

[ApiController]
[Route("api/admin/categories")]
[Authorize(Roles = "Admin")]
public sealed class AdminCategoriesController(AdminCategoryService categoryService, IFoodImageStorage storage, ILogger<AdminCategoriesController> logger) : ControllerBase
{
    [HttpPost("{categoryId:int}/image")]
    [RequestSizeLimit(6 * 1024 * 1024)]
    public async Task<IActionResult> UploadImage(int categoryId, [FromForm] IFormFile image, CancellationToken ct)
    {
        string? newUrl = null;
        var linked = false;
        try
        {
            newUrl = await storage.SaveAsync(image, ct);
            var result = await categoryService.SetImageAsync(categoryId, newUrl, ct);
            if (!result.IsSuccess)
            {
                await TryDeleteImage(newUrl, ct);
                return NotFound(ApiErrorResponse.Create(result.ErrorCode!, result.Error!));
            }
            linked = true;
            await TryDeleteImage(result.Value, CancellationToken.None);
            return Ok(new { imageUrl = newUrl });
        }
        catch (ImageUploadException error)
        {
            return BadRequest(ApiErrorResponse.Create("invalid_image", error.Message));
        }
        catch
        {
            if (!linked) await TryDeleteImage(newUrl, CancellationToken.None);
            throw;
        }
    }
    [HttpDelete("{categoryId:int}/image")]
    public async Task<IActionResult> DeleteImage(int categoryId, CancellationToken ct)
    {
        var result = await categoryService.SetImageAsync(categoryId, null, ct);
        if (!result.IsSuccess) return NotFound(ApiErrorResponse.Create(result.ErrorCode!, result.Error!));
        await TryDeleteImage(result.Value, CancellationToken.None);
        return NoContent();
    }
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
        if (result.IsSuccess)
        {
            await TryDeleteImage(result.Value, CancellationToken.None);
            return NoContent();
        }
        return result.ErrorCode == "category_not_found"
            ? NotFound(ApiErrorResponse.Create(result.ErrorCode, result.Error!))
            : Conflict(ApiErrorResponse.Create(result.ErrorCode!, result.Error!));
    }

    private async Task TryDeleteImage(string? url, CancellationToken ct)
    {
        try { await storage.DeleteAsync(url, ct); }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException)
        {
            logger.LogWarning(error, "Không thể xóa ảnh danh mục cũ.");
        }
    }
}
