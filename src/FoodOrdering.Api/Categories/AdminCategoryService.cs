using System.ComponentModel.DataAnnotations;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace FoodOrdering.Api.Categories;

public sealed record CategoryItem(int CategoryId, string Name, string? Description, string? ImageUrl, bool IsActive, DateTime CreatedAt);

public sealed record SaveCategoryRequest(
    [param: Required, StringLength(100, MinimumLength = 2)] string Name,
    [param: StringLength(500)] string? Description);

public sealed record CategoryActionResult<T>(bool IsSuccess, T? Value, string? ErrorCode, string? Error)
{
    public static CategoryActionResult<T> Success(T value) => new(true, value, null, null);
    public static CategoryActionResult<T> Failure(string errorCode, string error) => new(false, default, errorCode, error);
}

public sealed class AdminCategoryService(FoodOrderingDbContext dbContext)
{
    public async Task<CategoryActionResult<string?>> SetImageAsync(int id,string? image,CancellationToken ct){var c=await dbContext.Categories.FindAsync([id],ct);if(c is null)return CategoryActionResult<string?>.Failure("category_not_found","Không tìm thấy danh mục.");var old=c.ImageUrl;c.ImageUrl=image;c.UpdatedAt=DateTime.UtcNow;await dbContext.SaveChangesAsync(ct);return CategoryActionResult<string?>.Success(old);}
    public async Task<IReadOnlyList<CategoryItem>> GetAllAsync(CancellationToken cancellationToken) =>
        await dbContext.Categories.AsNoTracking()
            .OrderBy(category => category.Name)
            .Select(category => ToItem(category))
            .ToListAsync(cancellationToken);

    public async Task<CategoryActionResult<CategoryItem>> CreateAsync(SaveCategoryRequest request, CancellationToken cancellationToken)
    {
        var name = request.Name.Trim();
        if (await dbContext.Categories.AnyAsync(category => category.Name == name, cancellationToken))
        {
            return CategoryActionResult<CategoryItem>.Failure("category_name_exists", "Tên danh mục đã tồn tại.");
        }

        var category = new Category
        {
            Name = name,
            Description = NormalizeOptional(request.Description),
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
        };
        dbContext.Categories.Add(category);
        await dbContext.SaveChangesAsync(cancellationToken);
        return CategoryActionResult<CategoryItem>.Success(ToItem(category));
    }

    public async Task<CategoryActionResult<CategoryItem>> UpdateAsync(int categoryId, SaveCategoryRequest request, CancellationToken cancellationToken)
    {
        var category = await dbContext.Categories.SingleOrDefaultAsync(item => item.CategoryId == categoryId, cancellationToken);
        if (category is null)
        {
            return CategoryActionResult<CategoryItem>.Failure("category_not_found", "Không tìm thấy danh mục.");
        }

        var name = request.Name.Trim();
        if (await dbContext.Categories.AnyAsync(item => item.CategoryId != categoryId && item.Name == name, cancellationToken))
        {
            return CategoryActionResult<CategoryItem>.Failure("category_name_exists", "Tên danh mục đã tồn tại.");
        }

        category.Name = name;
        category.Description = NormalizeOptional(request.Description);
        category.UpdatedAt = DateTime.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
        return CategoryActionResult<CategoryItem>.Success(ToItem(category));
    }

    public async Task<CategoryActionResult<bool>> DeleteAsync(int categoryId, CancellationToken cancellationToken)
    {
        var category = await dbContext.Categories.SingleOrDefaultAsync(item => item.CategoryId == categoryId, cancellationToken);
        if (category is null)
        {
            return CategoryActionResult<bool>.Failure("category_not_found", "Không tìm thấy danh mục.");
        }

        if (await dbContext.FoodItems.AnyAsync(item => item.CategoryId == categoryId, cancellationToken))
        {
            return CategoryActionResult<bool>.Failure("category_has_food_items", "Không thể xóa danh mục còn món ăn.");
        }

        dbContext.Categories.Remove(category);
        await dbContext.SaveChangesAsync(cancellationToken);
        return CategoryActionResult<bool>.Success(true);
    }

    private static string? NormalizeOptional(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private static CategoryItem ToItem(Category category) => new(
        category.CategoryId,
        category.Name,
        category.Description,
        category.ImageUrl,
        category.IsActive,
        category.CreatedAt);
}
