using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using FoodOrdering.Api.Carts;
using FoodOrdering.Api.Common;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FoodOrdering.Api.Controllers;

public sealed record AddCartItemRequest([Range(1, int.MaxValue)] int FoodItemId, [Range(1, 99)] int Quantity = 1);
public sealed record UpdateCartItemRequest([Range(1, 99)] int Quantity);
public sealed record SyncCartItemRequest([Required] Guid OperationId, [Required, EmailAddress, StringLength(254)] string AccountEmail, [Range(1, int.MaxValue)] int FoodItemId, [Required, RegularExpression("^(add|set|remove)$")] string Action, [Range(0, 99)] int Quantity);
public sealed record CheckoutDeliveryRequest([Required, StringLength(120)] string ReceiverName, [Required, StringLength(20)] string ReceiverPhone, [Required, StringLength(500)] string DeliveryAddress, [StringLength(1000)] string? Note);

[ApiController, Route("api/cart"), Authorize]
public sealed class CartController(CartService carts) : ControllerBase
{
    [HttpGet] public async Task<ActionResult<CartDto>> Get(CancellationToken ct) => Ok(await carts.GetAsync(UserId, ct));
    [HttpPost("items")] public Task<ActionResult<CartDto>> Add(AddCartItemRequest request, CancellationToken ct) => Execute(carts.AddAsync(UserId, request.FoodItemId, request.Quantity, ct));
    [HttpPut("items/{cartItemId:int}")] public Task<ActionResult<CartDto>> Update(int cartItemId, UpdateCartItemRequest request, CancellationToken ct) => Execute(carts.SetQuantityAsync(UserId, cartItemId, request.Quantity, ct));
    [HttpDelete("items/{cartItemId:int}")] public Task<ActionResult<CartDto>> Delete(int cartItemId, CancellationToken ct) => Execute(carts.RemoveAsync(UserId, cartItemId, ct));
    [HttpPost("sync-item")]
    public async Task<ActionResult<CartDto>> Sync(SyncCartItemRequest request, CancellationToken ct)
    {
        if (request.OperationId == Guid.Empty || (request.Action != "remove" && request.Quantity < 1)) return BadRequest(ApiErrorResponse.Create("invalid_operation", "Thao tác giỏ hàng không hợp lệ."));
        if (!string.Equals(User.FindFirstValue(ClaimTypes.Email), request.AccountEmail.Trim(), StringComparison.OrdinalIgnoreCase)) return Forbid();
        var result = await carts.ApplySyncAsync(UserId, request.OperationId, request.FoodItemId, request.Action, request.Quantity, ct);
        return result.IsSuccess ? Ok(result.Value) : BadRequest(ApiErrorResponse.Create(result.ErrorCode!, result.Error!));
    }
    [HttpPost("checkout/delivery")]
    public async Task<ActionResult<object>> Checkout(CheckoutDeliveryRequest request, CancellationToken ct) { var result = await carts.CheckoutAsync(UserId, request.ReceiverName, request.ReceiverPhone, request.DeliveryAddress, request.Note, ct); return result.IsSuccess ? Ok(new { orderId = result.Value }) : BadRequest(ApiErrorResponse.Create(result.ErrorCode!, result.Error!)); }
    private Guid UserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
    private async Task<ActionResult<CartDto>> Execute(Task<CartResult<CartDto>> task) { var result = await task; if (result.IsSuccess) return Ok(result.Value); return result.ErrorCode == "quantity_limit" ? BadRequest(ApiErrorResponse.Create(result.ErrorCode, result.Error!)) : NotFound(ApiErrorResponse.Create(result.ErrorCode!, result.Error!)); }
}
