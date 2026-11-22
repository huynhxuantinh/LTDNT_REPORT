import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:trek_bikes_app/api_config.dart';
import 'package:trek_bikes_app/app_states.dart';
import 'package:trek_bikes_app/session_helper.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});
  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  final _search = TextEditingController();
  DateTime? _from, _to;
  int _page = 1;
  late Future<Map<String, dynamic>> _orders;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  void _reload() {
    _orders = _fetch();
  }

  Future<Map<String, dynamic>> _fetch() async {
    final token = await SessionHelper.accessToken;
    final params = <String, String>{
      'page': '$_page',
      'pageSize': '10',
      if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
      if (_from != null) 'fromDate': _date(_from!),
      if (_to != null) 'toDate': _date(_to!),
    };
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/admin/orders')
          .replace(queryParameters: params),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) throw Exception('Không tải được đơn hàng');
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<void> _selectRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5),
    );
    if (range != null && mounted)
      setState(() {
        _from = range.start;
        _to = range.end;
        _page = 1;
        _reload();
      });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quản lý đơn hàng')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _search,
            onSubmitted: (_) => setState(() {
              _page = 1;
              _reload();
            }),
            decoration: InputDecoration(
              labelText: 'Mã đơn, tên hoặc SĐT',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => setState(() {
                  _page = 1;
                  _reload();
                }),
              ),
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _selectRange,
              icon: const Icon(Icons.date_range),
              label: Text(
                _from == null
                    ? 'Chọn khoảng ngày'
                    : '${_date(_from!)} → ${_date(_to!)}',
              ),
            ),
            if (_from != null)
              TextButton(
                onPressed: () => setState(() {
                  _from = null;
                  _to = null;
                  _page = 1;
                  _reload();
                }),
                child: const Text('Xóa lọc ngày'),
              ),
          ],
        ),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _orders,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done)
                return const AppLoadingState();
              if (snapshot.hasError)
                return AppErrorState(onRetry: () => setState(_reload));
              final result = snapshot.data!;
              final items = result['data'] as List;
              final meta = result['meta'] as Map<String, dynamic>;
              final totalPages = meta['totalPages'] as int;
              return Column(
                children: [
                  Expanded(
                    child: items.isEmpty
                        ? const AppEmptyState(
                            message: 'Không tìm thấy đơn hàng.',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final order =
                                  items[index] as Map<String, dynamic>;
                              return Card(
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    child: const Icon(
                                      Icons.receipt_long_outlined,
                                    ),
                                  ),
                                  title: Text(order['orderCode'] as String),
                                  subtitle: Text(
                                    '${order['receiverName'] ?? 'Khách tại quán'} · ${order['status']}',
                                  ),
                                  trailing: Text('${order['totalAmount']} đ'),
                                ),
                              );
                            },
                          ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: _page > 1
                            ? () => setState(() {
                                _page--;
                                _reload();
                              })
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text('Trang $_page/${totalPages == 0 ? 1 : totalPages}'),
                      IconButton(
                        onPressed: _page < totalPages
                            ? () => setState(() {
                                _page++;
                                _reload();
                              })
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}
