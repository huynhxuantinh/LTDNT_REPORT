import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:food_ordering_app/admin_users_api.dart';
import 'package:food_ordering_app/auth_api.dart';

void main() {
  test('sends search, page and token and decodes UTF-8', () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters['page'], '2');
      expect(request.url.queryParameters['search'], 'An');
      expect(request.headers['Authorization'], 'Bearer test-token');
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'data': [
              {
                'userId': 'u1',
                'fullName': 'Nguyễn An',
                'email': 'an@example.com',
                'role': 'Member',
                'isActive': true,
                'isEmailVerified': false,
              },
            ],
            'meta': {'page': 2, 'totalPages': 2, 'totalItems': 11},
          }),
        ),
        200,
      );
    });
    final api = AdminUsersApi(
      client: client,
      tokenReader: () async => 'test-token',
      baseUrl: 'http://localhost',
    );
    final result = await api.getUsers(page: 2, search: ' An ');
    expect(result.users.single.name, 'Nguyễn An');
    expect(result.totalItems, 11);
    api.dispose();
  });
  test('reports API rejection when changing role', () async {
    final client = MockClient((request) async {
      expect(request.method, 'PUT');
      expect(jsonDecode(request.body)['role'], 'Staff');
      return http.Response(
        '{"error":{"message":"Không được phép"}}',
        400,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = AdminUsersApi(
      client: client,
      tokenReader: () async => 'token',
      baseUrl: 'http://localhost',
    );
    await expectLater(api.setRole('u1', 'Staff'), throwsA(isA<ApiException>()));
    api.dispose();
  });
}
