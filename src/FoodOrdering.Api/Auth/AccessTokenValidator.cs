using System.Security.Claims;
using FoodOrdering.Api.Data;
using Microsoft.EntityFrameworkCore;

namespace FoodOrdering.Api.Auth;

public static class AccessTokenValidator
{
    public static async Task<bool> IsCurrentAsync(ClaimsPrincipal? principal, FoodOrderingDbContext db, CancellationToken ct)
    {
        if (!Guid.TryParse(principal?.FindFirstValue(ClaimTypes.NameIdentifier), out var userId) ||
            !Guid.TryParse(principal?.FindFirstValue("security_stamp"), out var stamp)) return false;

        var roleClaim = principal.FindFirstValue(ClaimTypes.Role);
        if (string.IsNullOrEmpty(roleClaim)) return false;
        var user = await db.Users.AsNoTracking()
            .Where(x => x.UserId == userId)
            .Select(x => new { x.IsActive, x.SecurityStamp, Role = x.Role!.RoleName })
            .SingleOrDefaultAsync(ct);
        return user is not null && user.IsActive && user.SecurityStamp == stamp &&
               string.Equals(user.Role, roleClaim, StringComparison.Ordinal);
    }
}
