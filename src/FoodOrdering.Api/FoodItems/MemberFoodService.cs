using FoodOrdering.Api.Common;
using FoodOrdering.Api.Data;
using Microsoft.EntityFrameworkCore;

namespace FoodOrdering.Api.FoodItems;

public sealed record MemberFoodItem(
    int FoodItemId,
    int CategoryId,
    string CategoryName,
    string Name,
    string? Description,
    decimal Price,
    string? ImageUrl,
    DateTime CreatedAt);

public sealed class MemberFoodService(FoodOrderingDbContext dbContext)
{
    public async Task<PagedResponse<MemberFoodItem>> GetAllAsync(
        PageRequest pageRequest,
        int? categoryId,
        string? search,
        CancellationToken cancellationToken)
    {
        var page = pageRequest.ValidPage;
        var pageSize = pageRequest.ValidPageSize;
        var query = dbContext.FoodItems.AsNoTracking().Where(item => item.IsAvailable);

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
            .Select(item => new MemberFoodItem(
                item.FoodItemId,
                item.CategoryId,
                item.Category!.Name,
                item.Name,
                item.Description,
                item.Price,
                item.ImageUrl,
                item.CreatedAt))
            .ToListAsync(cancellationToken);

        return PagedResponse<MemberFoodItem>.Create(data, page, pageSize, totalItems);
    }
}
