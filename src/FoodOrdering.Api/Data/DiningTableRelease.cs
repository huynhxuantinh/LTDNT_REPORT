using FoodOrdering.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace FoodOrdering.Api.Data;

public static class DiningTableRelease
{
    // Run inside the same transaction as the order update. The conditional UPDATE
    // coordinates with the table lock used while creating a new dine-in order.
    public static async Task ReleaseIfUnoccupiedAsync(
        FoodOrderingDbContext db, FoodOrder order, CancellationToken ct)
    {
        if (order.OrderType != "DineIn" || order.TableId is not int tableId) return;

        var now = DateTime.UtcNow;
        await db.DiningTables
            .Where(table => table.TableId == tableId && !db.Orders.Any(other =>
                other.TableId == tableId && other.OrderId != order.OrderId &&
                other.OrderType == "DineIn" && other.PaymentStatus != "Paid" &&
                other.OrderStatus!.Name != "Completed" && other.OrderStatus.Name != "Cancelled"))
            .ExecuteUpdateAsync(setters => setters
                .SetProperty(table => table.Status, "Available")
                .SetProperty(table => table.UpdatedAt, now), ct);
    }
}
