using FoodOrdering.Api.Common;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using FoodOrdering.Api.Uploads;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FoodOrdering.Api.Controllers;

public sealed record FoodImageItem(int? ImageId, string ImageUrl, bool IsCover);

[ApiController, Route("api/admin/food-items/{foodItemId:int}/images"), Authorize(Roles = "Admin")]
public sealed class AdminFoodImagesController(FoodOrderingDbContext db, IFoodImageStorage storage, ILogger<AdminFoodImagesController> logger) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(int foodItemId, CancellationToken ct)
    {
        var food = await db.FoodItems.AsNoTracking().SingleOrDefaultAsync(x => x.FoodItemId == foodItemId, ct);
        if (food is null) return NotFound(ApiErrorResponse.Create("food_not_found", "Không tìm thấy món ăn."));
        var images = await db.FoodItemImages.AsNoTracking().Where(x => x.FoodItemId == foodItemId)
            .OrderBy(x => x.FoodItemImageId).Select(x => new FoodImageItem(x.FoodItemImageId, x.ImageUrl, false)).ToListAsync(ct);
        if (!string.IsNullOrWhiteSpace(food.ImageUrl)) images.Insert(0, new FoodImageItem(null, food.ImageUrl, true));
        return Ok(images);
    }

    [HttpPost, RequestSizeLimit(6 * 1024 * 1024)]
    public async Task<IActionResult> Add(int foodItemId, [FromForm] IFormFile image, CancellationToken ct)
    {
        var food = await db.FoodItems.SingleOrDefaultAsync(x => x.FoodItemId == foodItemId, ct);
        if (food is null) return NotFound(ApiErrorResponse.Create("food_not_found", "Không tìm thấy món ăn."));
        string? url = null;
        try
        {
            url = await storage.SaveAsync(image, ct);
            FoodItemImage? extra = null;
            if (string.IsNullOrWhiteSpace(food.ImageUrl)) food.ImageUrl = url;
            else { extra = new FoodItemImage { FoodItemId = foodItemId, ImageUrl = url, CreatedAt = DateTime.UtcNow }; db.FoodItemImages.Add(extra); }
            food.UpdatedAt = DateTime.UtcNow;
            await db.SaveChangesAsync(ct);
            return Ok(new FoodImageItem(extra?.FoodItemImageId, url, extra is null));
        }
        catch (ImageUploadException error) { return BadRequest(ApiErrorResponse.Create("invalid_image", error.Message)); }
        catch
        {
            if (url is not null) await TryDeleteFile(url);
            throw;
        }
    }

    [HttpDelete("cover")]
    public async Task<IActionResult> DeleteCover(int foodItemId, CancellationToken ct)
    {
        var food = await db.FoodItems.SingleOrDefaultAsync(x => x.FoodItemId == foodItemId, ct);
        if (food is null) return NotFound(ApiErrorResponse.Create("food_not_found", "Không tìm thấy món ăn."));
        if (string.IsNullOrWhiteSpace(food.ImageUrl)) return NotFound(ApiErrorResponse.Create("image_not_found", "Không tìm thấy ảnh."));
        var removed = food.ImageUrl;
        var next = await db.FoodItemImages.Where(x => x.FoodItemId == foodItemId).OrderBy(x => x.FoodItemImageId).FirstOrDefaultAsync(ct);
        food.ImageUrl = next?.ImageUrl;
        food.UpdatedAt = DateTime.UtcNow;
        if (next is not null) db.FoodItemImages.Remove(next);
        await db.SaveChangesAsync(ct);
        await TryDeleteFile(removed);
        return NoContent();
    }

    [HttpDelete("{imageId:int}")]
    public async Task<IActionResult> Delete(int foodItemId, int imageId, CancellationToken ct)
    {
        var image = await db.FoodItemImages.SingleOrDefaultAsync(x => x.FoodItemId == foodItemId && x.FoodItemImageId == imageId, ct);
        if (image is null) return NotFound(ApiErrorResponse.Create("image_not_found", "Không tìm thấy ảnh của món ăn."));
        db.FoodItemImages.Remove(image);
        await db.SaveChangesAsync(ct);
        await TryDeleteFile(image.ImageUrl);
        return NoContent();
    }

    private async Task TryDeleteFile(string url)
    {
        try { await storage.DeleteAsync(url, CancellationToken.None); }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException) { logger.LogWarning(error, "Không thể xóa ảnh món ăn."); }
    }
}

[ApiController, Route("api/foods/{foodItemId:int}/images"), AllowAnonymous]
public sealed class FoodImagesController(FoodOrderingDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(int foodItemId, CancellationToken ct)
    {
        var food = await db.FoodItems.AsNoTracking().SingleOrDefaultAsync(x => x.FoodItemId == foodItemId && x.IsAvailable, ct);
        if (food is null) return NotFound(ApiErrorResponse.Create("food_not_found", "Không tìm thấy món ăn."));
        var images = await db.FoodItemImages.AsNoTracking().Where(x => x.FoodItemId == foodItemId)
            .OrderBy(x => x.FoodItemImageId).Select(x => x.ImageUrl).ToListAsync(ct);
        if (!string.IsNullOrWhiteSpace(food.ImageUrl)) images.Insert(0, food.ImageUrl);
        return Ok(images);
    }
}
