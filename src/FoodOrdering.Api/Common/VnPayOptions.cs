namespace FoodOrdering.Api.Common;

/// <summary>
/// Cấu hình cổng thanh toán VNPay Sandbox.
/// </summary>
public sealed class VnPayOptions
{
    /// <summary>
    /// Mã định danh website (Merchant ID) tại VNPay.
    /// </summary>
    public string TmnCode { get; set; } = string.Empty;

    /// <summary>
    /// Chuỗi bí mật dùng để tạo và kiểm tra chữ ký băm (HMAC-SHA512).
    /// </summary>
    public string HashSecret { get; set; } = string.Empty;

    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(TmnCode)
        && !string.Equals(TmnCode.Trim(), "DEMOVNPAY", StringComparison.OrdinalIgnoreCase)
        && VnPayHelper.IsUsableSecret(HashSecret);

    public bool HasUsableReturnUrl =>
        Uri.TryCreate(ReturnUrl, UriKind.Absolute, out var uri)
        && (uri.Scheme == Uri.UriSchemeHttp || uri.Scheme == Uri.UriSchemeHttps)
        && !uri.IsLoopback
        && uri.Host != "0.0.0.0";

    /// <summary>
    /// URL cổng thanh toán Sandbox của VNPay.
    /// </summary>
    public string BaseUrl { get; set; } = "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html";

    /// <summary>
    /// URL VNPay sẽ redirect về sau khi thanh toán xong.
    /// </summary>
    public string ReturnUrl { get; set; } = string.Empty;
}

/// <summary>
/// DTO trả về cho Mobile khi yêu cầu tạo URL thanh toán VNPay.
/// </summary>
public sealed record VnPayPaymentDto(
    long OrderId,
    string OrderCode,
    decimal Amount,
    string PaymentUrl,
    string PaymentStatus,
    bool DemoEnabled);

