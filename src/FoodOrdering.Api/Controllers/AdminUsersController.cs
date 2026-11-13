using System.Security.Claims;
using FoodOrdering.Api.Common;
using FoodOrdering.Api.Users;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FoodOrdering.Api.Controllers;

[ApiController]
[Route("api/admin/users")]
[Authorize(Roles = "Admin")]
public sealed class AdminUsersController(AdminUserService adminUserService) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<PagedResponse<AdminUserListItem>>> GetUsers(
        [FromQuery] PageRequest pageRequest,
        [FromQuery] string? search,
        CancellationToken cancellationToken)
    {
        return Ok(await adminUserService.GetUsersAsync(pageRequest, search, cancellationToken));
    }

    [HttpPut("{userId:guid}/role")]
    public async Task<ActionResult<AdminUserListItem>> ChangeRole(
        Guid userId,
        ChangeUserRoleRequest request,
        CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var actorUserId))
        {
            return Unauthorized(ApiErrorResponse.Create("invalid_token", "Token không hợp lệ."));
        }

        var result = await adminUserService.ChangeRoleAsync(actorUserId, userId, request, cancellationToken);
        if (result.IsSuccess)
        {
            return Ok(result.Value);
        }

        return result.ErrorCode == "user_not_found"
            ? NotFound(ApiErrorResponse.Create(result.ErrorCode, result.Error!))
            : BadRequest(ApiErrorResponse.Create(result.ErrorCode!, result.Error!));
    }

    [HttpPut("{userId:guid}/active-status")]
    public async Task<ActionResult<AdminUserListItem>> ChangeActiveStatus(
        Guid userId,
        ChangeUserActiveStatusRequest request,
        CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var actorUserId))
        {
            return Unauthorized(ApiErrorResponse.Create("invalid_token", "Token không hợp lệ."));
        }

        var result = await adminUserService.ChangeActiveStatusAsync(actorUserId, userId, request, cancellationToken);
        if (result.IsSuccess)
        {
            return Ok(result.Value);
        }

        return result.ErrorCode == "user_not_found"
            ? NotFound(ApiErrorResponse.Create(result.ErrorCode, result.Error!))
            : BadRequest(ApiErrorResponse.Create(result.ErrorCode!, result.Error!));
    }
}
