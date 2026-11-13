using FoodOrdering.Api.Uploads;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.FileProviders;
using Xunit;

namespace FoodOrdering.Api.Tests;

public sealed class FoodImageStorageTests
{
    [Fact]
    public async Task SaveAsync_StoresValidPngUsingUuidFileName()
    {
        var rootPath = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(rootPath);
        try
        {
            var storage = new FoodImageStorage(new TestWebHostEnvironment(rootPath));
            await using var stream = new MemoryStream(Convert.FromBase64String("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL7WQAAAABJRU5ErkJggg=="));
            var image = new FormFile(stream, 0, stream.Length, "image", "food.png")
            {
                Headers = new HeaderDictionary { ["Content-Type"] = "image/png" },
            };

            var imageUrl = await storage.SaveAsync(image, CancellationToken.None);

            Assert.Matches("^/uploads/foods/[a-f0-9]{32}\\.png$", imageUrl);
            Assert.True(File.Exists(Path.Combine(rootPath, imageUrl.TrimStart('/').Replace('/', Path.DirectorySeparatorChar))));
            await storage.DeleteAsync(imageUrl, CancellationToken.None);
        }
        finally
        {
            if (Directory.Exists(rootPath)) Directory.Delete(rootPath, recursive: true);
        }
    }

    [Fact]
    public async Task SaveAsync_RejectsFileLargerThanFiveMb()
    {
        var rootPath = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(rootPath);
        try
        {
            var storage = new FoodImageStorage(new TestWebHostEnvironment(rootPath));

            var exception = await Assert.ThrowsAsync<ImageUploadException>(() =>
                storage.SaveAsync(CreateImage(new byte[(5 * 1024 * 1024) + 1], "large.png", "image/png"), CancellationToken.None));

            Assert.Contains("5 MB", exception.Message);
        }
        finally
        {
            if (Directory.Exists(rootPath)) Directory.Delete(rootPath, recursive: true);
        }
    }

    [Theory]
    [InlineData("image/gif", "image.gif")]
    [InlineData("image/png", "image.jpg")]
    public async Task SaveAsync_RejectsUnsupportedMimeTypeOrExtension(string mimeType, string fileName)
    {
        var rootPath = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(rootPath);
        try
        {
            var storage = new FoodImageStorage(new TestWebHostEnvironment(rootPath));

            await Assert.ThrowsAsync<ImageUploadException>(() =>
                storage.SaveAsync(CreateImage(ValidPng, fileName, mimeType), CancellationToken.None));
        }
        finally
        {
            if (Directory.Exists(rootPath)) Directory.Delete(rootPath, recursive: true);
        }
    }

    [Fact]
    public async Task SaveAsync_RejectsImageWithInvalidSignature()
    {
        var rootPath = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(rootPath);
        try
        {
            var storage = new FoodImageStorage(new TestWebHostEnvironment(rootPath));

            await Assert.ThrowsAsync<ImageUploadException>(() =>
                storage.SaveAsync(CreateImage([1, 2, 3, 4], "fake.png", "image/png"), CancellationToken.None));
        }
        finally
        {
            if (Directory.Exists(rootPath)) Directory.Delete(rootPath, recursive: true);
        }
    }

    private static readonly byte[] ValidPng = Convert.FromBase64String("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL7WQAAAABJRU5ErkJggg==");

    private static FormFile CreateImage(byte[] bytes, string fileName, string mimeType) => new(new MemoryStream(bytes), 0, bytes.Length, "image", fileName)
    {
        Headers = new HeaderDictionary { ["Content-Type"] = mimeType },
    };

    private sealed class TestWebHostEnvironment(string rootPath) : IWebHostEnvironment
    {
        public string ApplicationName { get; set; } = "FoodOrdering.Api.Tests";
        public IFileProvider WebRootFileProvider { get; set; } = new NullFileProvider();
        public string WebRootPath { get; set; } = rootPath;
        public string EnvironmentName { get; set; } = "Testing";
        public string ContentRootPath { get; set; } = rootPath;
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
