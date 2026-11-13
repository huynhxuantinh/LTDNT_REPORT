import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:trek_bikes_app/api_config.dart';
import 'package:trek_bikes_app/auth_api.dart';
import 'package:trek_bikes_app/session_helper.dart';
import 'package:trek_bikes_app/local_database.dart';

class CartItem {
  const CartItem({
    required this.cartItemId,
    required this.foodItemId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
  });
  final int cartItemId, foodItemId, quantity;
  final String name;
  final double unitPrice;
  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
    cartItemId: j['cartItemId'],
    foodItemId: j['foodItemId'],
    name: j['name'],
    unitPrice: (j['unitPrice'] as num).toDouble(),
    quantity: j['quantity'],
  );
}

class Cart {
  const Cart({
    required this.items,
    required this.totalQuantity,
    required this.totalAmount,
  });
  final List<CartItem> items;
  final int totalQuantity;
  final double totalAmount;
  factory Cart.fromJson(Map<String, dynamic> j) => Cart(
    items: (j['items'] as List).map((x) => CartItem.fromJson(x)).toList(),
    totalQuantity: j['totalQuantity'],
    totalAmount: (j['totalAmount'] as num).toDouble(),
  );
}

final cartCount = ValueNotifier<int>(0);

class CartApi {
  static Future<void> syncOfflineCart() async {
    final local = await LocalDatabase.instance.getLocalCartItems();
    for (final item in local) {
      final foodId = item['food_item_id'] as int;
      final quantity = item['quantity'] as int;
      for (var index = 0; index < quantity; index++) { await add(foodId); }
      await LocalDatabase.instance.removeLocalCartItem(foodId);
    }
  }
  static Future<Cart> get() => _request('GET', '');
  static Future<Cart> add(int foodItemId) =>
      _request('POST', '/items', {'foodItemId': foodItemId, 'quantity': 1});
  static Future<Cart> setQuantity(int id, int quantity) =>
      _request('PUT', '/items/$id', {'quantity': quantity});
  static Future<Cart> remove(int id) => _request('DELETE', '/items/$id');
  static Future<void> checkout({
    required String name,
    required String phone,
    required String address,
    String? note,
  }) async {
    final token = await SessionHelper.accessToken;
    final r = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/cart/checkout/delivery'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'receiverName': name,
        'receiverPhone': phone,
        'deliveryAddress': address,
        'note': note,
      }),
    );
    if (r.statusCode != 200) throw const ApiException('Không thể đặt hàng.');
    cartCount.value = 0;
  }

  static Future<Cart> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final token = await SessionHelper.accessToken;
    final request =
        http.Request(method, Uri.parse('${ApiConfig.baseUrl}/api/cart$path'))
          ..headers.addAll({
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          });
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode != 200)
      throw const ApiException('Không thể cập nhật giỏ hàng.');
    final cart = Cart.fromJson(jsonDecode(response.body));
    cartCount.value = cart.totalQuantity;
    return cart;
  }
}
