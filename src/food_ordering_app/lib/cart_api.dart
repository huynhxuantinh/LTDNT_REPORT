import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:trek_bikes_app/api_config.dart';
import 'package:trek_bikes_app/auth_api.dart';
import 'package:trek_bikes_app/local_database.dart';
import 'package:trek_bikes_app/member_food_api.dart';
import 'package:trek_bikes_app/network_failure.dart';
import 'package:trek_bikes_app/session_helper.dart';

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
    cartItemId: j['cartItemId'] as int,
    foodItemId: j['foodItemId'] as int,
    name: j['name'] as String,
    unitPrice: (j['unitPrice'] as num).toDouble(),
    quantity: j['quantity'] as int,
  );
  Map<String, dynamic> toJson() => {
    'cartItemId': cartItemId,
    'foodItemId': foodItemId,
    'name': name,
    'unitPrice': unitPrice,
    'quantity': quantity,
  };
}

class Cart {
  const Cart({
    required this.items,
    required this.totalQuantity,
    required this.totalAmount,
    this.isOffline = false,
    this.syncIssue,
  });
  final List<CartItem> items;
  final int totalQuantity;
  final double totalAmount;
  final bool isOffline;
  final String? syncIssue;
  factory Cart.fromJson(
    Map<String, dynamic> j, {
    bool offline = false,
    String? syncIssue,
  }) => Cart(
    items: (j['items'] as List)
        .map((x) => CartItem.fromJson(x as Map<String, dynamic>))
        .toList(),
    totalQuantity: j['totalQuantity'] as int,
    totalAmount: (j['totalAmount'] as num).toDouble(),
    isOffline: offline,
    syncIssue: syncIssue,
  );
  Map<String, dynamic> toJson() => {
    'items': items.map((item) => item.toJson()).toList(),
    'totalQuantity': totalQuantity,
    'totalAmount': totalAmount,
  };
}

final cartCount = ValueNotifier<int>(0);
final cartSyncRevision = ValueNotifier<int>(0);

class _CartRequestException extends ApiException {
  const _CartRequestException(this.status, super.message);
  final int status;
}

class CartApi {
  static Future<void> _tail = Future.value();
  static Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  static Future<String> _account() async {
    final email = await SessionHelper.email;
    final token = await SessionHelper.accessToken;
    if (email == null || email.trim().isEmpty || token == null || token.isEmpty)
      throw const ApiException('Vui lòng đăng nhập để sử dụng giỏ hàng.');
    return email.trim().toLowerCase();
  }

  static Future<bool> _sameAccount(String account) async {
    try {
      return await _account() == account;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _sqliteAvailable() async {
    try {
      await LocalDatabase.instance.database;
      return true;
    } catch (_) {
      return false;
    }
  }

  static String _operationId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static Future<void> syncOfflineCart() => _serial(() async {
    final account = await _account();
    if (!await _sqliteAvailable()) return;
    final hadPending = (await LocalDatabase.instance.pendingCart(account))
        .isNotEmpty;
    await _sync(account);
    if (hadPending) cartSyncRevision.value++;
  });

  static Future<void> _sync(String account) async {
    final pending = await LocalDatabase.instance.pendingCart(account);
    Cart? latest;
    for (final op in pending) {
      if (await _account() != account)
        throw const ApiException('Tài khoản đã thay đổi.');
      final cart = await _request(
        'POST',
        '/sync-item',
        account: account,
        body: {
          'operationId': op['operation_id'],
          'accountEmail': account,
          'foodItemId': op['food_id'],
          'action': op['action'],
          'quantity': op['quantity'],
        },
      );
      await LocalDatabase.instance.acknowledgeCart(
        account,
        op['operation_id'] as String,
        cart.toJson(),
      );
      latest = cart;
    }
    if (latest != null && await _account() == account)
      cartCount.value = latest.totalQuantity;
  }

  static Future<Cart> get({bool updateCount = true}) => _serial(() async {
    final account = await _account();
    final available = await _sqliteAvailable();
    try {
      if (available) await _sync(account);
      final cart = await _request('GET', '', account: account);
      if (available) {
        try {
          await LocalDatabase.instance.saveCart(account, cart.toJson());
        } catch (_) {
          /* Online cart is still usable. */
        }
      }
      if (updateCount) cartCount.value = cart.totalQuantity;
      return cart;
    } catch (error) {
      final conflict = error is _CartRequestException && error.status == 400;
      if (!available || (!isNetworkFailure(error) && !conflict)) rethrow;
      if (!await _sameAccount(account))
        throw const ApiException('Tài khoản đã thay đổi.');
      final saved = await LocalDatabase.instance.readCart(account);
      if (saved == null)
        throw const ApiException('Chưa có giỏ hàng được lưu trên thiết bị.');
      final cart = Cart.fromJson(
        saved,
        offline: true,
        syncIssue: conflict ? (error as ApiException).message : null,
      );
      if (updateCount) cartCount.value = cart.totalQuantity;
      return cart;
    }
  });

  static Future<Cart> add(int foodItemId) =>
      _serial(() => _change('add', foodItemId, 1));
  static Future<Cart> setQuantity(int id, int quantity) =>
      _serial(() => _change('set', id, quantity));
  static Future<Cart> remove(int id) => _serial(() => _change('remove', id, 0));

  static Future<Cart> _change(String action, int id, int quantity) async {
    final account = await _account();
    if (!await _sqliteAvailable()) {
      final cart = action == 'add'
          ? await _request(
              'POST',
              '/items',
              account: account,
              body: {'foodItemId': id, 'quantity': quantity},
            )
          : action == 'set'
          ? await _request(
              'PUT',
              '/items/$id',
              account: account,
              body: {'quantity': quantity},
            )
          : await _request('DELETE', '/items/$id', account: account);
      cartCount.value = cart.totalQuantity;
      return cart;
    }
    var saved = await LocalDatabase.instance.readCart(account);
    if (saved == null) {
      try {
        await _sync(account);
        final remote = await _request('GET', '', account: account);
        saved = remote.toJson();
        await LocalDatabase.instance.saveCart(account, saved);
      } catch (error) {
        if (!isNetworkFailure(error)) rethrow;
        if (action != 'add')
          throw const ApiException('Chưa có giỏ hàng được lưu trên thiết bị.');
        saved = const Cart(
          items: [],
          totalQuantity: 0,
          totalAmount: 0,
        ).toJson();
      }
    }
    final old = Cart.fromJson(saved);
    final items = [...old.items];
    final index = items.indexWhere(
      (item) => action == 'add' ? item.foodItemId == id : item.cartItemId == id,
    );
    int foodId;
    if (action == 'add') {
      foodId = id;
      if (index >= 0) {
        final item = items[index];
        if (item.quantity >= 99)
          throw const ApiException('Mỗi món tối đa 99 phần.');
        items[index] = CartItem(
          cartItemId: item.cartItemId,
          foodItemId: item.foodItemId,
          name: item.name,
          unitPrice: item.unitPrice,
          quantity: item.quantity + 1,
        );
      } else {
        final food = await MemberFoodApi.getById(id);
        items.add(
          CartItem(
            cartItemId: -id,
            foodItemId: id,
            name: food.name,
            unitPrice: food.price,
            quantity: 1,
          ),
        );
      }
    } else {
      if (index < 0)
        throw const ApiException('Không tìm thấy món trong giỏ hàng.');
      final item = items[index];
      foodId = item.foodItemId;
      if (action == 'remove') {
        items.removeAt(index);
      } else {
        if (quantity < 1 || quantity > 99)
          throw const ApiException('Số lượng phải từ 1 đến 99.');
        items[index] = CartItem(
          cartItemId: item.cartItemId,
          foodItemId: foodId,
          name: item.name,
          unitPrice: item.unitPrice,
          quantity: quantity,
        );
      }
    }
    final local = Cart(
      items: items,
      totalQuantity: items.fold<int>(0, (n, item) => n + item.quantity),
      totalAmount: items.fold<double>(
        0,
        (sum, item) => sum + item.unitPrice * item.quantity,
      ),
      isOffline: true,
    );
    if (!await _sameAccount(account))
      throw const ApiException('Tài khoản đã thay đổi.');
    await LocalDatabase.instance.queueCart(
      account,
      _operationId(),
      foodId,
      action,
      quantity,
      local.toJson(),
    );
    try {
      await _sync(account);
      final synced = await _request('GET', '', account: account);
      await LocalDatabase.instance.saveCart(account, synced.toJson());
      cartCount.value = synced.totalQuantity;
      return synced;
    } catch (error) {
      final conflict = error is _CartRequestException && error.status == 400;
      if (!isNetworkFailure(error) && !conflict) rethrow;
      if (!await _sameAccount(account))
        throw const ApiException('Tài khoản đã thay đổi.');
      final current = await LocalDatabase.instance.readCart(account);
      final offlineCart = current == null
          ? local
          : Cart.fromJson(
              current,
              offline: true,
              syncIssue: conflict ? (error as ApiException).message : null,
            );
      cartCount.value = offlineCart.totalQuantity;
      return offlineCart;
    }
  }

  static Future<Cart> discardPendingChanges() => _serial(() async {
    final account = await _account();
    final remote = await _request('GET', '', account: account);
    await LocalDatabase.instance.discardPendingCart(account, remote.toJson());
    cartCount.value = remote.totalQuantity;
    return remote;
  });

  static Future<int> checkout({
    required String name,
    required String phone,
    required String address,
    String? note,
  }) => _serial(() async {
    final account = await _account();
    final available = await _sqliteAvailable();
    if (available) await _sync(account);
    final token = await SessionHelper.accessToken;
    if (await _account() != account)
      throw const ApiException('Tài khoản đã thay đổi.');
    final r = await http
        .post(
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
        )
        .timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) throw const ApiException('Không thể đặt hàng.');
    final sameAccount = await _sameAccount(account);
    if (sameAccount) cartCount.value = 0;
    if (available && sameAccount) {
      try {
        await LocalDatabase.instance.saveCart(
          account,
          const Cart(items: [], totalQuantity: 0, totalAmount: 0).toJson(),
        );
      } catch (_) {
        /* The order was already created. */
      }
    }
    return (jsonDecode(utf8.decode(r.bodyBytes))
            as Map<String, dynamic>)['orderId']
        as int;
  });

  static Future<Cart> _request(
    String method,
    String path, {
    required String account,
    Map<String, dynamic>? body,
  }) async {
    final token = await SessionHelper.accessToken;
    if (await _account() != account)
      throw const ApiException('Tài khoản đã thay đổi.');
    final request =
        http.Request(method, Uri.parse('${ApiConfig.baseUrl}/api/cart$path'))
          ..headers.addAll({
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          });
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await request.send().timeout(const Duration(seconds: 8)),
    ).timeout(const Duration(seconds: 8));
    if (await _account() != account)
      throw const ApiException('Tài khoản đã thay đổi.');
    if (response.statusCode != 200) {
      try {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        if (json is Map &&
            json['error'] is Map &&
            json['error']['message'] is String)
          throw _CartRequestException(
            response.statusCode,
            json['error']['message'] as String,
          );
      } on FormatException {
        /* Use a generic message. */
      }
      throw _CartRequestException(
        response.statusCode,
        response.statusCode == 401
            ? 'Phiên đăng nhập hết hạn. Hãy đăng nhập lại.'
            : 'Không thể cập nhật giỏ hàng.',
      );
    }
    return Cart.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }
}
