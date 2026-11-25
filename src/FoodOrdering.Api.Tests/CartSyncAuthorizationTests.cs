using System.Security.Claims;
using FoodOrdering.Api.Carts;
using FoodOrdering.Api.Controllers;
using FoodOrdering.Api.Data;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace FoodOrdering.Api.Tests;

public sealed class CartSyncAuthorizationTests
{
    [Fact]
    public async Task CannotSyncOperationsUnderAnotherAccount()
    {
        await using var db = new FoodOrderingDbContext(new DbContextOptionsBuilder<FoodOrderingDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        var user = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, Guid.NewGuid().ToString()), new Claim(ClaimTypes.Email, "a@example.com")], "test"));
        var controller = new CartController(new CartService(db)) { ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext { User = user } } };
        var result = await controller.Sync(new SyncCartItemRequest(Guid.NewGuid(), "b@example.com", 1, "add", 1), CancellationToken.None);
        Assert.IsType<ForbidResult>(result.Result);
        Assert.Empty(db.CartSyncOperations);
    }
}
