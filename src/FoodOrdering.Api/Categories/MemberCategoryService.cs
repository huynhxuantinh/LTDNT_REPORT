using FoodOrdering.Api.Data;
using Microsoft.EntityFrameworkCore;

namespace FoodOrdering.Api.Categories;

public sealed record MemberCategoryItem(int CategoryId, string Name, string? Description, string? ImageUrl);

public sealed class MemberCategoryService(FoodOrderingDbContext dbContext)
{
    public async Task<IReadOnlyList<MemberCategoryItem>> GetActiveAsync(CancellationToken cancellationToken) =>
        await dbContext.Categories.AsNoTracking()
            .Where(category => category.IsActive)
            .OrderBy(category => category.Name)
            .Select(category => new MemberCategoryItem(
                category.CategoryId,
                category.Name,
                category.Description,
                category.ImageUrl))
            .ToListAsync(cancellationToken);
}
