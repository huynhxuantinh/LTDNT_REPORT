using System.Security.Claims;
using FoodOrdering.Api.Controllers;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace FoodOrdering.ConcurrencyTests;

public sealed class StaffOrderEditTests
{
    [SqlServerFact]
    public async Task StaffEditsUnpaidOrderAndRejectsStalePaidOrPendingPayment()
    {
        var connection = new SqlConnectionStringBuilder(Environment.GetEnvironmentVariable("FOOD_ORDERING_TEST_CONNECTION")!)
        {
            InitialCatalog = "codex_edit_test_" + Guid.NewGuid().ToString("N")[..12], Pooling = false,
        };
        var options = new DbContextOptionsBuilder<FoodOrderingDbContext>().UseSqlServer(connection.ConnectionString).Options;
        await using var db = new FoodOrderingDbContext(options);
        var created = false;
        try
        {
            if (await db.Database.CanConnectAsync()) throw new InvalidOperationException("Generated test database already exists.");
            created = await db.Database.EnsureCreatedAsync();
            if (!created) throw new InvalidOperationException("Could not create the isolated test database.");
            var role = new Role { RoleId = 1, RoleName = "Staff" };
            var user = new User { UserId = Guid.NewGuid(), FullName = "Staff", Email = "staff@example.test", PasswordHash = "test", Role = role, IsActive = true, CreatedAt = DateTime.UtcNow };
            var status = new OrderStatus { OrderStatusId = 1, DisplayOrder = 1, Name = "Pending" };
            var category = new Category { Name = "Food", IsActive = true, CreatedAt = DateTime.UtcNow };
            db.Roles.Add(role); db.Users.Add(user); db.OrderStatuses.Add(status); db.Categories.Add(category);
            await db.SaveChangesAsync();
            var oldFood = new FoodItem { Name = "Old", CategoryId = category.CategoryId, Price = 99, IsAvailable = true, CreatedAt = DateTime.UtcNow };
            var newFood = new FoodItem { Name = "New", CategoryId = category.CategoryId, Price = 20, IsAvailable = true, CreatedAt = DateTime.UtcNow };
            db.FoodItems.AddRange(oldFood, newFood); await db.SaveChangesAsync();
            var order = new FoodOrder { OrderCode = "EDIT-1", UserId = user.UserId, OrderStatusId = status.OrderStatusId, OrderType = "TakeAway", PaymentStatus = "Unpaid", TotalAmount = 12, CreatedAt = DateTime.UtcNow };
            order.OrderDetails.Add(new OrderDetail { FoodItemId = oldFood.FoodItemId, FoodNameSnapshot = "Old", UnitPrice = 12, Quantity = 1 });
            db.Orders.Add(order); await db.SaveChangesAsync();
            var firstDetail = order.OrderDetails.Single();
            var request = new UpdateStaffOrderItemsRequest([new(oldFood.FoodItemId, 2), new(newFood.FoodItemId, 1)], [new(firstDetail.OrderDetailId, 1)]);
            var context = new DefaultHttpContext { User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, user.UserId.ToString())], "test")) };
            var controller = new StaffOrdersController(db) { ControllerContext = new ControllerContext { HttpContext = context } };
            Assert.IsType<OkObjectResult>(await controller.UpdateItems(order.OrderId, request, default));
            db.ChangeTracker.Clear();
            var updated = await db.Orders.Include(x => x.OrderDetails).SingleAsync(x => x.OrderId == order.OrderId);
            Assert.Equal(44, updated.TotalAmount);
            Assert.Equal(12, updated.OrderDetails.Single(x => x.FoodItemId == oldFood.FoodItemId).UnitPrice);
            Assert.IsType<ConflictObjectResult>(await controller.UpdateItems(order.OrderId, request, default));

            var expected = updated.OrderDetails.Select(x => new ExpectedStaffOrderLine(x.OrderDetailId, x.Quantity)).ToList();
            var currentRequest = new UpdateStaffOrderItemsRequest([new(newFood.FoodItemId, 1)], expected);
            Assert.IsType<OkObjectResult>(await controller.UpdateItems(order.OrderId, currentRequest, default));
            db.ChangeTracker.Clear();
            updated = await db.Orders.Include(x => x.OrderDetails).SingleAsync(x => x.OrderId == order.OrderId);
            Assert.Single(updated.OrderDetails);
            Assert.Equal(20, updated.TotalAmount);
            expected = updated.OrderDetails.Select(x => new ExpectedStaffOrderLine(x.OrderDetailId, x.Quantity)).ToList();
            currentRequest = new UpdateStaffOrderItemsRequest([new(newFood.FoodItemId, 1)], expected);
            db.Payments.Add(new Payment { OrderId = order.OrderId, Method = "VNPay", Status = "Pending", Amount = 44, CreatedAt = DateTime.UtcNow });
            await db.SaveChangesAsync();
            Assert.IsType<ConflictObjectResult>(await controller.UpdateItems(order.OrderId, currentRequest, default));
            db.Payments.RemoveRange(await db.Payments.ToListAsync());
            updated.PaymentStatus = "Paid"; await db.SaveChangesAsync();
            Assert.IsType<ConflictObjectResult>(await controller.UpdateItems(order.OrderId, currentRequest, default));
            Assert.IsType<BadRequestObjectResult>(await controller.UpdateItems(order.OrderId, new UpdateStaffOrderItemsRequest([new(newFood.FoodItemId, 0)], expected), default));
        }
        finally
        {
            if (created) await db.Database.EnsureDeletedAsync();
        }
    }
}
