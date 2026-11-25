import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:trek_bikes_app/api_config.dart';
import 'package:trek_bikes_app/auth_api.dart';
import 'package:trek_bikes_app/local_database.dart';
import 'package:trek_bikes_app/network_failure.dart';

class MemberCategory {
  const MemberCategory({
    required this.categoryId,
    required this.name,
    this.description,
    this.imageUrl,
  });

  final int categoryId;
  final String name;
  final String? description;
  final String? imageUrl;

  factory MemberCategory.fromJson(Map<String, dynamic> json) => MemberCategory(
    categoryId: json['categoryId'] as int,
    name: json['name'] as String,
    description: json['description'] as String?,
    imageUrl: json['imageUrl'] as String?,
  );
}

class MemberCategoryApi {
  static Future<List<MemberCategory>> getAll() async {
    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/api/categories'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw const ApiException('Không thể tải danh mục.');
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      try {
        await LocalDatabase.instance.saveResponse('categories', data);
      } catch (_) {
        /* Cache is optional when online. */
      }
      return data
          .map((item) => MemberCategory.fromJson(item as Map<String, dynamic>))
          .toList();
    } on FormatException {
      throw const ApiException('Dữ liệu danh mục không hợp lệ.');
    } catch (error) {
      if (!isNetworkFailure(error)) rethrow;
      try {
        final cached = await LocalDatabase.instance.readResponse('categories');
        if (cached is List)
          return cached
              .map(
                (item) => MemberCategory.fromJson(item as Map<String, dynamic>),
              )
              .toList();
      } catch (_) {
        /* No usable cached data. */
      }
      throw const ApiException(
        'Không thể kết nối máy chủ và chưa có dữ liệu đã lưu.',
      );
    }
  }
}
