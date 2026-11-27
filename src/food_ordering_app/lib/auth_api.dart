import 'package:food_ordering_app/network_timeout.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:food_ordering_app/api_config.dart';

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
  final int? statusCode;
  final String? code;
  const ApiException(this.message, {this.statusCode, this.code});
}

class AuthApi {
  static Future<void> forgotPassword(String email) async {
    final response = await http
        .post(
          _uri('forgot-password'),
          headers: _headers(),
          body: jsonEncode({'email': email.trim()}),
        )
        .timeout(apiRequestTimeout);
    _ensure(response, 200);
  }

  static Future<void> checkPasswordResetCode(String email, String code) async {
    final response = await http
        .post(
          _uri('forgot-password/check-code'),
          headers: _headers(),
          body: jsonEncode({'email': email.trim(), 'code': code.trim()}),
        )
        .timeout(apiRequestTimeout);
    _ensure(response, 200);
  }

  static Future<void> resetPassword(
    String email,
    String code,
    String password,
  ) async {
    final response = await http
        .post(
          _uri('reset-password'),
          headers: _headers(),
          body: jsonEncode({
            'email': email.trim(),
            'code': code.trim(),
            'newPassword': password,
          }),
        )
        .timeout(apiRequestTimeout);
    _ensure(response, 204);
  }

  static Future<void> verifyEmail(String token) async {
    final response = await http
        .post(
          _uri('verify-email'),
          headers: _headers(),
          body: jsonEncode({'token': token.trim()}),
        )
        .timeout(apiRequestTimeout);
    _ensure(response, 200);
  }

  static String get _baseUrl => ApiConfig.baseUrl;
  static Uri _uri(String path) => Uri.parse('$_baseUrl/api/auth/$path');

  static Map<String, String> _headers([String? token]) => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  static Future<void> startRegistration({
    required String fullName,
    required String email,
  }) async {
    final response = await http
        .post(
          _uri('register/start'),
          headers: _headers(),
          body: jsonEncode({'fullName': fullName, 'email': email}),
        )
        .timeout(apiRequestTimeout);
    _ensure(response, 200);
  }

  static Future<void> checkRegistrationCode(String email, String code) async {
    final response = await http
        .post(
          _uri('register/check-code'),
          headers: _headers(),
          body: jsonEncode({'email': email.trim(), 'code': code.trim()}),
        )
        .timeout(apiRequestTimeout);
    _ensure(response, 200);
  }

  static Future<void> completeRegistration(
    String email,
    String code,
    String password,
  ) async {
    final response = await http
        .post(
          _uri('register/complete'),
          headers: _headers(),
          body: jsonEncode({
            'email': email.trim(),
            'code': code.trim(),
            'password': password,
          }),
        )
        .timeout(apiRequestTimeout);
    _ensure(response, 201);
  }

  static Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await http
        .post(
          _uri('login'),
          headers: _headers(),
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(apiRequestTimeout);
    _ensure(response, 200);
    return AuthSession.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  static Future<AuthSession> refresh({required String refreshToken}) async {
    final response = await http
        .post(
          _uri('refresh'),
          headers: _headers(),
          body: jsonEncode({'refreshToken': refreshToken}),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode == 401) {
      throw const ApiException('Phiên đăng nhập đã hết hạn.', statusCode: 401);
    }
    _ensure(response, 200);
    return AuthSession.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  static Future<void> changePassword({
    required String accessToken,
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await http
        .put(
          _uri('change-password'),
          headers: _headers(accessToken),
          body: jsonEncode({
            'currentPassword': currentPassword,
            'newPassword': newPassword,
          }),
        )
        .timeout(apiRequestTimeout);
    _ensure(response, 204);
  }

  static Future<void> logout({
    required String accessToken,
    required String refreshToken,
  }) async {
    final response = await http
        .post(
          _uri('logout'),
          headers: _headers(accessToken),
          body: jsonEncode({'refreshToken': refreshToken}),
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
      throw ApiException(
        error?['message'] as String? ??
            json['message'] as String? ??
            'Có lỗi xảy ra.',
        statusCode: response.statusCode,
      );
    } on FormatException {
      throw ApiException(
        'Không thể xử lý phản hồi từ máy chủ.',
        statusCode: response.statusCode,
      );
    }
  }
}
