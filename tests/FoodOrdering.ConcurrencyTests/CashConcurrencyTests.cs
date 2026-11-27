using System.Security.Claims;
using FoodOrdering.Api.Common;
using FoodOrdering.Api.Controllers;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace FoodOrdering.ConcurrencyTests;

public sealed class SqlServerFactAttribute : FactAttribute
{
    public SqlServerFactAttribute()
    {
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("FOOD_ORDERING_TEST_CONNECTION")))
            Skip = "Set FOOD_ORDERING_TEST_CONNECTION to a SQL Server account that can create a temporary database.";
    }
}

public sealed class CashConcurrencyTests
{
    [SqlServerFact]
    public async Task SimultaneousCashRequestsProduceOnePayment()
    {
        var connection = new SqlConnectionStringBuilder(Environment.GetEnvironmentVariable("FOOD_ORDERING_TEST_CONNECTION")!)
        {
            InitialCatalog = "codex_cash_test_" + Guid.NewGuid().ToString("N")[..12],
            Pooling = false,
        };
        var options = new DbContextOptionsBuilder<FoodOrderingDbContext>().UseSqlServer(connection.ConnectionString).Options;
        await using var db = new FoodOrderingDbContext(options);
        var created = false;
        try
        {
            if (await db.Database.CanConnectAsync())
                throw new InvalidOperationException("The generated test database name already exists.");
            created = await db.Database.EnsureCreatedAsync();
            if (!created) throw new InvalidOperationException("Could not create the isolated test database.");
            var role = new Role { RoleName = "Staff" };
            db.Roles.Add(role);
            await db.SaveChangesAsync();
            var user = new User { UserId = Guid.NewGuid(), FullName = "Test", Email = "cash@example.test", PasswordHash = "test", RoleId = role.RoleId, IsActive = true, CreatedAt = DateTime.UtcNow };
            var status = new OrderStatus { OrderStatusId = 1, DisplayOrder = 1, Name = "Pending" };
            db.Users.Add(user);
            db.OrderStatuses.Add(status);
            await db.SaveChangesAsync();
            var order = new FoodOrder { OrderCode = "CASH-CONCURRENCY", UserId = user.UserId, OrderStatusId = status.OrderStatusId, OrderType = "TakeAway", TotalAmount = 100, PaymentStatus = "Unpaid", CreatedAt = DateTime.UtcNow };
            db.Orders.Add(order);
            await db.SaveChangesAsync();

            var start = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
            var requests = Enumerable.Range(0, 8).Select(async _ =>
            {
                await using var requestDb = new FoodOrderingDbContext(options);
                var http = new DefaultHttpContext();
                http.User = new ClaimsPrincipal(new ClaimsIdentity(new[] { new Claim(ClaimTypes.NameIdentifier, user.UserId.ToString()), new Claim(ClaimTypes.Role, "Staff") }, "test"));
                var controller = new PaymentsController(requestDb, new VietQrOptions(), new VnPayOptions(), new TestEnvironment(), NullLogger<PaymentsController>.Instance)
                {
                    ControllerContext = new ControllerContext { HttpContext = http },
                };
                await start.Task;
                return await controller.CollectCash(order.OrderId, CancellationToken.None);
            }).ToArray();
            start.SetResult();
            var results = await Task.WhenAll(requests);
            Assert.Single(results.OfType<OkObjectResult>());
            Assert.Equal(7, results.OfType<ConflictObjectResult>().Count());
            db.ChangeTracker.Clear();
            Assert.Equal("Paid", (await db.Orders.SingleAsync(x => x.OrderId == order.OrderId)).PaymentStatus);
            Assert.Single(await db.Payments.Where(x => x.OrderId == order.OrderId && x.Method == "Cash").ToListAsync());
        }
        finally
        {
            if (created) await db.Database.EnsureDeletedAsync();
        }
    }

    private sealed class TestEnvironment : IWebHostEnvironment
    {
        public string ApplicationName { get; set; } = "Test";
        public IFileProvider WebRootFileProvider { get; set; } = new NullFileProvider();
        public string WebRootPath { get; set; } = "";
        public string EnvironmentName { get; set; } = "Development";
        public string ContentRootPath { get; set; } = "";
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
