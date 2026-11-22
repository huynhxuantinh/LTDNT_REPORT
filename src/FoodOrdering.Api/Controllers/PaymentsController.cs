using System.Security.Claims;
using FoodOrdering.Api.Common;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FoodOrdering.Api.Controllers;

/// <summary>
/// Controller xử lý thanh toán: Tiền mặt (Cash), Chuyển khoản VietQR, và Cổng VNPay Sandbox.
/// </summary>
[ApiController, Route("api/orders")]
public sealed class PaymentsController(
    FoodOrderingDbContext db,
    VietQrOptions vietQrOptions,
    VnPayOptions vnPayOptions) : ControllerBase
{
    private Guid CurrentUserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
    private bool IsStaffOrAdmin => User.IsInRole("Admin") || User.IsInRole("Staff");

    // ==========================================
    // 1. THANH TOÁN TIỀN MẶT (CASH / COD)
    // ==========================================

    /// <summary>
    /// Staff hoặc Admin xác nhận thu tiền mặt cho đơn hàng (COD hoặc tại quán).
    /// </summary>
    [HttpPost("{orderId:long}/collect-cash"), Authorize(Roles = "Admin,Staff")]
    public async Task<IActionResult> CollectCash(long orderId, CancellationToken ct)
    {
        var order = await db.Orders.SingleOrDefaultAsync(x => x.OrderId == orderId, ct);
        if (order is null) return NotFound(ApiErrorResponse.Create("order_not_found", "Không tìm thấy đơn hàng."));
        if (order.PaymentStatus == "Paid") return Conflict(ApiErrorResponse.Create("order_already_paid", "Đơn hàng đã thanh toán."));

        order.PaymentStatus = "Paid";
        order.UpdatedAt = DateTime.UtcNow;

        if (order.OrderType == "DineIn" && order.TableId is int tableId)
        {
            var table = await db.DiningTables.FindAsync([tableId], ct);
            if (table is not null)
            {
                table.Status = "Available";
                table.UpdatedAt = DateTime.UtcNow;
            }
        }

        db.Payments.Add(new Payment
        {
            OrderId = orderId,
            Method = "Cash",
            Status = "Paid",
            Amount = order.TotalAmount,
            PaidAt = DateTime.UtcNow,
            CreatedAt = DateTime.UtcNow
        });

        await db.SaveChangesAsync(ct);
        return Ok(new { orderId, paymentStatus = order.PaymentStatus });
    }

    // ==========================================
    // 2. THANH TOÁN VIETQR (QUÉT MÃ CHUYỂN KHOẢN)
    // ==========================================

    /// <summary>
    /// Lấy hoặc tạo mã VietQR theo chuẩn Napas để khách hàng quét chuyển khoản.
    /// </summary>
    [HttpGet("{orderId:long}/vietqr"), Authorize]
    public async Task<IActionResult> GetVietQr(long orderId, CancellationToken ct)
    {
        var order = await db.Orders.SingleOrDefaultAsync(x => x.OrderId == orderId, ct);
        if (order is null) return NotFound(ApiErrorResponse.Create("order_not_found", "Không tìm thấy đơn hàng."));

        if (!IsStaffOrAdmin && order.UserId != CurrentUserId)
        {
            return Forbid();
        }

        var transferContent = order.OrderCode;
        var amount = (long)Math.Round(order.TotalAmount, MidpointRounding.AwayFromZero);
        var qrImageUrl = $"https://img.vietqr.io/image/{vietQrOptions.BankId}-{vietQrOptions.AccountNo}-{vietQrOptions.Template}.png?amount={amount}&addInfo={Uri.EscapeDataString(transferContent)}&accountName={Uri.EscapeDataString(vietQrOptions.AccountName)}";

        var payment = await db.Payments.FirstOrDefaultAsync(p => p.OrderId == orderId && p.Method == "VietQR", ct);
        if (payment is null)
        {
            payment = new Payment
            {
                OrderId = orderId,
                Method = "VietQR",
                Status = order.PaymentStatus == "Paid" ? "Paid" : "Pending",
                Amount = order.TotalAmount,
                PaymentUrl = qrImageUrl,
                PaidAt = order.PaymentStatus == "Paid" ? DateTime.UtcNow : null,
                CreatedAt = DateTime.UtcNow
            };
            db.Payments.Add(payment);
        }
        else
        {
            payment.PaymentUrl = qrImageUrl;
            payment.Amount = order.TotalAmount;
        }

        await db.SaveChangesAsync(ct);

        var dto = new VietQrPaymentDto(
            order.OrderId,
            order.OrderCode,
            order.TotalAmount,
            vietQrOptions.BankId,
            vietQrOptions.AccountNo,
            vietQrOptions.AccountName,
            transferContent,
            qrImageUrl,
            order.PaymentStatus);

        return Ok(dto);
    }

    /// <summary>
    /// Xác nhận thanh toán VietQR thành công (Đối soát nhận tiền / Demo).
    /// </summary>
    [HttpPost("{orderId:long}/vietqr/confirm"), Authorize]
    public async Task<IActionResult> ConfirmVietQr(long orderId, CancellationToken ct)
    {
        var order = await db.Orders.SingleOrDefaultAsync(x => x.OrderId == orderId, ct);
        if (order is null) return NotFound(ApiErrorResponse.Create("order_not_found", "Không tìm thấy đơn hàng."));

        if (!IsStaffOrAdmin && order.UserId != CurrentUserId)
        {
            return Forbid();
        }

        if (order.PaymentStatus == "Paid")
        {
            return Conflict(ApiErrorResponse.Create("order_already_paid", "Đơn hàng đã được thanh toán trước đó."));
        }

        var now = DateTime.UtcNow;
        order.PaymentStatus = "Paid";
        order.UpdatedAt = now;

        if (order.OrderType == "DineIn" && order.TableId is int tableId)
        {
            var table = await db.DiningTables.FindAsync([tableId], ct);
            if (table is not null)
            {
                table.Status = "Available";
                table.UpdatedAt = now;
            }
        }

        var payment = await db.Payments.FirstOrDefaultAsync(p => p.OrderId == orderId && p.Method == "VietQR", ct);
        if (payment is null)
        {
            db.Payments.Add(new Payment
            {
                OrderId = orderId,
                Method = "VietQR",
                Status = "Paid",
                Amount = order.TotalAmount,
                PaidAt = now,
                CreatedAt = now
            });
        }
        else
        {
            payment.Status = "Paid";
            payment.PaidAt = now;
        }

        await db.SaveChangesAsync(ct);
        return Ok(new { orderId, paymentStatus = order.PaymentStatus, paidAt = now });
    }

    // ==========================================
    // 3. THANH TOÁN VNPAY SANDBOX
    // ==========================================

    /// <summary>
    /// Tạo URL thanh toán VNPay Sandbox có băm chữ ký HMAC-SHA512.
    /// </summary>
    [HttpGet("{orderId:long}/vnpay"), Authorize]
    public async Task<IActionResult> GetVnPayUrl(long orderId, CancellationToken ct)
    {
        var order = await db.Orders.SingleOrDefaultAsync(x => x.OrderId == orderId, ct);
        if (order is null) return NotFound(ApiErrorResponse.Create("order_not_found", "Không tìm thấy đơn hàng."));

        if (!IsStaffOrAdmin && order.UserId != CurrentUserId)
        {
            return Forbid();
        }

        var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "127.0.0.1";
        var paymentUrl = VnPayHelper.CreatePaymentUrl(vnPayOptions, order.OrderId, order.OrderCode, order.TotalAmount, ipAddress);

        // Lưu hoặc cập nhật bản ghi Payment với Method = "VNPay"
        var payment = await db.Payments.FirstOrDefaultAsync(p => p.OrderId == orderId && p.Method == "VNPay", ct);
        if (payment is null)
        {
            payment = new Payment
            {
                OrderId = orderId,
                Method = "VNPay",
                Status = order.PaymentStatus == "Paid" ? "Paid" : "Pending",
                Amount = order.TotalAmount,
                PaymentUrl = paymentUrl,
                PaidAt = order.PaymentStatus == "Paid" ? DateTime.UtcNow : null,
                CreatedAt = DateTime.UtcNow
            };
            db.Payments.Add(payment);
        }
        else
        {
            payment.PaymentUrl = paymentUrl;
            payment.Amount = order.TotalAmount;
        }

        await db.SaveChangesAsync(ct);

        var dto = new VnPayPaymentDto(
            order.OrderId,
            order.OrderCode,
            order.TotalAmount,
            paymentUrl,
            order.PaymentStatus);

        return Ok(dto);
    }

    /// <summary>
    /// Endpoint nhận callback trả về từ cổng thanh toán VNPay sau khi khách hàng hoàn tất giao dịch.
    /// Kiểm tra chữ ký HMAC-SHA512 và cập nhật trạng thái đơn hàng (idempotent).
    /// </summary>
    [HttpGet("vnpay-return"), AllowAnonymous]
    public async Task<IActionResult> VnPayReturn(CancellationToken ct)
    {
        var queryParams = HttpContext.Request.Query
            .ToDictionary(k => k.Key, v => v.Value.ToString());

        var isValidSignature = VnPayHelper.ValidateSignature(queryParams, vnPayOptions.HashSecret);
        if (!isValidSignature)
        {
            return Content("<html><body style='font-family:sans-serif;text-align:center;padding:50px;'><h2 style='color:red;'>Lỗi: Chữ ký VNPay không hợp lệ!</h2></body></html>", "text/html");
        }

        if (!queryParams.TryGetValue("vnp_TxnRef", out var txnRef) || !long.TryParse(txnRef, out var orderId))
        {
            return Content("<html><body style='font-family:sans-serif;text-align:center;padding:50px;'><h2 style='color:red;'>Lỗi: Mã đơn hàng không hợp lệ!</h2></body></html>", "text/html");
        }

        var responseCode = queryParams.GetValueOrDefault("vnp_ResponseCode");
        var transactionNo = queryParams.GetValueOrDefault("vnp_TransactionNo");
        var isSuccess = responseCode == "00";

        var order = await db.Orders.SingleOrDefaultAsync(x => x.OrderId == orderId, ct);
        if (order is not null)
        {
            var now = DateTime.UtcNow;
            var payment = await db.Payments.FirstOrDefaultAsync(p => p.OrderId == orderId && p.Method == "VNPay", ct);

            if (isSuccess)
            {
                // Cập nhật trạng thái nếu chưa Paid (đảm bảo tính Idempotent)
                if (order.PaymentStatus != "Paid")
                {
                    order.PaymentStatus = "Paid";
                    order.UpdatedAt = now;

                    if (order.OrderType == "DineIn" && order.TableId is int tableId)
                    {
                        var table = await db.DiningTables.FindAsync([tableId], ct);
                        if (table is not null)
                        {
                            table.Status = "Available";
                            table.UpdatedAt = now;
                        }
                    }
                }

                if (payment is null)
                {
                    db.Payments.Add(new Payment
                    {
                        OrderId = orderId,
                        Method = "VNPay",
                        Status = "Paid",
                        Amount = order.TotalAmount,
                        ProviderTxnCode = transactionNo,
                        PaidAt = now,
                        CreatedAt = now
                    });
                }
                else
                {
                    payment.Status = "Paid";
                    payment.ProviderTxnCode = transactionNo;
                    payment.PaidAt = now;
                }
            }
            else
            {
                if (payment is not null && payment.Status != "Paid")
                {
                    payment.Status = "Failed";
                    payment.ProviderTxnCode = transactionNo;
                }
            }

            await db.SaveChangesAsync(ct);
        }

        var html = isSuccess
            ? $"<html><body style='font-family:sans-serif;text-align:center;padding:50px;'><h2 style='color:green;'>✓ Thanh toán VNPay thành công!</h2><p>Mã giao dịch VNPay: <b>{transactionNo}</b></p><p>Bạn có thể đóng trang này và quay lại ứng dụng.</p></body></html>"
            : $"<html><body style='font-family:sans-serif;text-align:center;padding:50px;'><h2 style='color:red;'>✗ Giao dịch VNPay không thành công!</h2><p>Mã lỗi phản hồi: <b>{responseCode}</b></p><p>Bạn có thể đóng trang này và thử lại.</p></body></html>";

        return Content(html, "text/html");
    }

    /// <summary>
    /// Giả lập xác nhận thanh toán VNPay thành công (Dùng cho Demo / Kiểm thử offline khi bảo vệ).
    /// </summary>
    [HttpPost("{orderId:long}/vnpay/simulate-success"), Authorize]
    public async Task<IActionResult> SimulateVnPaySuccess(long orderId, CancellationToken ct)
    {
        var order = await db.Orders.SingleOrDefaultAsync(x => x.OrderId == orderId, ct);
        if (order is null) return NotFound(ApiErrorResponse.Create("order_not_found", "Không tìm thấy đơn hàng."));

        if (!IsStaffOrAdmin && order.UserId != CurrentUserId)
        {
            return Forbid();
        }

        if (order.PaymentStatus == "Paid")
        {
            return Conflict(ApiErrorResponse.Create("order_already_paid", "Đơn hàng đã thanh toán."));
        }

        var now = DateTime.UtcNow;
        var fakeTxnNo = $"VNP-DEMO-{now.Ticks}";

        order.PaymentStatus = "Paid";
        order.UpdatedAt = now;

        if (order.OrderType == "DineIn" && order.TableId is int tableId)
        {
            var table = await db.DiningTables.FindAsync([tableId], ct);
            if (table is not null)
            {
                table.Status = "Available";
                table.UpdatedAt = now;
            }
        }

        var payment = await db.Payments.FirstOrDefaultAsync(p => p.OrderId == orderId && p.Method == "VNPay", ct);
        if (payment is null)
        {
            db.Payments.Add(new Payment
            {
                OrderId = orderId,
                Method = "VNPay",
                Status = "Paid",
                Amount = order.TotalAmount,
                ProviderTxnCode = fakeTxnNo,
                PaidAt = now,
                CreatedAt = now
            });
        }
        else
        {
            payment.Status = "Paid";
            payment.ProviderTxnCode = fakeTxnNo;
            payment.PaidAt = now;
        }

        await db.SaveChangesAsync(ct);
        return Ok(new { orderId, paymentStatus = order.PaymentStatus, transactionNo = fakeTxnNo, paidAt = now });
    }

    // ==========================================
    // 4. TRẠNG THÁI THANH TOÁN CHUNG
    // ==========================================

    /// <summary>
    /// Kiểm tra trạng thái thanh toán hiện tại của đơn hàng.
    /// </summary>
    [HttpGet("{orderId:long}/payment-status"), Authorize]
    public async Task<IActionResult> GetPaymentStatus(long orderId, CancellationToken ct)
    {
        var order = await db.Orders.AsNoTracking().SingleOrDefaultAsync(x => x.OrderId == orderId, ct);
        if (order is null) return NotFound(ApiErrorResponse.Create("order_not_found", "Không tìm thấy đơn hàng."));

        if (!IsStaffOrAdmin && order.UserId != CurrentUserId)
        {
            return Forbid();
        }

        return Ok(new { orderId = order.OrderId, paymentStatus = order.PaymentStatus });
    }
}
