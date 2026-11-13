using System.Security.Claims;
using FoodOrdering.Api.Common;
using FoodOrdering.Api.Users;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FoodOrdering.Api.Controllers;

[ApiController]
[Route("api/users/me")]
[Authorize]
public sealed class ProfileController(UserProfileService userProfileService) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<MyProfile>> GetProfile(CancellationToken cancellationToken)
    {
        var userId = GetUserId();
        if (userId is null)
        {
            return Unauthorized(ApiErrorResponse.Create("invalid_token", "Token không hợp lệ."));
        }

        var result = await userProfileService.GetProfileAsync(userId.Value, cancellationToken);
        return result.IsSuccess
            ? Ok(result.Value)
            : NotFound(ApiErrorResponse.Create("profile_not_found", result.Error!));
    }

    [HttpPut]
    public async Task<ActionResult<MyProfile>> UpdateProfile(UpdateMyProfileRequest request, CancellationToken cancellationToken)
    {
        var userId = GetUserId();
        if (userId is null)
        {
            return Unauthorized(ApiErrorResponse.Create("invalid_token", "Token không hợp lệ."));
        }

        var result = await userProfileService.UpdateProfileAsync(userId.Value, request, cancellationToken);
        return result.IsSuccess
            ? Ok(result.Value)
            : NotFound(ApiErrorResponse.Create("profile_not_found", result.Error!));
    }

    private Guid? GetUserId() => Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var userId) ? userId : null;
}
