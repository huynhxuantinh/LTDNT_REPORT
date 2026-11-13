using FoodOrdering.Api.Common;
using FoodOrdering.Api.Data;
using Microsoft.EntityFrameworkCore;
using System.ComponentModel.DataAnnotations;

namespace FoodOrdering.Api.Users;

public sealed record AdminUserListItem(
    Guid UserId,
    string FullName,
    string Email,
    string? PhoneNumber,
    string Role,
    bool IsActive,
    bool IsEmailVerified,
    DateTime CreatedAt);

public sealed record ChangeUserRoleRequest([param: Required, StringLength(20)] string Role);

public sealed record ChangeUserActiveStatusRequest(bool IsActive);

public sealed record AdminUserResult<T>(bool IsSuccess, T? Value, string? Error, string? ErrorCode)
{
    public static AdminUserResult<T> Success(T value) => new(true, value, null, null);
    public static AdminUserResult<T> Failure(string errorCode, string error) => new(false, default, error, errorCode);
}

public sealed class AdminUserService(FoodOrderingDbContext dbContext)
{
    public async Task<PagedResponse<AdminUserListItem>> GetUsersAsync(
        PageRequest pageRequest,
        string? search,
        CancellationToken cancellationToken)
    {
        var page = pageRequest.ValidPage;
        var pageSize = pageRequest.ValidPageSize;
        var query = dbContext.Users.AsNoTracking().Include(user => user.Role).AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
        {
            var keyword = search.Trim();
            query = query.Where(user => user.FullName.Contains(keyword) || user.Email.Contains(keyword));
        }

        var totalItems = await query.CountAsync(cancellationToken);
        var users = await query
            .OrderByDescending(user => user.CreatedAt)
            .ThenBy(user => user.FullName)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(user => new AdminUserListItem(
                user.UserId,
                user.FullName,
                user.Email,
                user.PhoneNumber,
                user.Role!.RoleName,
                user.IsActive,
                user.IsEmailVerified,
                user.CreatedAt))
            .ToListAsync(cancellationToken);

        return PagedResponse<AdminUserListItem>.Create(users, page, pageSize, totalItems);
    }

    public async Task<AdminUserResult<AdminUserListItem>> ChangeRoleAsync(
        Guid actorUserId,
        Guid userId,
        ChangeUserRoleRequest request,
        CancellationToken cancellationToken)
    {
        var roleName = request.Role?.Trim();
        if (string.IsNullOrWhiteSpace(roleName))
        {
            return AdminUserResult<AdminUserListItem>.Failure("invalid_role", "Role không hợp lệ.");
        }

        var user = await dbContext.Users.SingleOrDefaultAsync(item => item.UserId == userId, cancellationToken);
        if (user is null)
        {
            return AdminUserResult<AdminUserListItem>.Failure("user_not_found", "Không tìm thấy người dùng.");
        }

        var role = await dbContext.Roles.SingleOrDefaultAsync(
            item => item.RoleName.ToUpper() == roleName.ToUpper(),
            cancellationToken);
        if (role is null)
        {
            return AdminUserResult<AdminUserListItem>.Failure("invalid_role", "Role chỉ có thể là Member, Staff hoặc Admin.");
        }

        if (actorUserId == userId && role.RoleName != "Admin")
        {
            return AdminUserResult<AdminUserListItem>.Failure("self_role_change_forbidden", "Admin không thể tự bỏ quyền Admin.");
        }

        user.RoleId = role.RoleId;
        user.UpdatedAt = DateTime.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);

        return AdminUserResult<AdminUserListItem>.Success(new AdminUserListItem(
            user.UserId,
            user.FullName,
            user.Email,
            user.PhoneNumber,
            role.RoleName,
            user.IsActive,
            user.IsEmailVerified,
            user.CreatedAt));
    }

    public async Task<AdminUserResult<AdminUserListItem>> ChangeActiveStatusAsync(
        Guid actorUserId,
        Guid userId,
        ChangeUserActiveStatusRequest request,
        CancellationToken cancellationToken)
    {
        if (actorUserId == userId && !request.IsActive)
        {
            return AdminUserResult<AdminUserListItem>.Failure("self_lock_forbidden", "Admin không thể tự khóa tài khoản.");
        }

        var user = await dbContext.Users.Include(item => item.Role).SingleOrDefaultAsync(item => item.UserId == userId, cancellationToken);
        if (user is null)
        {
            return AdminUserResult<AdminUserListItem>.Failure("user_not_found", "Không tìm thấy người dùng.");
        }

        user.IsActive = request.IsActive;
        user.UpdatedAt = DateTime.UtcNow;
        if (!request.IsActive)
        {
            var refreshTokens = await dbContext.RefreshTokens
                .Where(item => item.UserId == userId && item.RevokedAt == null)
                .ToListAsync(cancellationToken);
            foreach (var refreshToken in refreshTokens)
            {
                refreshToken.RevokedAt = DateTime.UtcNow;
            }
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return AdminUserResult<AdminUserListItem>.Success(new AdminUserListItem(
            user.UserId,
            user.FullName,
            user.Email,
            user.PhoneNumber,
            user.Role!.RoleName,
            user.IsActive,
            user.IsEmailVerified,
            user.CreatedAt));
    }
}
