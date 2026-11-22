using System.Security.Claims;
using FoodOrdering.Api.Common;
using FoodOrdering.Api.Data;
using FoodOrdering.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FoodOrdering.Api.Controllers;

/// <summary>
/// Controller xử lý thanh toán: Tiền mặt (Cash) và Chuyển khoản VietQR.
/// </summary>
[ApiController, Route("api/orders")]
public sealed class PaymentsController(FoodOrderingDbContext db, VietQrOptions vietQrOptions) : ControllerBase
{
    private Guid CurrentUserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
    private bool IsStaffOrAdmin => User.IsInRole("Admin") || User.IsInRole("Staff");

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

        // Nếu là đơn ăn tại bàn (DineIn), giải phóng bàn ăn về Available
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

    /// <summary>
    /// Tạo hoặc lấy mã VietQR của đơn hàng để khách hàng quét chuyển khoản.
    /// Khách hàng (Member) chỉ xem được đơn của mình; Staff/Admin xem được tất cả.
    /// </summary>
    [HttpGet("{orderId:long}/vietqr"), Authorize]
    public async Task<IActionResult> GetVietQr(long orderId, CancellationToken ct)
    {
        var order = await db.Orders.SingleOrDefaultAsync(x => x.OrderId == orderId, ct);
        if (order is null) return NotFound(ApiErrorResponse.Create("order_not_found", "Không tìm thấy đơn hàng."));

        // Kiểm tra quyền: Nếu không phải Staff/Admin thì phải là chủ sở hữu đơn hàng
        if (!IsStaffOrAdmin && order.UserId != CurrentUserId)
        {
            return Forbid();
        }

        // Tạo đường link ảnh QR theo chuẩn Napas của VietQR Quick Link
        var transferContent = order.OrderCode;
        var amount = (long)Math.Round(order.TotalAmount, MidpointRounding.AwayFromZero);
        var qrImageUrl = $"https://img.vietqr.io/image/{vietQrOptions.BankId}-{vietQrOptions.AccountNo}-{vietQrOptions.Template}.png?amount={amount}&addInfo={Uri.EscapeDataString(transferContent)}&accountName={Uri.EscapeDataString(vietQrOptions.AccountName)}";

        // Tìm bản ghi Payment theo phương thức VietQR
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
    /// Xác nhận thanh toán VietQR thành công (Đối soát nhận tiền).
    /// Hỗ trợ Admin, Staff hoặc chính khách hàng (cho mục đích demo/kiểm thử đồ án).
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

        // Nếu là đơn tại bàn (DineIn), chuyển trạng thái bàn về Available
        if (order.OrderType == "DineIn" && order.TableId is int tableId)
        {
            var table = await db.DiningTables.FindAsync([tableId], ct);
            if (table is not null)
            {
                table.Status = "Available";
                table.UpdatedAt = now;
            }
        }

        // Cập nhật bản ghi Payment của VietQR
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
