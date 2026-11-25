import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:trek_bikes_app/api_config.dart';
import 'package:trek_bikes_app/auth_api.dart';
import 'package:trek_bikes_app/local_database.dart';
import 'package:trek_bikes_app/network_failure.dart';

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
    this.isOffline = false,
  });

  final List<MemberFoodItem> items;
  final int page;
  final int totalItems;
  final int totalPages;
  final bool isOffline;

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
    final cacheKey =
        'food-page:$page:$pageSize:${categoryId ?? ''}:${(search ?? '').trim().toLowerCase()}';
    try {
      final query = <String, String>{'page': '$page', 'pageSize': '$pageSize'};
      if (categoryId != null) query['categoryId'] = '$categoryId';
      if (search != null && search.trim().isNotEmpty)
        query['search'] = search.trim();
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/foods')
                .replace(queryParameters: query),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw const ApiException('Không thể tải món ăn.');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      try {
        await LocalDatabase.instance.saveResponse(cacheKey, data);
        for (final item in data['data'] as List) {
          await LocalDatabase.instance.saveResponse(
            'food:${item['foodItemId']}',
            item,
          );
        }
      } catch (_) {
        /* Cache is optional when online. */
      }
      return MemberFoodPage.fromJson(data);
    } on FormatException {
      throw const ApiException('Dữ liệu món ăn không hợp lệ.');
    } catch (error) {
      if (!isNetworkFailure(error)) rethrow;
      try {
        final data = await LocalDatabase.instance.readResponse(cacheKey);
        if (data is Map<String, dynamic>) {
          final cached = MemberFoodPage.fromJson(data);
          return MemberFoodPage(
            items: cached.items,
            page: cached.page,
            totalItems: cached.totalItems,
            totalPages: cached.totalPages,
            isOffline: true,
          );
        }
      } catch (_) {
        /* No usable cached page. */
      }
      throw const ApiException(
        'Không thể kết nối máy chủ và chưa lưu trang món này.',
      );
    }
  }

  static Future<MemberFoodItem> getById(int id) async {
    try {
      final r = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/api/foods/$id'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200)
        throw const ApiException('Không tìm thấy món ăn.');
      final data = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      try {
        await LocalDatabase.instance.saveResponse('food:$id', data);
      } catch (_) {
        /* Online data remains usable. */
      }
      return MemberFoodItem.fromJson(data);
    } catch (error) {
      if (!isNetworkFailure(error)) rethrow;
      try {
        final data = await LocalDatabase.instance.readResponse('food:$id');
        if (data is Map<String, dynamic>) return MemberFoodItem.fromJson(data);
      } catch (_) {
        /* No usable cached item. */
      }
      throw const ApiException(
        'Không thể kết nối máy chủ và chưa lưu món này.',
      );
    }
  }
}
