import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:trek_bikes_app/api_config.dart';
import 'package:trek_bikes_app/auth_api.dart';

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
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/categories'),
      );
      if (response.statusCode != 200) {
        throw const ApiException('Không thể tải danh mục.');
      }
      final data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((item) => MemberCategory.fromJson(item as Map<String, dynamic>))
          .toList();
    } on http.ClientException {
      throw const ApiException('Không thể kết nối máy chủ.');
    } on FormatException {
      throw const ApiException('Dữ liệu danh mục không hợp lệ.');
    }
  }
}
