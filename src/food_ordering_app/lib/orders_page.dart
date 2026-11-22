import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:trek_bikes_app/api_config.dart';
import 'package:trek_bikes_app/app_states.dart';
import 'package:trek_bikes_app/session_helper.dart';
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

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  late Future<dynamic> orders;
  @override
  void initState() {
    super.initState();
    orders = _load('');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Đơn hàng của tôi')),
        body: FutureBuilder<dynamic>(
          future: orders,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const AppLoadingState();
            }
            if (snapshot.hasError) {
              return AppErrorState(
                onRetry: () => setState(() => orders = _load('')),
              );
            }
            final items = snapshot.data as List;
            if (items.isEmpty) {
              return const AppEmptyState(message: 'Bạn chưa có đơn hàng nào.');
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final order = items[index] as Map<String, dynamic>;
                final isPaid = order['paymentStatus'] == 'Paid';
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: isPaid ? Colors.green.shade100 : Colors.orange.shade100,
                      child: Icon(
                        isPaid ? Icons.check_circle_outline : Icons.receipt_long_outlined,
                        color: isPaid ? Colors.green : Colors.orange,
                      ),
                    ),
                    title: Text(order['orderCode'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${order['status']} · ${isPaid ? "Đã thanh toán" : "Chưa thanh toán"}\n${order['totalAmount']} đ',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderDetailPage(id: order['orderId'] as int),
                      ),
                    ).then((_) {
                      if (mounted) setState(() => orders = _load(''));
                    }),
                  ),
                );
              },
            );
          },
        ),
      );
}

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({super.key, required this.id});
  final int id;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late Future<dynamic> order;
  @override
  void initState() {
    super.initState();
    order = _load('/${widget.id}');
  }

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
                onRetry: () => setState(() => order = _load('/${widget.id}')),
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
                      Text('Món đã đặt', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (items.isEmpty) const Text('Không có chi tiết món.'),
                      ...items.map(
                        (item) => Card(
                          child: ListTile(
                            title: Text(item['foodNameSnapshot'] as String),
                            subtitle: Text('Số lượng: ${item['quantity']}'),
                            trailing: Text('${item['unitPrice']} đ'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Tổng cộng: ${data['totalAmount']} đ',
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
                                  builder: (_) => VietQrPaymentPage(orderId: widget.id),
                                ),
                              );
                              if (mounted) setState(() => order = _load('/${widget.id}'));
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
                                  builder: (_) => VnPayPaymentPage(orderId: widget.id),
                                ),
                              );
                              if (mounted) setState(() => order = _load('/${widget.id}'));
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
