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

    public static string Html(string title, string description, string url, string token)
    {
        var safeTitle = WebUtility.HtmlEncode(title);
        var safeDescription = WebUtility.HtmlEncode(description);
        var safeUrl = WebUtility.HtmlEncode(url);
        var safeToken = WebUtility.HtmlEncode(token);
        var isCode = token.Length == 6 && token.All(c => c >= '0' && c <= '9');
        var codeStyle = isCode ? "font-size:32px;letter-spacing:8px;font-weight:bold" : "font-size:14px;word-break:break-all";
        return $$"""
            <!doctype html>
            <html lang="vi">
            <head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{{safeTitle}}</title></head>
            <body style="margin:0;padding:0;background:#f8f3f0;font-family:Arial,Helvetica,sans-serif;color:#332522;line-height:1.6">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f8f3f0;padding:32px 12px">
                <tr><td align="center">
                  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:520px;background:#ffffff;border-radius:16px;overflow:hidden">
                    <tr><td style="background:#914c3b;padding:22px 28px;color:#ffffff;font-size:19px;font-weight:bold">Food Ordering</td></tr>
                    <tr><td style="padding:32px 28px">
                      <h1 style="margin:0 0 14px;font-size:24px;line-height:1.3;color:#332522">{{safeTitle}}</h1>
                      <p style="margin:0 0 20px;color:#66534d">{{safeDescription}}</p>
                      <p style="margin:0 0 10px;color:#66534d">Mã của bạn:</p>
                      <div style="background:#fff3ee;border:1px solid #f1d5ca;border-radius:10px;padding:18px;text-align:center;color:#914c3b;{{codeStyle}}">{{safeToken}}</div>
                      <p style="margin:24px 0;text-align:center"><a href="{{safeUrl}}" style="display:inline-block;background:#914c3b;color:#ffffff;text-decoration:none;font-weight:bold;padding:12px 24px;border-radius:8px">{{safeTitle}}</a></p>
                      <p style="margin:0;color:#796c67;font-size:13px">Nếu bạn không yêu cầu thao tác này, hãy bỏ qua email và không chia sẻ mã với người khác.</p>
                    </td></tr>
                  </table>
                  <p style="margin:18px 0 0;color:#93817a;font-size:12px">Food Ordering · Email tự động, vui lòng không trả lời.</p>
                </td></tr>
              </table>
            </body></html>
            """;
    }
}
