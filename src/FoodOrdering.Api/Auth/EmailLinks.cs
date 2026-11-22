using System.Net;

namespace FoodOrdering.Api.Auth;

public static class EmailLinks
{
    public static string Create(IConfiguration config, string path, string token)
    {
        var baseUrl = config["EmailLinks:BaseUrl"] ?? "http://localhost:5000";
        if (!Uri.TryCreate(baseUrl, UriKind.Absolute, out var uri) || (uri.Scheme != Uri.UriSchemeHttp && uri.Scheme != Uri.UriSchemeHttps) || !string.IsNullOrEmpty(uri.Query) || !string.IsNullOrEmpty(uri.Fragment))
            throw new InvalidOperationException("EmailLinks:BaseUrl không hợp lệ.");
        return $"{baseUrl.TrimEnd('/')}{path}?token={Uri.EscapeDataString(token)}";
    }

    public static string Html(string title, string description, string url, string token) =>
        $"<!doctype html><html lang=\"vi\"><body style=\"font-family:Arial,sans-serif;color:#292929;line-height:1.5\"><h2>{WebUtility.HtmlEncode(title)}</h2><p>{WebUtility.HtmlEncode(description)}</p><p><a href=\"{WebUtility.HtmlEncode(url)}\" style=\"background:#a0442d;color:white;padding:12px 18px;text-decoration:none;border-radius:6px\">{WebUtility.HtmlEncode(title)}</a></p><p>Hoặc nhập mã này trong ứng dụng:</p><p><code>{WebUtility.HtmlEncode(token)}</code></p><p>Nếu bạn không yêu cầu, hãy bỏ qua email này.</p></body></html>";
}
