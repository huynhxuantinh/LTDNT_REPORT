import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:trek_bikes_app/api_config.dart';
import 'package:trek_bikes_app/money_format.dart';
import 'package:trek_bikes_app/session_helper.dart';
import 'package:trek_bikes_app/vietqr_payment_page.dart';
import 'package:trek_bikes_app/vnpay_payment_page.dart';

class StaffPaymentPage extends StatefulWidget {
  const StaffPaymentPage({
    super.key,
    required this.orderId,
    required this.orderCode,
    required this.orderType,
    required this.orderStatus,
    required this.paymentStatus,
    required this.totalAmount,
  });

  final int orderId;
  final String orderCode;
  final String orderType;
  final String orderStatus;
  final String paymentStatus;
  final num totalAmount;

  @override
  State<StaffPaymentPage> createState() => _StaffPaymentPageState();
}

class _StaffPaymentPageState extends State<StaffPaymentPage> {
  bool busy = false;

  Future<void> _collectCash() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận thu tiền'),
        content: Text('Xác nhận đã nhận ${formatVnd(widget.totalAmount)} đ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đã nhận tiền'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => busy = true);
    try {
      final token = await SessionHelper.accessToken;
      final response = await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/orders/${widget.orderId}/collect-cash',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(body['message'] ?? 'Không thể ghi nhận thanh toán.');
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể thu tiền: $error')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _openVietQr() async {
    final paid = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => VietQrPaymentPage(
          orderId: widget.orderId,
          popToRootOnSuccess: false,
        ),
      ),
    );
    if (paid == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _openVnPay() async {
    final paid = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => VnPayPaymentPage(
          orderId: widget.orderId,
          popToRootOnSuccess: false,
        ),
      ),
    );
    if (paid == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isPaid = widget.paymentStatus == 'Paid';
    final canPay = !isPaid && widget.orderStatus != 'Cancelled';
    final orderTypeLabel = switch (widget.orderType) {
      'DineIn' => 'Ăn tại quán',
      'TakeAway' => 'Mang đi',
      _ => widget.orderType,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Thanh toán đơn tại quán')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: colors.primaryContainer,
                    child: Icon(
                      isPaid ? Icons.check_circle_outline : Icons.payment,
                      size: 32,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isPaid ? 'Đơn đã thanh toán' : 'Chọn hình thức thanh toán',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          _PaymentRow(label: 'Mã đơn', value: widget.orderCode),
                          _PaymentRow(label: 'Loại đơn', value: orderTypeLabel),
                          _PaymentRow(
                            label: 'Trạng thái đơn',
                            value: widget.orderStatus,
                          ),
                          _PaymentRow(
                            label: 'Thanh toán',
                            value: isPaid ? 'Đã thanh toán' : 'Chưa thanh toán',
                          ),
                          const Divider(height: 28),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Tổng cộng'),
                              Text(
                                '${formatVnd(widget.totalAmount)} đ',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: colors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (canPay) ...[
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: busy ? null : _collectCash,
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Tiền mặt tại quán'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: busy ? null : _openVietQr,
                      icon: const Icon(Icons.qr_code_2),
                      label: const Text('Chuyển khoản VietQR'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: busy ? null : _openVnPay,
                      icon: const Icon(Icons.payment),
                      label: const Text('Thanh toán VNPay'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: busy ? null : () => Navigator.pop(context),
                    child: const Text('Quay lại danh sách đơn'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
