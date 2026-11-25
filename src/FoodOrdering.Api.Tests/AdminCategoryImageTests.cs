using FoodOrdering.Api.Categories;
using FoodOrdering.Api.Controllers;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using FoodOrdering.Api.Uploads;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace FoodOrdering.Api.Tests;

public sealed class AdminCategoryImageTests
{
    [Fact]
    public async Task ReplaceAndRemoveImage_UpdatesCategoryAndDeletesOldFiles()
    {
        await using var db = CreateContext();
        var category = new Category { Name = "Food", ImageUrl = "/uploads/foods/old.jpg", CreatedAt = DateTime.UtcNow };
        db.Categories.Add(category);
        await db.SaveChangesAsync();
        var storage = new FakeStorage();
        var controller = CreateController(db, storage);
        var image = new FormFile(new MemoryStream([1]), 0, 1, "image", "new.jpg");

        Assert.IsType<OkObjectResult>(await controller.UploadImage(category.CategoryId, image, CancellationToken.None));
        Assert.Equal("/uploads/foods/new.jpg", category.ImageUrl);
        Assert.Equal(["/uploads/foods/old.jpg"], storage.Deleted);

        Assert.IsType<NoContentResult>(await controller.DeleteImage(category.CategoryId, CancellationToken.None));
        Assert.Null(category.ImageUrl);
        Assert.Equal(["/uploads/foods/old.jpg", "/uploads/foods/new.jpg"], storage.Deleted);
    }

    [Fact]
    public async Task DeleteCategory_WithFoodPreservesImage_WithoutFoodDeletesIt()
    {
        await using var db = CreateContext();
        var category = new Category { Name = "Food", ImageUrl = "/uploads/foods/old.jpg", CreatedAt = DateTime.UtcNow };
        var food = new FoodItem { Category = category, Name = "Dish", Price = 1, CreatedAt = DateTime.UtcNow };
        db.FoodItems.Add(food);
        await db.SaveChangesAsync();
        var storage = new FakeStorage();
        var controller = CreateController(db, storage);

        Assert.IsType<ConflictObjectResult>(await controller.Delete(category.CategoryId, CancellationToken.None));
        Assert.Empty(storage.Deleted);
        Assert.NotNull(await db.Categories.FindAsync(category.CategoryId));
        db.FoodItems.Remove(food);
        await db.SaveChangesAsync();
        Assert.IsType<NoContentResult>(await controller.Delete(category.CategoryId, CancellationToken.None));
        Assert.Equal(["/uploads/foods/old.jpg"], storage.Deleted);
    }

    [Fact]
    public async Task UploadToMissingCategory_DeletesNewFile()
    {
        await using var db = CreateContext();
        var storage = new FakeStorage();
        var image = new FormFile(new MemoryStream([1]), 0, 1, "image", "new.jpg");
        Assert.IsType<NotFoundObjectResult>(await CreateController(db, storage).UploadImage(123, image, CancellationToken.None));
        Assert.Equal(["/uploads/foods/new.jpg"], storage.Deleted);
    }

    private static AdminCategoriesController CreateController(FoodOrderingDbContext db, IFoodImageStorage storage) =>
        new(new AdminCategoryService(db), storage, NullLogger<AdminCategoriesController>.Instance);

    private static FoodOrderingDbContext CreateContext() => new(new DbContextOptionsBuilder<FoodOrderingDbContext>()
        .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);

    private sealed class FakeStorage : IFoodImageStorage
    {
        public List<string?> Deleted { get; } = [];
        public Task<string> SaveAsync(IFormFile image, CancellationToken cancellationToken) => Task.FromResult("/uploads/foods/new.jpg");
        public Task DeleteAsync(string? imageUrl, CancellationToken cancellationToken)
        {
            Deleted.Add(imageUrl);
            return Task.CompletedTask;
        }
    }
}
