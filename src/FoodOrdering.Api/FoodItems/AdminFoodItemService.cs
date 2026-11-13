using FoodOrdering.Api.Common;
using FoodOrdering.Api.Data;
using Microsoft.EntityFrameworkCore;

namespace FoodOrdering.Api.FoodItems;

public sealed record FoodItemListItem(
    int FoodItemId,
    int CategoryId,
    string CategoryName,
    string Name,
    string? Description,
    decimal Price,
    string? ImageUrl,
    bool IsAvailable,
    DateTime CreatedAt);

public sealed record CreateFoodItemData(int CategoryId, string Name, string? Description, decimal Price, string ImageUrl);

public sealed record UpdateFoodItemData(int CategoryId, string Name, string? Description, decimal Price, string? NewImageUrl);

public sealed record UpdatedFoodItem(FoodItemListItem Item, string? PreviousImageUrl);

public sealed record FoodItemActionResult<T>(bool IsSuccess, T? Value, string? ErrorCode, string? Error)
{
    public static FoodItemActionResult<T> Success(T value) => new(true, value, null, null);
    public static FoodItemActionResult<T> Failure(string errorCode, string error) => new(false, default, errorCode, error);
}

public sealed class AdminFoodItemService(FoodOrderingDbContext dbContext)
{
    public async Task<PagedResponse<FoodItemListItem>> GetAllAsync(
        PageRequest pageRequest,
        int? categoryId,
        string? search,
        CancellationToken cancellationToken)
    {
        var page = pageRequest.ValidPage;
        var pageSize = pageRequest.ValidPageSize;
        var query = dbContext.FoodItems.AsNoTracking().AsQueryable();

        if (categoryId is > 0)
        {
            query = query.Where(item => item.CategoryId == categoryId);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var keyword = search.Trim().ToLower();
            query = query.Where(item => item.Name.ToLower().Contains(keyword));
        }

        var totalItems = await query.CountAsync(cancellationToken);
        var data = await query
            .OrderByDescending(item => item.CreatedAt)
            .ThenByDescending(item => item.FoodItemId)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(item => new FoodItemListItem(
                item.FoodItemId,
                item.CategoryId,
                item.Category!.Name,
                item.Name,
                item.Description,
                item.Price,
                item.ImageUrl,
                item.IsAvailable,
                item.CreatedAt))
            .ToListAsync(cancellationToken);

        return PagedResponse<FoodItemListItem>.Create(data, page, pageSize, totalItems);
    }

    public async Task<FoodItemActionResult<FoodItemListItem>> CreateAsync(
        CreateFoodItemData data,
        CancellationToken cancellationToken)
    {
        var category = await dbContext.Categories
            .SingleOrDefaultAsync(item => item.CategoryId == data.CategoryId && item.IsActive, cancellationToken);
        if (category is null)
        {
            return FoodItemActionResult<FoodItemListItem>.Failure("category_not_found", "Danh mục không tồn tại hoặc đã bị ẩn.");
        }

        var name = data.Name.Trim();
        if (await dbContext.FoodItems.AnyAsync(item => item.CategoryId == data.CategoryId && item.Name == name, cancellationToken))
        {
            return FoodItemActionResult<FoodItemListItem>.Failure("food_name_exists", "Tên món đã tồn tại trong danh mục.");
        }

        var foodItem = new global::FoodOrdering.Api.Models.FoodItem
        {
            CategoryId = category.CategoryId,
            Category = category,
            Name = name,
            Description = string.IsNullOrWhiteSpace(data.Description) ? null : data.Description.Trim(),
            Price = data.Price,
            ImageUrl = data.ImageUrl,
            IsAvailable = true,
            CreatedAt = DateTime.UtcNow,
        };
        dbContext.FoodItems.Add(foodItem);
        await dbContext.SaveChangesAsync(cancellationToken);

        return FoodItemActionResult<FoodItemListItem>.Success(new FoodItemListItem(
            foodItem.FoodItemId,
            category.CategoryId,
            category.Name,
            foodItem.Name,
            foodItem.Description,
            foodItem.Price,
            foodItem.ImageUrl,
            foodItem.IsAvailable,
            foodItem.CreatedAt));
    }

    public async Task<FoodItemActionResult<UpdatedFoodItem>> UpdateAsync(
        int foodItemId,
        UpdateFoodItemData data,
        CancellationToken cancellationToken)
    {
        var foodItem = await dbContext.FoodItems.SingleOrDefaultAsync(item => item.FoodItemId == foodItemId, cancellationToken);
        if (foodItem is null)
        {
            return FoodItemActionResult<UpdatedFoodItem>.Failure("food_not_found", "Không tìm thấy món ăn.");
        }

        var category = await dbContext.Categories
            .SingleOrDefaultAsync(item => item.CategoryId == data.CategoryId && item.IsActive, cancellationToken);
        if (category is null)
        {
            return FoodItemActionResult<UpdatedFoodItem>.Failure("category_not_found", "Danh mục không tồn tại hoặc đã bị ẩn.");
        }

        var name = data.Name.Trim();
        if (await dbContext.FoodItems.AnyAsync(
                item => item.FoodItemId != foodItemId && item.CategoryId == data.CategoryId && item.Name == name,
                cancellationToken))
        {
            return FoodItemActionResult<UpdatedFoodItem>.Failure("food_name_exists", "Tên món đã tồn tại trong danh mục.");
        }

        var previousImageUrl = foodItem.ImageUrl;
        foodItem.CategoryId = category.CategoryId;
        foodItem.Category = category;
        foodItem.Name = name;
        foodItem.Description = string.IsNullOrWhiteSpace(data.Description) ? null : data.Description.Trim();
        foodItem.Price = data.Price;
        if (data.NewImageUrl is not null) foodItem.ImageUrl = data.NewImageUrl;
        foodItem.UpdatedAt = DateTime.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);

        var item = new FoodItemListItem(
            foodItem.FoodItemId,
            category.CategoryId,
            category.Name,
            foodItem.Name,
            foodItem.Description,
            foodItem.Price,
            foodItem.ImageUrl,
            foodItem.IsAvailable,
            foodItem.CreatedAt);
        return FoodItemActionResult<UpdatedFoodItem>.Success(new UpdatedFoodItem(item, data.NewImageUrl is null ? null : previousImageUrl));
    }

    public async Task<FoodItemActionResult<string?>> DeleteAsync(int foodItemId, CancellationToken cancellationToken)
    {
        var foodItem = await dbContext.FoodItems.SingleOrDefaultAsync(item => item.FoodItemId == foodItemId, cancellationToken);
        if (foodItem is null)
        {
            return FoodItemActionResult<string?>.Failure("food_not_found", "Không tìm thấy món ăn.");
        }

        if (await dbContext.OrderDetails.AnyAsync(item => item.FoodItemId == foodItemId, cancellationToken))
        {
            return FoodItemActionResult<string?>.Failure("food_has_order_details", "Không thể xóa món đã có trong đơn hàng.");
        }

        var imageUrl = foodItem.ImageUrl;
        dbContext.FoodItems.Remove(foodItem);
        await dbContext.SaveChangesAsync(cancellationToken);
        return FoodItemActionResult<string?>.Success(imageUrl);
    }

    public async Task<FoodItemActionResult<FoodItemListItem>> HideAsync(int foodItemId, CancellationToken cancellationToken)
    {
        var foodItem = await dbContext.FoodItems.Include(item => item.Category)
            .SingleOrDefaultAsync(item => item.FoodItemId == foodItemId, cancellationToken);
        if (foodItem is null)
        {
            return FoodItemActionResult<FoodItemListItem>.Failure("food_not_found", "Không tìm thấy món ăn.");
        }

        if (!await dbContext.OrderDetails.AnyAsync(item => item.FoodItemId == foodItemId, cancellationToken))
        {
            return FoodItemActionResult<FoodItemListItem>.Failure("food_has_no_order_details", "Chỉ có thể ẩn món đã xuất hiện trong đơn hàng.");
        }

        foodItem.IsAvailable = false;
        foodItem.UpdatedAt = DateTime.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
        return FoodItemActionResult<FoodItemListItem>.Success(new FoodItemListItem(
            foodItem.FoodItemId,
            foodItem.CategoryId,
            foodItem.Category!.Name,
            foodItem.Name,
            foodItem.Description,
            foodItem.Price,
            foodItem.ImageUrl,
            foodItem.IsAvailable,
            foodItem.CreatedAt));
    }
}
