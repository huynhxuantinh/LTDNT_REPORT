using FoodOrdering.Api.Controllers;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.FoodItems;
using FoodOrdering.Api.Models;
using FoodOrdering.Api.Uploads;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace FoodOrdering.Api.Tests;

public sealed class FoodImagesControllerTests
{
    private static FoodOrderingDbContext CreateDb() => new(new DbContextOptionsBuilder<FoodOrderingDbContext>()
        .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);

    [Fact]
    public async Task MultipleImagesCanBeDeletedIndividuallyAndCoverIsPromoted()
    {
        await using var db = CreateDb();
        db.FoodItems.Add(new FoodItem { FoodItemId = 1, Name = "Phở", ImageUrl = "/uploads/foods/cover.jpg", IsAvailable = true });
        await db.SaveChangesAsync();
        var storage = new FakeStorage();
        var controller = new AdminFoodImagesController(db, storage, NullLogger<AdminFoodImagesController>.Instance);
        var image = new FormFile(new MemoryStream([1]), 0, 1, "image", "new.jpg");
        var first = Assert.IsType<FoodImageItem>(Assert.IsType<OkObjectResult>(await controller.Add(1, image, CancellationToken.None)).Value);
        var second = Assert.IsType<FoodImageItem>(Assert.IsType<OkObjectResult>(await controller.Add(1, image, CancellationToken.None)).Value);
        var all = Assert.IsType<List<FoodImageItem>>(Assert.IsType<OkObjectResult>(await controller.Get(1, CancellationToken.None)).Value);
        Assert.Equal(3, all.Count);
        Assert.True(all[0].IsCover);
        Assert.IsType<NoContentResult>(await controller.Delete(1, second.ImageId!.Value, CancellationToken.None));
        Assert.Equal([second.ImageUrl], storage.Deleted);
        Assert.IsType<NoContentResult>(await controller.DeleteCover(1, CancellationToken.None));
        Assert.Equal(first.ImageUrl, (await db.FoodItems.FindAsync(1))!.ImageUrl);
        Assert.Equal([second.ImageUrl, "/uploads/foods/cover.jpg"], storage.Deleted);
        Assert.Empty(db.FoodItemImages);
        var publicImages = Assert.IsType<List<string>>(Assert.IsType<OkObjectResult>(await new FoodImagesController(db).Get(1, CancellationToken.None)).Value);
        Assert.Equal([first.ImageUrl], publicImages);
        Assert.IsType<NoContentResult>(await controller.DeleteCover(1, CancellationToken.None));
        Assert.Null((await db.FoodItems.FindAsync(1))!.ImageUrl);
        var newCover = Assert.IsType<FoodImageItem>(Assert.IsType<OkObjectResult>(await controller.Add(1, image, CancellationToken.None)).Value);
        Assert.True(newCover.IsCover);
        Assert.Null(newCover.ImageId);
        Assert.Equal(newCover.ImageUrl, (await db.FoodItems.FindAsync(1))!.ImageUrl);
        Assert.IsType<NotFoundObjectResult>(await controller.Delete(2, first.ImageId!.Value, CancellationToken.None));
    }

    [Fact]
    public async Task DeletingFoodCleansAllImagesAndHiddenFoodIsNotPublic()
    {
        await using var db = CreateDb();
        var food = new FoodItem { FoodItemId = 1, Name = "Phở", ImageUrl = "/uploads/foods/cover.jpg", IsAvailable = false };
        db.FoodItems.Add(food);
        db.FoodItemImages.Add(new FoodItemImage { FoodItemId = 1, ImageUrl = "/uploads/foods/extra.jpg" });
        await db.SaveChangesAsync();
        Assert.IsType<NotFoundObjectResult>(await new FoodImagesController(db).Get(1, CancellationToken.None));
        var storage = new FakeStorage();
        var controller = new AdminFoodItemsController(new AdminFoodItemService(db), storage, db, NullLogger<AdminFoodItemsController>.Instance);
        Assert.IsType<NoContentResult>(await controller.Delete(1, CancellationToken.None));
        Assert.Equal(["/uploads/foods/cover.jpg", "/uploads/foods/extra.jpg"], storage.Deleted);
        Assert.Empty(db.FoodItemImages);
        Assert.Empty(db.FoodItems);
    }

    private sealed class FakeStorage : IFoodImageStorage
    {
        private int _count;
        public List<string?> Deleted { get; } = [];
        public Task<string> SaveAsync(IFormFile image, CancellationToken ct) => Task.FromResult($"/uploads/foods/{++_count}.jpg");
        public Task DeleteAsync(string? url, CancellationToken ct) { Deleted.Add(url); return Task.CompletedTask; }
    }
}
