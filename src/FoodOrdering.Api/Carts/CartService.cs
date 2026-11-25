using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using Microsoft.EntityFrameworkCore;
using System.Data;

namespace FoodOrdering.Api.Carts;

public sealed record CartItemDto(int CartItemId, int FoodItemId, string Name, decimal UnitPrice, int Quantity, decimal LineTotal);
public sealed record CartDto(IReadOnlyList<CartItemDto> Items, int TotalQuantity, decimal TotalAmount);
public sealed record CartResult<T>(bool IsSuccess, T? Value, string? ErrorCode, string? Error)
{
    public static CartResult<T> Success(T value) => new(true, value, null, null);
    public static CartResult<T> Failure(string code, string error) => new(false, default, code, error);
}

public sealed class CartService(FoodOrderingDbContext db)
{
    public async Task<CartResult<CartDto>> ApplySyncAsync(Guid userId, Guid operationId, int foodId, string action, int quantity, CancellationToken ct)
    {
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        var previous = await db.CartSyncOperations.SingleOrDefaultAsync(x => x.OperationId == operationId, ct);
        if (previous is not null)
            return previous.UserId == userId ? CartResult<CartDto>.Success(await GetAsync(userId, ct)) : CartResult<CartDto>.Failure("invalid_operation", "Thao tác không hợp lệ.");

        CartResult<CartDto>? result = null;
        var item = await db.CartItems.Include(x => x.Cart).SingleOrDefaultAsync(x => x.Cart!.UserId == userId && x.FoodItemId == foodId, ct);
        if (action == "add" && item is not null && item.Quantity + quantity > 99)
            return CartResult<CartDto>.Failure("quantity_limit", "Mỗi món tối đa 99 phần.");
        if (action == "add") result = await AddAsync(userId, foodId, quantity, ct);
        else if (action == "set" && item is not null) result = await SetQuantityAsync(userId, item.CartItemId, quantity, ct);
        else if (action == "set") result = await AddAsync(userId, foodId, quantity, ct);
        else if (action == "remove" && item is not null) result = await RemoveAsync(userId, item.CartItemId, ct);
        else if (action != "remove") return CartResult<CartDto>.Failure("invalid_operation", "Thao tác không hợp lệ.");
        if (result is { IsSuccess: false }) return result;
        db.CartSyncOperations.Add(new CartSyncOperation { OperationId = operationId, UserId = userId, CreatedAt = DateTime.UtcNow });
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return CartResult<CartDto>.Success(await GetAsync(userId, ct));
    }
    public async Task<CartResult<long>> CheckoutAsync(Guid userId, string name, string phone, string address, string? note, CancellationToken ct)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var cart = await db.Carts.Include(x => x.CartItems).ThenInclude(x => x.FoodItem).SingleOrDefaultAsync(x => x.UserId == userId, ct);
        if (cart is null || cart.CartItems.Count == 0) return CartResult<long>.Failure("cart_empty", "Giỏ hàng đang trống.");
        if (cart.CartItems.Any(x => x.FoodItem is null || !x.FoodItem.IsAvailable)) return CartResult<long>.Failure("food_not_available", "Có món không còn bán.");
        var order = new FoodOrder { OrderCode = $"DLV-{DateTime.UtcNow:yyyyMMddHHmmssfff}", UserId = userId, OrderStatusId = 1, OrderType = "Delivery", ReceiverName = name.Trim(), ReceiverPhone = phone.Trim(), DeliveryAddress = address.Trim(), Note = string.IsNullOrWhiteSpace(note) ? null : note.Trim(), TotalAmount = cart.CartItems.Sum(x => x.UnitPrice * x.Quantity), PaymentStatus = "Unpaid", CreatedAt = DateTime.UtcNow };
        foreach (var item in cart.CartItems) order.OrderDetails.Add(new OrderDetail { FoodItemId = item.FoodItemId, FoodNameSnapshot = item.FoodItem!.Name, ImageUrlSnapshot = item.FoodItem.ImageUrl, UnitPrice = item.UnitPrice, Quantity = item.Quantity });
        db.Orders.Add(order); db.CartItems.RemoveRange(cart.CartItems); await db.SaveChangesAsync(ct); await tx.CommitAsync(ct);
        return CartResult<long>.Success(order.OrderId);
    }
    public async Task<CartDto> GetAsync(Guid userId, CancellationToken ct)
    {
        var items = await (from item in db.CartItems.AsNoTracking()
                           join cart in db.Carts.AsNoTracking() on item.CartId equals cart.CartId
                           join food in db.FoodItems.AsNoTracking() on item.FoodItemId equals food.FoodItemId
                           where cart.UserId == userId
                           orderby item.CartItemId
                           select new CartItemDto(
                               item.CartItemId,
                               item.FoodItemId,
                               food.Name,
                               item.UnitPrice,
                               item.Quantity,
                               item.UnitPrice * item.Quantity))
            .ToListAsync(ct);
        return new CartDto(items, items.Sum(item => item.Quantity), items.Sum(item => item.LineTotal));
    }

    public async Task<CartResult<CartDto>> AddAsync(Guid userId, int foodItemId, int quantity, CancellationToken ct)
    {
        var food = await db.FoodItems.SingleOrDefaultAsync(x => x.FoodItemId == foodItemId && x.IsAvailable, ct);
        if (food is null) return CartResult<CartDto>.Failure("food_not_available", "Món ăn không còn bán.");
        var cart = await db.Carts.Include(x => x.CartItems).ThenInclude(x => x.FoodItem).SingleOrDefaultAsync(x => x.UserId == userId, ct);
        if (cart is null) { cart = new Cart { CartId = Guid.NewGuid(), UserId = userId, UpdatedAt = DateTime.UtcNow }; db.Carts.Add(cart); }
        var item = cart.CartItems.SingleOrDefault(x => x.FoodItemId == foodItemId);
        if (item is null) cart.CartItems.Add(new CartItem { FoodItemId = foodItemId, FoodItem = food, Quantity = quantity, UnitPrice = food.Price, CreatedAt = DateTime.UtcNow });
        else { item.Quantity += quantity; item.UnitPrice = food.Price; item.UpdatedAt = DateTime.UtcNow; }
        cart.UpdatedAt = DateTime.UtcNow; await db.SaveChangesAsync(ct);
        return CartResult<CartDto>.Success(await GetAsync(userId, ct));
    }

    public async Task<CartResult<CartDto>> SetQuantityAsync(Guid userId, int cartItemId, int quantity, CancellationToken ct)
    {
        var item = await db.CartItems.Include(x => x.Cart).SingleOrDefaultAsync(x => x.CartItemId == cartItemId && x.Cart!.UserId == userId, ct);
        if (item is null) return CartResult<CartDto>.Failure("cart_item_not_found", "Không tìm thấy món trong giỏ hàng.");
        item.Quantity = quantity; item.UpdatedAt = DateTime.UtcNow; item.Cart!.UpdatedAt = DateTime.UtcNow; await db.SaveChangesAsync(ct);
        return CartResult<CartDto>.Success(await GetAsync(userId, ct));
    }

    public async Task<CartResult<CartDto>> RemoveAsync(Guid userId, int cartItemId, CancellationToken ct)
    {
        var item = await db.CartItems.Include(x => x.Cart).SingleOrDefaultAsync(x => x.CartItemId == cartItemId && x.Cart!.UserId == userId, ct);
        if (item is null) return CartResult<CartDto>.Failure("cart_item_not_found", "Không tìm thấy món trong giỏ hàng.");
        item.Cart!.UpdatedAt = DateTime.UtcNow; db.CartItems.Remove(item); await db.SaveChangesAsync(ct);
        return CartResult<CartDto>.Success(await GetAsync(userId, ct));
    }
}
