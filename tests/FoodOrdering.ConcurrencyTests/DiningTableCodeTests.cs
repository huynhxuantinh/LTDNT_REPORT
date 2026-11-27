using FoodOrdering.Api.Controllers;
using FoodOrdering.Api.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace FoodOrdering.ConcurrencyTests;

public sealed class DiningTableCodeTests
{
    [SqlServerFact]
    public async Task DuplicateTableCodesReturnConflictIncludingConcurrentRequests()
    {
        var connection = new SqlConnectionStringBuilder(Environment.GetEnvironmentVariable("FOOD_ORDERING_TEST_CONNECTION")!)
        {
            InitialCatalog = "codex_table_test_" + Guid.NewGuid().ToString("N")[..12],
            Pooling = false,
        };
        var options = new DbContextOptionsBuilder<FoodOrderingDbContext>().UseSqlServer(connection.ConnectionString).Options;
        await using var db = new FoodOrderingDbContext(options);
        var created = false;
        try
        {
            if (await db.Database.CanConnectAsync()) throw new InvalidOperationException("Generated test database already exists.");
            created = await db.Database.EnsureCreatedAsync();
            if (!created) throw new InvalidOperationException("Could not create the isolated test database.");

            var start = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
            var creates = Enumerable.Range(0, 8).Select(async _ =>
            {
                await using var requestDb = new FoodOrderingDbContext(options);
                var controller = new DiningTablesController(requestDb);
                await start.Task;
                return await controller.Create(new SaveTableRequest(" B01 ", 2), CancellationToken.None);
            }).ToArray();
            start.SetResult();
            var results = await Task.WhenAll(creates);
            Assert.Single(results.OfType<OkObjectResult>());
            Assert.Equal(7, results.OfType<ConflictObjectResult>().Count());

            await using (var createDb = new FoodOrderingDbContext(options))
                Assert.IsType<OkObjectResult>(await new DiningTablesController(createDb).Create(new SaveTableRequest("B02", 2), CancellationToken.None));

            var secondId = await db.DiningTables.Where(x => x.TableCode == "B02").Select(x => x.TableId).SingleAsync();
            await using (var updateDb = new FoodOrderingDbContext(options))
                Assert.IsType<ConflictObjectResult>(await new DiningTablesController(updateDb).Update(secondId, new SaveTableRequest("B01", 2), CancellationToken.None));
            await using (var updateDb = new FoodOrderingDbContext(options))
                Assert.IsType<OkObjectResult>(await new DiningTablesController(updateDb).Update(secondId, new SaveTableRequest(" B02 ", 2), CancellationToken.None));
            await using (var invalidDb = new FoodOrderingDbContext(options))
                Assert.IsType<BadRequestObjectResult>(await new DiningTablesController(invalidDb).Create(new SaveTableRequest("  ", 2), CancellationToken.None));

            Assert.Equal(2, await db.DiningTables.CountAsync());
        }
        finally
        {
            if (created) await db.Database.EnsureDeletedAsync();
        }
    }
}
