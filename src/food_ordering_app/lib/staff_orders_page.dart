import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:trek_bikes_app/api_config.dart';
import 'package:trek_bikes_app/app_states.dart';
import 'package:trek_bikes_app/session_helper.dart';

class StaffOrdersPage extends StatefulWidget {
  const StaffOrdersPage({super.key});
  @override
  State<StaffOrdersPage> createState() => _StaffOrdersPageState();
}

class _StaffOrdersPageState extends State<StaffOrdersPage> {
  late Future<List<dynamic>> orders;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    orders = load();
  }

  Future<List<dynamic>> load() async {
    final token = await SessionHelper.accessToken;
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/staff/orders'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) throw Exception('Không tải được đơn hàng');
    return jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
  }

  Future<void> action(int id, {String? status}) async {
    setState(() => busy = true);
    try {
      final token = await SessionHelper.accessToken;
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      final response = status == null
          ? await http.post(
              Uri.parse('${ApiConfig.baseUrl}/api/orders/$id/collect-cash'),
              headers: headers,
            )
          : await http.put(
              Uri.parse('${ApiConfig.baseUrl}/api/staff/orders/$id/status'),
              headers: headers,
              body: jsonEncode({'status': status}),
            );
      if (response.statusCode != 200) throw Exception('Cập nhật thất bại');
      if (mounted) setState(reload);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể cập nhật đơn. Vui lòng thử lại.'),
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Xử lý đơn tại quán')),
    body: FutureBuilder<List<dynamic>>(
      future: orders,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const AppLoadingState();
        if (snapshot.hasError)
          return AppErrorState(onRetry: () => setState(reload));
        final list = snapshot.data!;
        if (list.isEmpty)
          return const AppEmptyState(message: 'Chưa có đơn tại quán.');
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final order = list[i] as Map<String, dynamic>;
            final id = order['orderId'] as int;
            final status = order['status'] as String;
            final next = switch (status) {
              'Pending' => 'Confirmed',
              'Confirmed' => 'Preparing',
              'Preparing' => 'Completed',
              _ => null,
            };
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order['orderCode'] as String),
                    Text(
                      '${order['orderType']} · $status · ${order['paymentStatus']}',
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (next != null)
                          OutlinedButton(
                            onPressed: busy
                                ? null
                                : () => action(id, status: next),
                            child: Text('Chuyển $next'),
                          ),
                        if (next != null)
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => action(id, status: 'Cancelled'),
                            child: const Text('Hủy đơn'),
                          ),
                        if (order['paymentStatus'] == 'Unpaid' &&
                            status != 'Cancelled')
                          FilledButton(
                            onPressed: busy ? null : () => action(id),
                            child: const Text('Thu tiền'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
