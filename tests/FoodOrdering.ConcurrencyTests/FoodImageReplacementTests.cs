using FoodOrdering.Api.Controllers;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.FoodItems;
using FoodOrdering.Api.Models;
using FoodOrdering.Api.Uploads;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace FoodOrdering.ConcurrencyTests;

public sealed class FoodImageReplacementTests
{
    [SqlServerFact]
    public async Task NewImageSurvivesOldImageCleanupFailureAndIsRemovedWhenSaveFails()
    {
        var connection = new SqlConnectionStringBuilder(Environment.GetEnvironmentVariable("FOOD_ORDERING_TEST_CONNECTION")!)
        {
            InitialCatalog = "codex_image_test_" + Guid.NewGuid().ToString("N")[..12],
            Pooling = false,
        };
        var options = new DbContextOptionsBuilder<FoodOrderingDbContext>().UseSqlServer(connection.ConnectionString).Options;
        await using var db = new FoodOrderingDbContext(options);
        var created = false;
        try
        {
            if (await db.Database.CanConnectAsync()) throw new InvalidOperationException("Generated test database already exists.");
            created = await db.Database.EnsureCreatedAsync();
            if (!created) throw new InvalidOperationException("Could not create the isolated test database.");

            var category = new Category { Name = "Test", IsActive = true, CreatedAt = DateTime.UtcNow };
            db.Categories.Add(category);
            await db.SaveChangesAsync();
            var food = new FoodItem { CategoryId = category.CategoryId, Name = "Food", Price = 100, ImageUrl = FakeStorage.OldImage, IsAvailable = true, CreatedAt = DateTime.UtcNow };
            db.FoodItems.Add(food);
            await db.SaveChangesAsync();

            var storage = new FakeStorage();
            var controller = new AdminFoodItemsController(new AdminFoodItemService(db), storage, db, NullLogger<AdminFoodItemsController>.Instance);
            using var bytes = new MemoryStream([1]);
            var image = new FormFile(bytes, 0, 1, "image", "new.png");
            UpdateFoodItemRequest request(int categoryId) => new() { CategoryId = categoryId, Name = "Food", Price = 100, Image = image };

            var updated = await controller.Update(food.FoodItemId, request(category.CategoryId), CancellationToken.None);
            Assert.IsType<OkObjectResult>(updated.Result);
            Assert.Contains(FakeStorage.OldImage, storage.AttemptedDeletes);
            Assert.Contains("/uploads/foods/new-1.png", storage.Files);
            db.ChangeTracker.Clear();
            Assert.Equal("/uploads/foods/new-1.png", (await db.FoodItems.SingleAsync(x => x.FoodItemId == food.FoodItemId)).ImageUrl);

            var missingCategory = await controller.Update(food.FoodItemId, request(category.CategoryId + 1000), CancellationToken.None);
            Assert.IsType<NotFoundObjectResult>(missingCategory.Result);
            Assert.DoesNotContain("/uploads/foods/new-2.png", storage.Files);

            await db.Database.ExecuteSqlRawAsync("CREATE TRIGGER image_test_fail_update ON dbo.FoodItems AFTER UPDATE AS THROW 51000, 'Injected save failure', 1");
            await Assert.ThrowsAsync<DbUpdateException>(() => controller.Update(food.FoodItemId, request(category.CategoryId), CancellationToken.None));
            Assert.DoesNotContain("/uploads/foods/new-3.png", storage.Files);
            db.ChangeTracker.Clear();
            Assert.Equal("/uploads/foods/new-1.png", (await db.FoodItems.SingleAsync(x => x.FoodItemId == food.FoodItemId)).ImageUrl);
            Assert.Contains("/uploads/foods/new-1.png", storage.Files);
        }
        finally
        {
            if (created) await db.Database.EnsureDeletedAsync();
        }
    }

    private sealed class FakeStorage : IFoodImageStorage
    {
        public const string OldImage = "/uploads/foods/old.png";
        public HashSet<string> Files { get; } = [OldImage];
        public List<string> AttemptedDeletes { get; } = [];
        private int count;

        public Task<string> SaveAsync(IFormFile image, CancellationToken cancellationToken)
        {
            var path = $"/uploads/foods/new-{++count}.png";
            Files.Add(path);
            return Task.FromResult(path);
        }

        public Task DeleteAsync(string? imageUrl, CancellationToken cancellationToken)
        {
            if (imageUrl is null) return Task.CompletedTask;
            AttemptedDeletes.Add(imageUrl);
            if (imageUrl == OldImage) throw new IOException("Injected old image deletion failure");
            Files.Remove(imageUrl);
            return Task.CompletedTask;
        }
    }
}
