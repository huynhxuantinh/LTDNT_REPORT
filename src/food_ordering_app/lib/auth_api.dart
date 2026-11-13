import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AuthSession {
  final String userId;
  final String fullName;
  final String email;
  final String role;
  final String accessToken;
  final String refreshToken;

  const AuthSession({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    userId: json['userId'] as String,
    fullName: json['fullName'] as String,
    email: json['email'] as String,
    role: json['role'] as String,
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
  );
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
}

class AuthApi {
  static String get _baseUrl => dotenv.env['API_URL'] ?? 'http://10.0.2.2:5000';
  static Uri _uri(String path) => Uri.parse('$_baseUrl/api/auth/$path');

  static Map<String, String> _headers([String? token]) => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  static Future<void> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      _uri('register'),
      headers: _headers(),
      body: jsonEncode({
        'fullName': fullName,
        'email': email,
        'password': password,
      }),
    );
    _ensure(response, 201);
  }

  static Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      _uri('login'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    _ensure(response, 200);
    return AuthSession.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  static Future<AuthSession> refresh({required String refreshToken}) async {
    final response = await http.post(
      _uri('refresh'),
      headers: _headers(),
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    _ensure(response, 200);
    return AuthSession.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  static Future<void> changePassword({
    required String accessToken,
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await http.put(
      _uri('change-password'),
      headers: _headers(accessToken),
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );
    _ensure(response, 204);
  }

  static Future<void> logout({
    required String accessToken,
    required String refreshToken,
  }) async {
    final response = await http.post(
      _uri('logout'),
      headers: _headers(accessToken),
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    _ensure(response, 204);
  }

  static void _ensure(http.Response response, int expected) {
    if (response.statusCode == expected) return;
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final error = json['error'] as Map<String, dynamic>?;
      throw ApiException(
        error?['message'] as String? ??
            json['message'] as String? ??
            'Có lỗi xảy ra.',
      );
    } on FormatException {
      throw const ApiException('Không thể kết nối đến máy chủ.');
    }
  }
}
