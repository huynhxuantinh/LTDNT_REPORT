import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:trek_bikes_app/api_config.dart';
import 'package:trek_bikes_app/auth_api.dart';
import 'package:trek_bikes_app/session_helper.dart';

class AdminUser {
  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
    required this.verified,
  });
  final String id, name, email, role;
  final bool active, verified;
  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
    id: json['userId'] as String,
    name: json['fullName'] as String,
    email: json['email'] as String,
    role: json['role'] as String,
    active: json['isActive'] as bool,
    verified: json['isEmailVerified'] as bool,
  );
}

class AdminUsersPageData {
  const AdminUsersPageData({
    required this.users,
    required this.page,
    required this.totalPages,
    required this.totalItems,
  });
  final List<AdminUser> users;
  final int page, totalPages, totalItems;
  factory AdminUsersPageData.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>;
    return AdminUsersPageData(
      users: (json['data'] as List)
          .map((x) => AdminUser.fromJson(x as Map<String, dynamic>))
          .toList(),
      page: meta['page'] as int,
      totalPages: meta['totalPages'] as int,
      totalItems: meta['totalItems'] as int,
    );
  }
}

class AdminUsersApi {
  AdminUsersApi({
    http.Client? client,
    Future<String?> Function()? tokenReader,
    String? baseUrl,
  }) : _client = client ?? http.Client(),
       _tokenReader = tokenReader ?? (() => SessionHelper.accessToken),
       _baseUrl = baseUrl ?? ApiConfig.baseUrl;
  final http.Client _client;
  final Future<String?> Function() _tokenReader;
  final String _baseUrl;
  Future<Map<String, String>> _headers() async {
    final token = await _tokenReader();
    if (token == null || token.isEmpty)
      throw const ApiException('Phiên đăng nhập đã hết hạn.');
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  void _check(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final message = (body as Map<String, dynamic>)['error']?['message'];
      if (message is String && message.isNotEmpty) throw ApiException(message);
    } on FormatException {
      /* Fall back to a generic message. */
    }
    throw ApiException(
      response.statusCode == 403
          ? 'Bạn không có quyền quản lý người dùng.'
          : response.statusCode == 401
          ? 'Phiên đăng nhập đã hết hạn.'
          : 'Không thể xử lý yêu cầu.',
    );
  }

  Future<AdminUsersPageData> getUsers({
    required int page,
    String search = '',
  }) async {
    final query = {
      'page': '$page',
      'pageSize': '10',
      if (search.trim().isNotEmpty) 'search': search.trim(),
    };
    final r = await _client.get(
      Uri.parse('$_baseUrl/api/admin/users').replace(queryParameters: query),
      headers: await _headers(),
    );
    _check(r);
    return AdminUsersPageData.fromJson(
      jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<void> setRole(String id, String role) async {
    final r = await _client.put(
      Uri.parse('$_baseUrl/api/admin/users/$id/role'),
      headers: await _headers(),
      body: jsonEncode({'role': role}),
    );
    _check(r);
  }

  Future<void> setActive(String id, bool active) async {
    final r = await _client.put(
      Uri.parse('$_baseUrl/api/admin/users/$id/active-status'),
      headers: await _headers(),
      body: jsonEncode({'isActive': active}),
    );
    _check(r);
  }

  void dispose() => _client.close();
}
