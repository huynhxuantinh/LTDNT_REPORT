import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:trek_bikes_app/api_config.dart';
import 'package:trek_bikes_app/app_states.dart';
import 'package:trek_bikes_app/session_helper.dart';
import 'package:trek_bikes_app/money_format.dart';
import 'package:trek_bikes_app/vietqr_payment_page.dart';
import 'package:trek_bikes_app/vnpay_payment_page.dart';

Future<dynamic> _load(String path) async {
  final token = await SessionHelper.accessToken;
  final response = await http.get(
    Uri.parse('${ApiConfig.baseUrl}/api/orders$path'),
    headers: {'Authorization': 'Bearer $token'},
  );
  if (response.statusCode != 200) throw Exception('Không tải được đơn hàng');
  return jsonDecode(utf8.decode(response.bodyBytes));
}

DateTime? _parseOrderDate(dynamic raw) {
  if (raw is! String) return null;
  final normalized =
      raw.endsWith('Z') || RegExp(r'[+-]\d\d:\d\d$').hasMatch(raw)
      ? raw
      : '${raw}Z';
  return DateTime.tryParse(normalized)?.toLocal();
}

String? _deliveryEstimate(Map<String, dynamic> order) {
  if (order['orderType'] != 'Delivery') return null;
  if (order['status'] == 'Completed') return 'Đơn đã hoàn thành';
  if (order['status'] == 'Cancelled') return 'Đơn đã hủy';

  final createdAt = _parseOrderDate(order['createdAt']);
  if (createdAt == null) return null;
  final eta = createdAt.add(const Duration(minutes: 45));
  final time =
      '${eta.hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')}';
  return eta.isBefore(DateTime.now())
      ? 'Đã quá giờ dự kiến ($time)'
      : 'Dự kiến giao khoảng $time';
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final _searchController = TextEditingController();
  late Future<dynamic> orders;
  String _search = '';

  @override
  void initState() {
    super.initState();
    orders = _loadOrders();
  }

  Future<dynamic> _loadOrders() {
    final query = _search.isEmpty
        ? ''
        : '?${Uri(queryParameters: {'search': _search}).query}';
    return _load(query);
  }

  void _submitSearch() {
    FocusScope.of(context).unfocus();
    setState(() {
      _search = _searchController.text.trim();
      orders = _loadOrders();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đơn hàng của tôi')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _submitSearch(),
            decoration: InputDecoration(
              hintText: 'Tìm theo mã đơn, tên hoặc SĐT',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Xóa tìm kiếm',
                    onPressed: () {
                      _searchController.clear();
                      _submitSearch();
                    },
                    icon: const Icon(Icons.clear),
                  ),
                  IconButton(
                    tooltip: 'Tìm kiếm',
                    onPressed: _submitSearch,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ],
              ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<dynamic>(
            future: orders,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const AppLoadingState();
              }
              if (snapshot.hasError) {
                return AppErrorState(
                  onRetry: () => setState(() => orders = _loadOrders()),
                );
              }
              final items = snapshot.data as List;
              if (items.isEmpty) {
                return AppEmptyState(
                  message: _search.isEmpty
                      ? 'Bạn chưa có đơn hàng nào.'
                      : 'Không tìm thấy đơn hàng phù hợp.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final order = items[index] as Map<String, dynamic>;
                  final isPaid = order['paymentStatus'] == 'Paid';
                  final estimate = _deliveryEstimate(order);
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: isPaid
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                        child: Icon(
                          isPaid
                              ? Icons.check_circle_outline
                              : Icons.receipt_long_outlined,
                          color: isPaid ? Colors.green : Colors.orange,
                        ),
                      ),
                      title: Text(
                        order['orderCode'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${order['status']} · ${isPaid ? "Đã thanh toán" : "Chưa thanh toán"}\n${formatVnd(order['totalAmount'] as num)} đ${estimate == null ? '' : '\n$estimate'}',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  OrderDetailPage(id: order['orderId'] as int),
                            ),
                          ).then((_) {
                            if (mounted) setState(() => orders = _loadOrders());
                          }),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({super.key, required this.id, this.loadOrder});
  final int id;
  final Future<dynamic> Function(int id)? loadOrder;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late Future<dynamic> order;
  @override
  void initState() {
    super.initState();
    order = _fetchOrder();
  }

  Future<dynamic> _fetchOrder() =>
      widget.loadOrder?.call(widget.id) ?? _load('/${widget.id}');

  String _date(dynamic raw) {
    final value = _parseOrderDate(raw);
    if (value == null) return 'Không có thông tin';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} ${two(value.hour)}:${two(value.minute)}';
  }

  String _value(dynamic value) =>
      value is String && value.trim().isNotEmpty ? value : 'Không có thông tin';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết đơn hàng')),
    body: FutureBuilder<dynamic>(
      future: order,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AppLoadingState();
        }
        if (snapshot.hasError) {
          return AppErrorState(
            onRetry: () => setState(() => order = _fetchOrder()),
          );
        }
        final data = snapshot.data as Map<String, dynamic>;
        final items = data['items'] as List;
        final isPaid = data['paymentStatus'] == 'Paid';

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      title: Text(
                        data['orderCode'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Trạng thái: ${data['status']}\nThanh toán: ${isPaid ? "Đã thanh toán" : "Chưa thanh toán"}',
                        style: TextStyle(
                          color: isPaid ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      isThreeLine: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Thông tin đơn hàng',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _detailRow('Ngày đặt', _date(data['createdAt'])),
                          _detailRow('Loại đơn', switch (data['orderType']) {
                            'Delivery' => 'Giao hàng',
                            'DineIn' => 'Ăn tại quán',
                            'TakeAway' => 'Mang đi',
                            _ => _value(data['orderType']),
                          }),
                          if (data['orderType'] == 'Delivery' &&
                              _deliveryEstimate(data) != null)
                            _detailRow(
                              'Thời gian giao',
                              _deliveryEstimate(data)!,
                            ),
                          if (data['orderType'] == 'Delivery' ||
                              data['deliveryAddress'] != null) ...[
                            _detailRow(
                              'Người nhận',
                              _value(data['receiverName']),
                            ),
                            _detailRow(
                              'Số điện thoại',
                              _value(data['receiverPhone']),
                            ),
                            _detailRow(
                              'Địa chỉ giao hàng',
                              _value(data['deliveryAddress']),
                            ),
                          ],
                          _detailRow('Ghi chú', _value(data['note'])),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Món đã đặt',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (items.isEmpty) const Text('Không có chi tiết món.'),
                  ...items.map(
                    (item) => Card(
                      child: ListTile(
                        title: Text(item['foodNameSnapshot'] as String),
                        subtitle: Text(
                          'Số lượng: ${item['quantity']} · Đơn giá: ${formatVnd(item['unitPrice'] as num)} đ',
                        ),
                        trailing: Text(
                          '${formatVnd((item['unitPrice'] as num) * (item['quantity'] as num))} đ',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Tổng cộng: ${formatVnd(data['totalAmount'] as num)} đ',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!isPaid)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.qr_code_2),
                        label: const Text('VietQR'),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  VietQrPaymentPage(orderId: widget.id),
                            ),
                          );
                          if (mounted) setState(() => order = _fetchOrder());
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.payment),
                        label: const Text('VNPay'),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  VnPayPaymentPage(orderId: widget.id),
                            ),
                          );
                          if (mounted) setState(() => order = _fetchOrder());
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    ),
  );
}

Widget _detailRow(String label, String value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 130, child: Text(label)),
      Expanded(
        child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ),
    ],
  ),
);
