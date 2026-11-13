using System.ComponentModel.DataAnnotations;
using FoodOrdering.Api.Common;
using FoodOrdering.Api.FoodItems;
using FoodOrdering.Api.Uploads;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FoodOrdering.Api.Controllers;

public sealed class CreateFoodItemRequest
{
    [Range(1, int.MaxValue)]
    public int CategoryId { get; init; }

    [Required, StringLength(150, MinimumLength = 2)]
    public required string Name { get; init; }

    public string? Description { get; init; }

    [Range(typeof(decimal), "0.01", "9999999999999999")]
    public decimal Price { get; init; }

    [Required]
    public IFormFile? Image { get; init; }
}

public sealed class UpdateFoodItemRequest
{
    [Range(1, int.MaxValue)]
    public int CategoryId { get; init; }

    [Required, StringLength(150, MinimumLength = 2)]
    public required string Name { get; init; }

    public string? Description { get; init; }

    [Range(typeof(decimal), "0.01", "9999999999999999")]
    public decimal Price { get; init; }

    public IFormFile? Image { get; init; }
}

[ApiController]
[Route("api/admin/food-items")]
[Authorize(Roles = "Admin")]
public sealed class AdminFoodItemsController(AdminFoodItemService foodItemService, IFoodImageStorage imageStorage) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<PagedResponse<FoodItemListItem>>> GetAll(
        [FromQuery] PageRequest pageRequest,
        [FromQuery] int? categoryId,
        [FromQuery] string? search,
        CancellationToken cancellationToken) =>
        Ok(await foodItemService.GetAllAsync(pageRequest, categoryId, search, cancellationToken));

    [HttpPost]
    [RequestSizeLimit(6 * 1024 * 1024)]
    public async Task<ActionResult<FoodItemListItem>> Create([FromForm] CreateFoodItemRequest request, CancellationToken cancellationToken)
    {
        try
        {
            var imageUrl = await imageStorage.SaveAsync(request.Image!, cancellationToken);
            var result = await foodItemService.CreateAsync(
                new CreateFoodItemData(request.CategoryId, request.Name, request.Description, request.Price, imageUrl),
                cancellationToken);
            if (result.IsSuccess)
            {
                return CreatedAtAction(nameof(GetAll), result.Value);
            }

            await imageStorage.DeleteAsync(imageUrl, cancellationToken);
            return result.ErrorCode == "category_not_found"
                ? NotFound(ApiErrorResponse.Create(result.ErrorCode, result.Error!))
                : Conflict(ApiErrorResponse.Create(result.ErrorCode!, result.Error!));
        }
        catch (ImageUploadException error)
        {
            return BadRequest(ApiErrorResponse.Create("invalid_image", error.Message));
        }
    }

    [HttpPut("{foodItemId:int}")]
    [RequestSizeLimit(6 * 1024 * 1024)]
    public async Task<ActionResult<FoodItemListItem>> Update(
        int foodItemId,
        [FromForm] UpdateFoodItemRequest request,
        CancellationToken cancellationToken)
    {
        string? newImageUrl = null;
        try
        {
            if (request.Image is not null)
            {
                newImageUrl = await imageStorage.SaveAsync(request.Image, cancellationToken);
            }

            var result = await foodItemService.UpdateAsync(
                foodItemId,
                new UpdateFoodItemData(request.CategoryId, request.Name, request.Description, request.Price, newImageUrl),
                cancellationToken);
            if (result.IsSuccess)
            {
                await imageStorage.DeleteAsync(result.Value!.PreviousImageUrl, cancellationToken);
                return Ok(result.Value.Item);
            }

            await imageStorage.DeleteAsync(newImageUrl, cancellationToken);
            return result.ErrorCode == "food_not_found" || result.ErrorCode == "category_not_found"
                ? NotFound(ApiErrorResponse.Create(result.ErrorCode!, result.Error!))
                : Conflict(ApiErrorResponse.Create(result.ErrorCode!, result.Error!));
        }
        catch (ImageUploadException error)
        {
            return BadRequest(ApiErrorResponse.Create("invalid_image", error.Message));
        }
        catch
        {
            await imageStorage.DeleteAsync(newImageUrl, cancellationToken);
            throw;
        }
    }

    [HttpDelete("{foodItemId:int}")]
    public async Task<IActionResult> Delete(int foodItemId, CancellationToken cancellationToken)
    {
        var result = await foodItemService.DeleteAsync(foodItemId, cancellationToken);
        if (result.IsSuccess)
        {
            await imageStorage.DeleteAsync(result.Value, cancellationToken);
            return NoContent();
        }

        return result.ErrorCode == "food_not_found"
            ? NotFound(ApiErrorResponse.Create(result.ErrorCode, result.Error!))
            : Conflict(ApiErrorResponse.Create(result.ErrorCode!, result.Error!));
    }

    [HttpPost("{foodItemId:int}/hide")]
    public async Task<ActionResult<FoodItemListItem>> Hide(int foodItemId, CancellationToken cancellationToken)
    {
        var result = await foodItemService.HideAsync(foodItemId, cancellationToken);
        if (result.IsSuccess) return Ok(result.Value);
        return result.ErrorCode == "food_not_found"
            ? NotFound(ApiErrorResponse.Create(result.ErrorCode, result.Error!))
            : BadRequest(ApiErrorResponse.Create(result.ErrorCode!, result.Error!));
    }
}
