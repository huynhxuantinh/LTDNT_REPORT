import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:trek_bikes_app/auth_api.dart';
import 'package:trek_bikes_app/session_helper.dart';

class AdminCategory {
  final int categoryId;
  final String name;
  final String? description;
  final String? imageUrl;
  final bool isActive;
  final DateTime createdAt;

  const AdminCategory({
    required this.categoryId,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.isActive,
    required this.createdAt,
  });

  factory AdminCategory.fromJson(Map<String, dynamic> json) => AdminCategory(
    categoryId: json['categoryId'] as int,
    name: json['name'] as String,
    description: json['description'] as String?,
    imageUrl: json['imageUrl'] as String?,
    isActive: json['isActive'] as bool,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class CategoryApi {
  static String get _baseUrl => dotenv.env['API_URL'] ?? 'http://10.0.2.2:5000';
  static Uri _uri([String? categoryId]) => Uri.parse(
    '$_baseUrl/api/admin/categories${categoryId == null ? '' : '/$categoryId'}',
  );

  static Future<Map<String, String>> _headers() async {
    final accessToken = await SessionHelper.accessToken;
    if (accessToken == null || accessToken.isEmpty)
      throw const ApiException('Phiên đăng nhập đã hết hạn.');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
  }

  static Future<List<AdminCategory>> getAll() async {
    final response = await http.get(_uri(), headers: await _headers());
    _ensure(response, 200);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => AdminCategory.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<AdminCategory> create({
    required String name,
    String? description,
  }) async {
    final response = await http.post(
      _uri(),
      headers: await _headers(),
      body: jsonEncode({'name': name, 'description': description}),
    );
    _ensure(response, 201);
    return AdminCategory.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  static Future<AdminCategory> update({
    required int categoryId,
    required String name,
    String? description,
  }) async {
    final response = await http.put(
      _uri('$categoryId'),
      headers: await _headers(),
      body: jsonEncode({'name': name, 'description': description}),
    );
    _ensure(response, 200);
    return AdminCategory.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  static Future<void> delete(int categoryId) async {
    final response = await http.delete(
      _uri('$categoryId'),
      headers: await _headers(),
    );
    _ensure(response, 204);
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
