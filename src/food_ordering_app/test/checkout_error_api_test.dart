import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:food_ordering_app/auth_api.dart';
import 'package:food_ordering_app/cart_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('checkout preserves the API error code and message', () async {
    dotenv.loadFromString(envString: 'API_URL=http://localhost:5000');
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'token',
      'email': 'an@example.com',
    });
    await http.runWithClient(
      () async {
        await expectLater(
          CartApi.checkout(name: 'An', phone: '123', address: 'Địa chỉ'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.code, 'code', 'food_not_available')
                .having((e) => e.message, 'message', 'Có món không còn bán.'),
          ),
        );
      },
      () => MockClient(
        (request) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'error': {
                'code': 'food_not_available',
                'message': 'Có món không còn bán.',
              },
            }),
          ),
          400,
        ),
      ),
    );
  });
}
