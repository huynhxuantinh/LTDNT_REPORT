using FoodOrdering.Api.Auth;
using Xunit;

namespace FoodOrdering.Api.Tests;

public sealed class EmailLinksTests
{
    [Fact]
    public void Html_ShowsCodeAndEscapesValues()
    {
        var html = EmailLinks.Html("Xác nhận <email>", "Thời hạn 10 phút", "https://example.test/?a=1&b=2", "012345");
        Assert.Contains("012345", html);
        Assert.Contains("&lt;email&gt;", html);
        Assert.DoesNotContain("<email>", html);
        Assert.Contains("a=1&amp;b=2", html);
        Assert.Contains("Thời hạn 10 phút", System.Net.WebUtility.HtmlDecode(html));
        Assert.Contains("font-size:32px", html);
    }
}
