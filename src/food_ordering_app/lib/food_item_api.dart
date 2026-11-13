import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:trek_bikes_app/api_config.dart';
import 'package:trek_bikes_app/auth_api.dart';
import 'package:trek_bikes_app/session_helper.dart';

class AdminFoodItem {
  final int foodItemId;
  final int categoryId;
  final String categoryName;
  final String name;
  final String? description;
  final double price;
  final String? imageUrl;
  final bool isAvailable;
  final DateTime createdAt;

  const AdminFoodItem({
    required this.foodItemId,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.isAvailable,
    required this.createdAt,
  });

  factory AdminFoodItem.fromJson(Map<String, dynamic> json) => AdminFoodItem(
    foodItemId: json['foodItemId'] as int,
    categoryId: json['categoryId'] as int,
    categoryName: json['categoryName'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    price: (json['price'] as num).toDouble(),
    imageUrl: json['imageUrl'] as String?,
    isAvailable: json['isAvailable'] as bool,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class AdminFoodPage {
  final List<AdminFoodItem> items;
  final int page;
  final int pageSize;
  final int totalItems;
  final int totalPages;

  const AdminFoodPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalItems,
    required this.totalPages,
  });

  factory AdminFoodPage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>;
    return AdminFoodPage(
      items: (json['data'] as List<dynamic>)
          .map((item) => AdminFoodItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      page: meta['page'] as int,
      pageSize: meta['pageSize'] as int,
      totalItems: meta['totalItems'] as int,
      totalPages: meta['totalPages'] as int,
    );
  }
}

class FoodItemApi {
  static String get _baseUrl => ApiConfig.baseUrl;

  static Future<AdminFoodPage> getPage({
    required int page,
    required int pageSize,
    int? categoryId,
    String? search,
  }) async {
    final query = <String, String>{'page': '$page', 'pageSize': '$pageSize'};
    if (categoryId != null) query['categoryId'] = '$categoryId';
    if (search != null && search.trim().isNotEmpty)
      query['search'] = search.trim();
    final response = await http.get(
      Uri.parse('$_baseUrl/api/admin/food-items')
          .replace(queryParameters: query),
      headers: await _headers(),
    );
    _ensure(response, 200);
    return AdminFoodPage.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  static Future<Map<String, String>> _headers() async {
    final accessToken = await SessionHelper.accessToken;
    if (accessToken == null || accessToken.isEmpty)
      throw const ApiException('Phiên đăng nhập đã hết hạn.');
    return {'Authorization': 'Bearer $accessToken'};
  }

  static void _ensure(http.Response response, int expected) {
    if (response.statusCode == expected) return;
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final error = json['error'] as Map<String, dynamic>?;
      throw ApiException(error?['message'] as String? ?? 'Có lỗi xảy ra.');
    } on FormatException {
      throw const ApiException('Không thể kết nối đến máy chủ.');
    }
  }
}
