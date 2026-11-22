namespace FoodOrdering.Api.Common;

/// <summary>
/// Cấu hình cổng thanh toán VNPay Sandbox.
/// </summary>
public sealed class VnPayOptions
{
    /// <summary>
    /// Mã định danh website (Merchant ID) tại VNPay.
    /// </summary>
    public string TmnCode { get; set; } = "DEMOVNPAY";

    /// <summary>
    /// Chuỗi bí mật dùng để tạo và kiểm tra chữ ký băm (HMAC-SHA512).
    /// </summary>
    public string HashSecret { get; set; } = "SECRETKEYVNPAYDEMO1234567890ABCD";

    /// <summary>
    /// URL cổng thanh toán Sandbox của VNPay.
    /// </summary>
    public string BaseUrl { get; set; } = "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html";

    /// <summary>
    /// URL VNPay sẽ redirect về sau khi thanh toán xong.
    /// </summary>
    public string ReturnUrl { get; set; } = "http://localhost:5000/api/orders/vnpay-return";
}

/// <summary>
/// DTO trả về cho Mobile khi yêu cầu tạo URL thanh toán VNPay.
/// </summary>
public sealed record VnPayPaymentDto(
    long OrderId,
    string OrderCode,
    decimal Amount,
    string PaymentUrl,
    string PaymentStatus);

