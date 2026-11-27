import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:food_ordering_app/api_config.dart';
import 'package:food_ordering_app/app_states.dart';
import 'package:food_ordering_app/member_food_api.dart';
import 'package:food_ordering_app/network_timeout.dart';
import 'package:food_ordering_app/session_helper.dart';

class StaffEditOrderPage extends StatefulWidget {
  const StaffEditOrderPage({
    super.key,
    required this.orderId,
    required this.items,
  });
  final int orderId;
  final List<dynamic> items;

  @override
  State<StaffEditOrderPage> createState() => _StaffEditOrderPageState();
}

class _StaffEditOrderPageState extends State<StaffEditOrderPage> {
  final _search = TextEditingController();
  final Map<int, int> _quantities = {};
  final Map<int, String> _names = {};
  late final List<Map<String, int>> _expected;
  late Future<MemberFoodPage> _foods;
  int _page = 1;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _expected = widget.items.map((raw) {
      final item = raw as Map<String, dynamic>;
      final id = item['foodItemId'] as int;
      final quantity = item['quantity'] as int;
      _quantities[id] = quantity;
      _names[id] = item['foodNameSnapshot'] as String;
      return {
        'orderDetailId': item['orderDetailId'] as int,
        'quantity': quantity,
      };
    }).toList();
    _loadFoods();
  }

  void _loadFoods() {
    _foods = MemberFoodApi.getPage(
      page: _page,
      pageSize: 10,
      search: _search.text,
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_quantities.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final token = await SessionHelper.accessToken;
      final response = await http
          .put(
            Uri.parse(
              '${ApiConfig.baseUrl}/api/staff/orders/${widget.orderId}/items',
            ),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'items': _quantities.entries
                  .map((x) => {'foodItemId': x.key, 'quantity': x.value})
                  .toList(),
              'expectedItems': _expected,
            }),
          )
          .timeout(apiRequestTimeout);
      if (!mounted) return;
      if (response.statusCode == 200) {
        Navigator.pop(context, true);
        return;
      }
      String message = 'Không thể cập nhật đơn. Vui lòng kiểm tra lại.';
      try {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body is Map &&
            body['error'] is Map &&
            body['error']['message'] is String) {
          message = body['error']['message'] as String;
        }
      } catch (_) {}
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } on TimeoutException {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Chưa xác nhận được kết quả. Hãy tải lại chi tiết đơn trước khi thử lại.',
            ),
          ),
        );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể kết nối máy chủ. Vui lòng thử lại.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sửa món trong đơn')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              labelText: 'Tìm món ăn',
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => setState(() {
                  _page = 1;
                  _loadFoods();
                }),
              ),
            ),
            onSubmitted: (_) => setState(() {
              _page = 1;
              _loadFoods();
            }),
          ),
        ),
        if (_quantities.isNotEmpty)
          SizedBox(
            height: 150,
            child: ListView(
              children: _quantities.entries
                  .map(
                    (entry) => ListTile(
                      title: Text(_names[entry.key] ?? 'Món ${entry.key}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Giảm hoặc xóa',
                            onPressed: () => setState(() {
                              if (entry.value == 1) {
                                _quantities.remove(entry.key);
                              } else {
                                _quantities[entry.key] = entry.value - 1;
                              }
                            }),
                            icon: const Icon(Icons.remove),
                          ),
                          Text('${entry.value}'),
                          IconButton(
                            tooltip: 'Tăng số lượng',
                            onPressed: entry.value >= 99
                                ? null
                                : () => setState(
                                    () => _quantities[entry.key] =
                                        entry.value + 1,
                                  ),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        Expanded(
          child: FutureBuilder<MemberFoodPage>(
            future: _foods,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done)
                return const AppLoadingState();
              if (snapshot.hasError)
                return AppErrorState(onRetry: () => setState(_loadFoods));
              final data = snapshot.data!;
              return Column(
                children: [
                  Expanded(
                    child: data.items.isEmpty
                        ? const AppEmptyState(message: 'Không tìm thấy món.')
                        : ListView.builder(
                            itemCount: data.items.length,
                            itemBuilder: (context, index) {
                              final food = data.items[index];
                              return ListTile(
                                title: Text(food.name),
                                trailing: IconButton(
                                  tooltip: 'Thêm món',
                                  icon: const Icon(Icons.add_shopping_cart),
                                  onPressed:
                                      (_quantities[food.foodItemId] ?? 0) >= 99
                                      ? null
                                      : () => setState(() {
                                          _names[food.foodItemId] = food.name;
                                          _quantities[food.foodItemId] =
                                              (_quantities[food.foodItemId] ??
                                                  0) +
                                              1;
                                        }),
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
                                _loadFoods();
                              })
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(
                        'Trang $_page/${data.totalPages == 0 ? 1 : data.totalPages}',
                      ),
                      IconButton(
                        onPressed: _page < data.totalPages
                            ? () => setState(() {
                                _page++;
                                _loadFoods();
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
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _saving || _quantities.isEmpty ? null : _save,
              child: Text(_saving ? 'Đang lưu...' : 'Lưu thay đổi'),
            ),
          ),
        ),
      ],
    ),
  );
}
