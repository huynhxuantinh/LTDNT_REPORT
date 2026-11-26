import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:trek_bikes_app/api_config.dart';
import 'package:trek_bikes_app/session_helper.dart';
import 'package:trek_bikes_app/member_food_api.dart';
import 'package:trek_bikes_app/app_states.dart';
import 'package:trek_bikes_app/staff_payment_page.dart';

class StaffOrderPage extends StatefulWidget {
  const StaffOrderPage({super.key, this.loadFoods, this.loadTables});
  final Future<MemberFoodPage> Function(int page, int pageSize, String search)?
  loadFoods;
  final Future<List<dynamic>> Function()? loadTables;
  @override
  State<StaffOrderPage> createState() => _StaffOrderPageState();
}

class _StaffOrderPageState extends State<StaffOrderPage> {
  String type = 'DineIn';
  int? tableId;
  bool saving = false;
  final items = <int, int>{};
  late Future<List<dynamic>> tables;
  late Future<MemberFoodPage> foods;
  static const _pageSize = 10;
  int _foodPage = 1;
  final _searchController = TextEditingController();
  final _customerController = TextEditingController();
  String _search = '';
  @override
  void initState() {
    super.initState();
    tables = widget.loadTables?.call() ?? _tables();
    foods = _loadFoods();
  }

  Future<MemberFoodPage> _loadFoods() =>
      widget.loadFoods?.call(_foodPage, _pageSize, _search) ??
      MemberFoodApi.getPage(
        page: _foodPage,
        pageSize: _pageSize,
        search: _search,
      );

  void _applySearch() {
    FocusScope.of(context).unfocus();
    setState(() {
      _search = _searchController.text.trim();
      _foodPage = 1;
      foods = _loadFoods();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customerController.dispose();
    super.dispose();
  }

  void _goToFoodPage(int page) => setState(() {
    _foodPage = page;
    foods = _loadFoods();
  });

  Future<List<dynamic>> _tables() async {
    final t = await SessionHelper.accessToken;
    final r = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/staff/tables/available'),
      headers: {'Authorization': 'Bearer $t'},
    );
    if (r.statusCode != 200) throw Exception('Không tải được bàn');
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  Future<void> _create({bool goToPayment = false}) async {
    setState(() => saving = true);
    try {
      final t = await SessionHelper.accessToken;
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/staff/orders'),
        headers: {
          'Authorization': 'Bearer $t',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'orderType': type,
          'tableId': type == 'DineIn' ? tableId : null,
          'receiverName': _customerController.text.trim(),
          'items': items.entries
              .map((x) => {'foodItemId': x.key, 'quantity': x.value})
              .toList(),
        }),
      );
      if (response.statusCode != 200 && response.statusCode != 201)
        throw Exception('Tạo đơn thất bại');
      if (mounted) {
        setState(() {
          items.clear();
          _customerController.clear();
          tableId = null;
          tables = widget.loadTables?.call() ?? _tables();
        });
        if (goToPayment) {
          Map<String, dynamic>? order;
          try {
            order = jsonDecode(
              utf8.decode(response.bodyBytes),
            ) as Map<String, dynamic>;
          } catch (_) {
            // The order is already saved; avoid submitting it a second time.
          }
          if (order?['orderId'] is int &&
              order?['orderCode'] is String &&
              order?['orderType'] is String &&
              order?['status'] is String &&
              order?['paymentStatus'] is String &&
              order?['totalAmount'] is num) {
            final paid = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => StaffPaymentPage(
                  orderId: order!['orderId'] as int,
                  orderCode: order['orderCode'] as String,
                  orderType: order['orderType'] as String,
                  orderStatus: order['status'] as String,
                  paymentStatus: order['paymentStatus'] as String,
                  totalAmount: order['totalAmount'] as num,
                  backLabel: 'Quay lại tạo đơn',
                ),
              ),
            );
            if (mounted) {
              setState(() => tables = widget.loadTables?.call() ?? _tables());
              if (paid == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã thanh toán đơn.')),
                );
              }
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Đã tạo đơn. Mở Xử lý đơn tại quán để thanh toán.',
                ),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Đã tạo đơn.')));
        }
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tạo được đơn. Kiểm tra bàn và kết nối.'),
          ),
        );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Nhân viên tạo đơn')),
    body: Column(
      children: [
        DropdownButton<String>(
          value: type,
          items: const [
            DropdownMenuItem(value: 'DineIn', child: Text('Ăn tại quán')),
            DropdownMenuItem(value: 'TakeAway', child: Text('Mang đi')),
          ],
          onChanged: (v) => setState(() => type = v!),
        ),
        if (type == 'DineIn')
          FutureBuilder<List<dynamic>>(
            future: tables,
            builder: (c, s) => DropdownButton<int>(
              value: tableId,
              hint: const Text('Chọn bàn'),
              items: (s.data ?? [])
                  .map(
                    (x) => DropdownMenuItem(
                      value: x['tableId'] as int,
                      child: Text(x['tableCode']),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => tableId = v),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _customerController,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Tên khách (không bắt buộc)',
              prefixIcon: Icon(Icons.person_outline),
              counterText: '',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _applySearch(),
            decoration: InputDecoration(
              hintText: 'Tìm món ăn',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Xóa tìm kiếm',
                    onPressed: () {
                      _searchController.clear();
                      _applySearch();
                    },
                    icon: const Icon(Icons.clear),
                  ),
                  IconButton(
                    tooltip: 'Tìm kiếm',
                    onPressed: _applySearch,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ],
              ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<MemberFoodPage>(
            future: foods,
            builder: (c, s) {
              if (s.connectionState != ConnectionState.done) {
                return const AppLoadingState(message: 'Đang tải món ăn...');
              }
              if (s.hasError) {
                return AppErrorState(
                  onRetry: () => setState(() => foods = _loadFoods()),
                );
              }
              final result = s.data!;
              return Column(
                children: [
                  if (result.isOffline)
                    const Text('Đang xem món đã lưu trên máy.'),
                  Expanded(
                    child: result.items.isEmpty
                        ? const AppEmptyState(message: 'Không tìm thấy món ăn.')
                        : ListView.builder(
                            itemCount: result.items.length,
                            itemBuilder: (context, index) {
                              final f = result.items[index];
                              return ListTile(
                                title: Text(f.name),
                                trailing: items.containsKey(f.foodItemId)
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            onPressed: () => setState(
                                              () => items[f.foodItemId] == 1
                                                  ? items.remove(f.foodItemId)
                                                  : items[f.foodItemId] =
                                                        items[f.foodItemId]! -
                                                        1,
                                            ),
                                            icon: const Icon(Icons.remove),
                                          ),
                                          Text('${items[f.foodItemId]}'),
                                          IconButton(
                                            onPressed:
                                                items[f.foodItemId]! >= 99
                                                ? null
                                                : () => setState(
                                                    () => items[f.foodItemId] =
                                                        items[f.foodItemId]! +
                                                        1,
                                                  ),
                                            icon: const Icon(Icons.add),
                                          ),
                                        ],
                                      )
                                    : IconButton(
                                        onPressed: () => setState(
                                          () => items[f.foodItemId] = 1,
                                        ),
                                        icon: const Icon(
                                          Icons.add_shopping_cart,
                                        ),
                                      ),
                              );
                            },
                          ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Trang trước',
                        onPressed: _foodPage > 1
                            ? () => _goToFoodPage(_foodPage - 1)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(
                        'Trang ${result.page}/${result.totalPages == 0 ? 1 : result.totalPages}',
                      ),
                      IconButton(
                        tooltip: 'Trang sau',
                        onPressed: _foodPage < result.totalPages
                            ? () => _goToFoodPage(_foodPage + 1)
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
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          children: [
            OutlinedButton(
              onPressed:
                  saving ||
                      items.isEmpty ||
                      (type == 'DineIn' && tableId == null)
                  ? null
                  : () => _create(),
              child: const Text('Tạo đơn'),
            ),
            FilledButton.icon(
              onPressed:
                  saving ||
                      items.isEmpty ||
                      (type == 'DineIn' && tableId == null)
                  ? null
                  : () => _create(goToPayment: true),
              icon: const Icon(Icons.payment),
              label: const Text('Tạo đơn và thanh toán'),
            ),
          ],
        ),
      ],
    ),
  );
}
