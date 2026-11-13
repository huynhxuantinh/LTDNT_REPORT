using System.ComponentModel.DataAnnotations;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace FoodOrdering.Api.Users;

public sealed record MyProfile(Guid UserId, string FullName, string Email, string? PhoneNumber, string Role, bool IsEmailVerified);

public sealed record UpdateMyProfileRequest(
    [param: Required, StringLength(120, MinimumLength = 2)] string FullName,
    [param: StringLength(20)] string? PhoneNumber);

public sealed record UserProfileResult<T>(bool IsSuccess, T? Value, string? Error)
{
    public static UserProfileResult<T> Success(T value) => new(true, value, null);
    public static UserProfileResult<T> Failure(string error) => new(false, default, error);
}

public sealed class UserProfileService(FoodOrderingDbContext dbContext)
{
    public async Task<UserProfileResult<MyProfile>> GetProfileAsync(Guid userId, CancellationToken cancellationToken)
    {
        var user = await dbContext.Users.AsNoTracking().Include(item => item.Role)
            .SingleOrDefaultAsync(item => item.UserId == userId && item.IsActive, cancellationToken);
        return user is null
            ? UserProfileResult<MyProfile>.Failure("Không tìm thấy tài khoản đang hoạt động.")
            : UserProfileResult<MyProfile>.Success(ToProfile(user));
    }

    public async Task<UserProfileResult<MyProfile>> UpdateProfileAsync(
        Guid userId,
        UpdateMyProfileRequest request,
        CancellationToken cancellationToken)
    {
        var user = await dbContext.Users.Include(item => item.Role)
            .SingleOrDefaultAsync(item => item.UserId == userId && item.IsActive, cancellationToken);
        if (user is null)
        {
            return UserProfileResult<MyProfile>.Failure("Không tìm thấy tài khoản đang hoạt động.");
        }

        user.FullName = request.FullName.Trim();
        user.PhoneNumber = string.IsNullOrWhiteSpace(request.PhoneNumber) ? null : request.PhoneNumber.Trim();
        user.UpdatedAt = DateTime.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
        return UserProfileResult<MyProfile>.Success(ToProfile(user));
    }

    private static MyProfile ToProfile(User user) => new(
        user.UserId,
        user.FullName,
        user.Email,
        user.PhoneNumber,
        user.Role?.RoleName ?? "Member",
        user.IsEmailVerified);
}
