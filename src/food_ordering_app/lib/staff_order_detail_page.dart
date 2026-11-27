import 'package:food_ordering_app/network_timeout.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:food_ordering_app/api_config.dart';
import 'package:food_ordering_app/app_states.dart';
import 'package:food_ordering_app/money_format.dart';
import 'package:food_ordering_app/session_helper.dart';
import 'package:food_ordering_app/staff_edit_order_page.dart';
import 'package:food_ordering_app/staff_payment_page.dart';
import 'package:food_ordering_app/vietnamese_labels.dart';

class StaffOrderDetailPage extends StatefulWidget {
  const StaffOrderDetailPage({
    super.key,
    required this.orderId,
    this.loadOrder,
  });

  final int orderId;
  final Future<Map<String, dynamic>> Function(int id)? loadOrder;

  @override
  State<StaffOrderDetailPage> createState() => _StaffOrderDetailPageState();
}

class _StaffOrderDetailPageState extends State<StaffOrderDetailPage> {
  late Future<Map<String, dynamic>> _order;

  @override
  void initState() {
    super.initState();
    _order = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    if (widget.loadOrder != null) return widget.loadOrder!(widget.orderId);
    final token = await SessionHelper.accessToken;
    final response = await http
        .get(
          Uri.parse('${ApiConfig.baseUrl}/api/staff/orders/${widget.orderId}'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(apiRequestTimeout);
    if (response.statusCode != 200) throw Exception('Không tải được đơn hàng.');
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  String _value(dynamic value, [String fallback = 'Không có thông tin']) =>
      value is String && value.trim().isNotEmpty ? value : fallback;

  String _date(dynamic raw) {
    if (raw is! String) return 'Không có thông tin';
    final hasZone =
        raw.endsWith('Z') || RegExp(r'[+-]\d\d:\d\d$').hasMatch(raw);
    final date = DateTime.tryParse(hasZone ? raw : '${raw}Z')?.toLocal();
    if (date == null) return 'Không có thông tin';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 125, child: Text(label)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết đơn tại quán')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _order,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const AppLoadingState();
        if (snapshot.hasError || snapshot.data == null) {
          return AppErrorState(onRetry: () => setState(() => _order = _load()));
        }
        final order = snapshot.data!;
        final items = order['items'] as List<dynamic>? ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _value(order['orderCode']),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row('Loại đơn', orderTypeLabel(order['orderType'])),
                    if (order['orderType'] == 'DineIn')
                      _row('Bàn', _value(order['tableCode'])),
                    _row(
                      'Tên khách',
                      _value(order['receiverName'], 'Chưa ghi nhận'),
                    ),
                    _row('Nhân viên tạo', _value(order['createdBy'])),
                    _row('Thời gian tạo', _date(order['createdAt'])),
                    if (order['orderType'] != 'DineIn')
                      _row('Trạng thái', orderStatusLabel(order['status'])),
                    _row(
                      'Thanh toán',
                      paymentStatusLabel(order['paymentStatus']),
                    ),
                    if (order['note'] is String &&
                        (order['note'] as String).trim().isNotEmpty)
                      _row('Ghi chú', order['note'] as String),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Món đã gọi', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (items.isEmpty) const Text('Không có món trong đơn.'),
            ...items.map((raw) {
              final item = raw as Map<String, dynamic>;
              final price = item['unitPrice'] as num;
              final quantity = item['quantity'] as num;
              return Card(
                child: ListTile(
                  title: Text(_value(item['foodNameSnapshot'])),
                  subtitle: Text('${formatVnd(price)} đ × $quantity'),
                  trailing: Text('${formatVnd(price * quantity)} đ'),
                ),
              );
            }),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Tổng cộng: ${formatVnd(order['totalAmount'] as num)} đ',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            if (order['paymentStatus'] == 'Unpaid' &&
                order['status'] != 'Cancelled' &&
                order['status'] != 'Completed' &&
                items.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () async {
                  final changed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StaffEditOrderPage(
                        orderId: widget.orderId,
                        items: items,
                      ),
                    ),
                  );
                  if (changed == true && mounted)
                    setState(() => _order = _load());
                },
                icon: const Icon(Icons.edit),
                label: const Text('Sửa món trong đơn'),
              ),
            FilledButton.icon(
              onPressed:
                  order['status'] == 'Cancelled' &&
                      order['paymentStatus'] != 'Paid'
                  ? null
                  : () async {
                      final paid = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StaffPaymentPage(
                            orderId: widget.orderId,
                            orderCode: _value(order['orderCode']),
                            orderType: order['orderType'] as String,
                            orderStatus: order['status'] as String,
                            paymentStatus: order['paymentStatus'] as String,
                            totalAmount: order['totalAmount'] as num,
                            backLabel: 'Quay lại chi tiết đơn',
                          ),
                        ),
                      );
                      if (paid == true && mounted)
                        setState(() => _order = _load());
                    },
              icon: const Icon(Icons.payments_outlined),
              label: Text(
                order['paymentStatus'] == 'Paid'
                    ? 'Xem thanh toán'
                    : 'Thanh toán',
              ),
            ),
          ],
        );
      },
    ),
  );
}
