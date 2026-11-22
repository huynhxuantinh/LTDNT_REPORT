using System.Net;
using System.Security.Cryptography;
using System.Text;

namespace FoodOrdering.Api.Common;

/// <summary>
/// Lớp tiện ích xử lý tạo URL và kiểm tra chữ ký HMAC-SHA512 của VNPay.
/// </summary>
public static class VnPayHelper
{
    /// <summary>
    /// Tạo URL thanh toán VNPay kèm chữ ký bảo mật.
    /// </summary>
    public static string CreatePaymentUrl(
        VnPayOptions options,
        long orderId,
        string orderCode,
        decimal amount,
        string ipAddress,
        DateTime? createDate = null)
    {
        var date = createDate ?? DateTime.UtcNow;
        var vnpAmount = (long)Math.Round(amount * 100, MidpointRounding.AwayFromZero);

        var data = new SortedDictionary<string, string>(StringComparer.Ordinal)
        {
            ["vnp_Version"] = "2.1.0",
            ["vnp_Command"] = "pay",
            ["vnp_TmnCode"] = options.TmnCode,
            ["vnp_Amount"] = vnpAmount.ToString(),
            ["vnp_CreateDate"] = date.ToString("yyyyMMddHHmmss"),
            ["vnp_CurrCode"] = "VND",
            ["vnp_IpAddr"] = string.IsNullOrWhiteSpace(ipAddress) ? "127.0.0.1" : ipAddress,
            ["vnp_Locale"] = "vn",
            ["vnp_OrderInfo"] = $"Thanh toan don hang {orderCode}",
            ["vnp_OrderType"] = "other",
            ["vnp_ReturnUrl"] = options.ReturnUrl,
            ["vnp_TxnRef"] = orderId.ToString()
        };

        // Ghép chuỗi dữ liệu để băm chữ ký
        var signData = new StringBuilder();
        var queryData = new StringBuilder();

        foreach (var (key, value) in data)
        {
            if (string.IsNullOrEmpty(value)) continue;

            if (signData.Length > 0)
            {
                signData.Append('&');
                queryData.Append('&');
            }

            signData.Append(WebUtility.UrlEncode(key)).Append('=').Append(WebUtility.UrlEncode(value));
            queryData.Append(WebUtility.UrlEncode(key)).Append('=').Append(WebUtility.UrlEncode(value));
        }

        // Tính chữ ký HMAC-SHA512
        var secureHash = HmacSha512(options.HashSecret, signData.ToString());
        queryData.Append("&vnp_SecureHash=").Append(secureHash);

        return $"{options.BaseUrl}?{queryData}";
    }

    /// <summary>
    /// Kiểm tra chữ ký bảo mật trả về từ VNPay.
    /// </summary>
    public static bool ValidateSignature(IDictionary<string, string> queryParams, string hashSecret)
    {
        if (!queryParams.TryGetValue("vnp_SecureHash", out var secureHash) || string.IsNullOrEmpty(secureHash))
        {
            return false;
        }

        var signData = new StringBuilder();
        var sortedParams = new SortedDictionary<string, string>(queryParams, StringComparer.Ordinal);

        foreach (var (key, value) in sortedParams)
        {
            // Bỏ qua vnp_SecureHash và vnp_SecureHashType khi tính toán
            if (key is "vnp_SecureHash" or "vnp_SecureHashType" || string.IsNullOrEmpty(value))
            {
                continue;
            }

            if (signData.Length > 0) signData.Append('&');
            signData.Append(WebUtility.UrlEncode(key)).Append('=').Append(WebUtility.UrlEncode(value));
        }

        var computedHash = HmacSha512(hashSecret, signData.ToString());
        return string.Equals(computedHash, secureHash, StringComparison.OrdinalIgnoreCase);
    }

    /// <summary>
    /// Hàm băm HMAC-SHA512 chuẩn.
    /// </summary>
    public static string HmacSha512(string key, string input)
    {
        var keyBytes = Encoding.UTF8.GetBytes(key);
        var inputBytes = Encoding.UTF8.GetBytes(input);

        using var hmac = new HMACSHA512(keyBytes);
        var hashBytes = hmac.ComputeHash(inputBytes);
        return Convert.ToHexString(hashBytes).ToLowerInvariant();
    }
}

