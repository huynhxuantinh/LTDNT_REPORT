using Microsoft.AspNetCore.Http;

namespace FoodOrdering.Api.Uploads;

public sealed class ImageUploadException(string message) : Exception(message);

public interface IFoodImageStorage
{
    Task<string> SaveAsync(IFormFile image, CancellationToken cancellationToken);
    Task DeleteAsync(string? imageUrl, CancellationToken cancellationToken);
}

public sealed class FoodImageStorage(IWebHostEnvironment environment) : IFoodImageStorage
{
    private const long MaxFileSize = 5 * 1024 * 1024;
    private static readonly IReadOnlyDictionary<string, string[]> ExtensionsByMimeType = new Dictionary<string, string[]>
    {
        ["image/jpeg"] = [".jpg", ".jpeg"],
        ["image/png"] = [".png"],
        ["image/webp"] = [".webp"],
    };

    public async Task<string> SaveAsync(IFormFile image, CancellationToken cancellationToken)
    {
        if (image.Length is <= 0 or > MaxFileSize)
        {
            throw new ImageUploadException("Ảnh phải có dung lượng từ 1 byte đến 5 MB.");
        }

        var extension = Path.GetExtension(image.FileName).ToLowerInvariant();
        if (!ExtensionsByMimeType.TryGetValue(image.ContentType.ToLowerInvariant(), out var allowedExtensions) || !allowedExtensions.Contains(extension))
        {
            throw new ImageUploadException("Chỉ chấp nhận ảnh JPEG, PNG hoặc WEBP.");
        }

        await using var source = image.OpenReadStream();
        if (!await HasValidSignatureAsync(source, image.ContentType, cancellationToken))
        {
            throw new ImageUploadException("Nội dung tệp không khớp định dạng ảnh khai báo.");
        }

        source.Position = 0;
        var webRootPath = environment.WebRootPath ?? Path.Combine(environment.ContentRootPath, "wwwroot");
        var foodDirectory = Path.Combine(webRootPath, "uploads", "foods");
        Directory.CreateDirectory(foodDirectory);
        var fileName = $"{Guid.NewGuid():N}{extension}";
        var filePath = Path.Combine(foodDirectory, fileName);
        await using var destination = new FileStream(filePath, FileMode.CreateNew, FileAccess.Write, FileShare.None);
        await source.CopyToAsync(destination, cancellationToken);
        return $"/uploads/foods/{fileName}";
    }

    public Task DeleteAsync(string? imageUrl, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(imageUrl) || !imageUrl.StartsWith("/uploads/foods/", StringComparison.Ordinal))
        {
            return Task.CompletedTask;
        }

        var webRootPath = environment.WebRootPath ?? Path.Combine(environment.ContentRootPath, "wwwroot");
        var fileName = Path.GetFileName(imageUrl);
        var filePath = Path.Combine(webRootPath, "uploads", "foods", fileName);
        if (File.Exists(filePath)) File.Delete(filePath);
        return Task.CompletedTask;
    }

    private static async Task<bool> HasValidSignatureAsync(Stream stream, string contentType, CancellationToken cancellationToken)
    {
        var bytes = new byte[12];
        var read = await stream.ReadAsync(bytes.AsMemory(0, bytes.Length), cancellationToken);
        return contentType.ToLowerInvariant() switch
        {
            "image/jpeg" => read >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF,
            "image/png" => read >= 8 && bytes[..8].SequenceEqual(new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A }),
            "image/webp" => read >= 12 && bytes[..4].SequenceEqual("RIFF"u8) && bytes[8..12].SequenceEqual("WEBP"u8),
            _ => false,
        };
    }
}
