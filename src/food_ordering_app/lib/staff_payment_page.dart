import 'package:flutter/material.dart';

class StaffPaymentPage extends StatelessWidget {
  const StaffPaymentPage({
    super.key,
    required this.orderCode,
    required this.orderType,
    required this.orderStatus,
    required this.paymentStatus,
    required this.totalAmount,
  });
  final String orderCode;
  final String orderType;
  final String orderStatus;
  final String paymentStatus;
  final num totalAmount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Thanh toán tại quán')),
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
                      Icons.receipt_long_outlined,
                      size: 32,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Thông tin thanh toán',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Kiểm tra thông tin đơn hàng trước khi thu tiền.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          _PaymentRow(label: 'Mã đơn', value: orderCode),
                          _PaymentRow(
                            label: 'Loại đơn',
                            value: orderType == 'DineIn'
                                ? 'Ăn tại quán'
                                : orderType == 'TakeAway'
                                ? 'Mang đi'
                                : orderType,
                          ),
                          _PaymentRow(
                            label: 'Trạng thái đơn',
                            value: orderStatus,
                          ),
                          _PaymentRow(
                            label: 'Thanh toán',
                            value: paymentStatus == 'Paid'
                                ? 'Đã thanh toán'
                                : paymentStatus == 'Unpaid'
                                ? 'Chưa thanh toán'
                                : paymentStatus,
                          ),
                          const Divider(height: 28),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Tổng cộng'),
                              Text(
                                '${totalAmount.toStringAsFixed(0)} đ',
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
                  const SizedBox(height: 16),
                  const Text(
                    'Màn hình hiển thị thông tin đơn. Tính năng thanh toán trực tuyến sẽ được bổ sung sau.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Quay lại đơn hàng'),
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
