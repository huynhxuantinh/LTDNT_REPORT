namespace FoodOrdering.Api.Common;

/// <summary>
/// Cấu hình thông tin ngân hàng phục vụ tạo mã VietQR chuẩn Napas.
/// </summary>
public sealed class VietQrOptions
{
    /// <summary>
    /// Mã ngân hàng (ví dụ: MB, VCB, ICB, ACB, BIDV...).
    /// </summary>
    public string BankId { get; set; } = "MB";

    /// <summary>
    /// Số tài khoản nhận tiền.
    /// </summary>
    public string AccountNo { get; set; } = "0987654321";

    /// <summary>
    /// Tên chủ tài khoản hiển thị trên mã QR.
    /// </summary>
    public string AccountName { get; set; } = "QUAN AN DEMO";

    /// <summary>
    /// Mẫu giao diện hiển thị của ảnh VietQR (compact, compact2, qr_only...).
    /// </summary>
    public string Template { get; set; } = "compact2";
}

/// <summary>
/// Dữ liệu trả về khi gọi API lấy mã VietQR của đơn hàng.
/// </summary>
public sealed record VietQrPaymentDto(
    long OrderId,
    string OrderCode,
    decimal Amount,
    string BankId,
    string AccountNo,
    string AccountName,
    string TransferContent,
    string QrImageUrl,
    string PaymentStatus);

