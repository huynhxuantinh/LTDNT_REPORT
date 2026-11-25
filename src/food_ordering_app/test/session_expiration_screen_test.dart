import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trek_bikes_app/main.dart';

void main() {
  testWidgets('expired refresh returns the user to login with a message', (
    tester,
  ) async {
    dotenv.loadFromString(envString: 'API_URL=http://localhost:5000');
    final payload = base64Url
        .encode(
          utf8.encode(
            jsonEncode({
              'exp':
                  DateTime.now()
                      .subtract(const Duration(minutes: 1))
                      .millisecondsSinceEpoch ~/
                  1000,
            }),
          ),
        )
        .replaceAll('=', '');
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'header.$payload.signature',
      'refresh_token': 'invalid',
      'role': 'Member',
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(const FoodOrderingApp());
      await tester.pumpAndSettle();
      expect(find.text('Đăng nhập'), findsWidgets);
      expect(
        find.text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((_) async => http.Response('', 401)));
  });
}
