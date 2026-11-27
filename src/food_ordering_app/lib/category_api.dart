import 'package:trek_bikes_app/network_timeout.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:trek_bikes_app/api_config.dart';
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
  static String get _baseUrl => ApiConfig.baseUrl;
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
    final response = await http
        .get(_uri(), headers: await _headers())
        .timeout(apiRequestTimeout);
    _ensure(response, 200);
    final data = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return data
        .map((item) => AdminCategory.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<AdminCategory> create({
    required String name,
    String? description,
  }) async {
    final response = await http
        .post(
          _uri(),
          headers: await _headers(),
          body: jsonEncode({'name': name, 'description': description}),
        )
        .timeout(apiRequestTimeout);
    _ensure(response, 201);
    return AdminCategory.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  static Future<AdminCategory> update({
    required int categoryId,
    required String name,
    String? description,
  }) async {
    final response = await http
        .put(
          _uri('$categoryId'),
          headers: await _headers(),
          body: jsonEncode({'name': name, 'description': description}),
        )
        .timeout(apiRequestTimeout);
    _ensure(response, 200);
    return AdminCategory.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  static Future<void> delete(int categoryId) async {
    final response = await http
        .delete(_uri('$categoryId'), headers: await _headers())
        .timeout(apiRequestTimeout);
    _ensure(response, 204);
  }

  static Future<String> uploadImage(
    int categoryId,
    Uint8List bytes,
    String fileName,
  ) async {
    final lower = fileName.toLowerCase();
    final type = lower.endsWith('.jpg') || lower.endsWith('.jpeg')
        ? MediaType('image', 'jpeg')
        : lower.endsWith('.png')
        ? MediaType('image', 'png')
        : lower.endsWith('.webp')
        ? MediaType('image', 'webp')
        : null;
    if (type == null)
      throw const ApiException('Chỉ hỗ trợ ảnh JPEG, PNG hoặc WEBP.');
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024)
      throw const ApiException('Ảnh phải có dung lượng từ 1 byte đến 5 MB.');
    final headers = await _headers();
    final request =
        http.MultipartRequest('POST', Uri.parse('${_uri('$categoryId')}/image'))
          ..headers['Authorization'] = headers['Authorization']!
          ..files.add(
            http.MultipartFile.fromBytes(
              'image',
              bytes,
              filename: fileName,
              contentType: type,
            ),
          );
    final response = await http.Response.fromStream(
      await request.send().timeout(apiUploadTimeout),
    ).timeout(apiUploadTimeout);
    _ensure(response, 200);
    return (jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>)['imageUrl']
        as String;
  }

  static Future<void> deleteImage(int categoryId) async {
    final response = await http
        .delete(
          Uri.parse('${_uri('$categoryId')}/image'),
          headers: await _headers(),
        )
        .timeout(apiRequestTimeout);
    _ensure(response, 204);
  }

  static void _ensure(http.Response response, int expected) {
    if (response.statusCode == expected) return;
    try {
      final json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final error = json['error'] as Map<String, dynamic>?;
      throw ApiException(error?['message'] as String? ?? 'Có lỗi xảy ra.');
    } on FormatException {
      throw const ApiException('Không thể kết nối đến máy chủ.');
    }
  }
}
