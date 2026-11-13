import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:trek_bikes_app/api_config.dart';
import 'package:trek_bikes_app/auth_api.dart';

class MemberFoodItem {
  const MemberFoodItem({
    required this.foodItemId,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.price,
    this.description,
    this.imageUrl,
  });

  final int foodItemId;
  final int categoryId;
  final String categoryName;
  final String name;
  final String? description;
  final double price;
  final String? imageUrl;

  factory MemberFoodItem.fromJson(Map<String, dynamic> json) => MemberFoodItem(
    foodItemId: json['foodItemId'] as int,
    categoryId: json['categoryId'] as int,
    categoryName: json['categoryName'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    price: (json['price'] as num).toDouble(),
    imageUrl: json['imageUrl'] as String?,
  );
}

class MemberFoodPage {
  const MemberFoodPage({
    required this.items,
    required this.page,
    required this.totalItems,
    required this.totalPages,
  });

  final List<MemberFoodItem> items;
  final int page;
  final int totalItems;
  final int totalPages;

  factory MemberFoodPage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>;
    return MemberFoodPage(
      items: (json['data'] as List<dynamic>)
          .map((item) => MemberFoodItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      page: meta['page'] as int,
      totalItems: meta['totalItems'] as int,
      totalPages: meta['totalPages'] as int,
    );
  }
}

class MemberFoodApi {
  static Future<MemberFoodPage> getPage({
    required int page,
    required int pageSize,
    int? categoryId,
    String? search,
  }) async {
    try {
      final query = <String, String>{'page': '$page', 'pageSize': '$pageSize'};
      if (categoryId != null) query['categoryId'] = '$categoryId';
      if (search != null && search.trim().isNotEmpty)
        query['search'] = search.trim();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/foods')
            .replace(queryParameters: query),
      );
      if (response.statusCode != 200) {
        throw const ApiException('Không thể tải món ăn.');
      }
      return MemberFoodPage.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } on http.ClientException {
      throw const ApiException('Không thể kết nối máy chủ.');
    } on FormatException {
      throw const ApiException('Dữ liệu món ăn không hợp lệ.');
    }
  }

  static Future<MemberFoodItem> getById(int id) async {
    final r = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/foods/$id'));
    if (r.statusCode != 200) throw const ApiException('Không tìm thấy món ăn.');
    return MemberFoodItem.fromJson(jsonDecode(r.body));
  }
}
