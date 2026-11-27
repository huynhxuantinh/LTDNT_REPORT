import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:food_ordering_app/orders_page.dart';

void main() {
  testWidgets('member searches orders through the API and clears the search', (
    tester,
  ) async {
    dotenv.loadFromString(envString: 'API_URL=http://localhost:5000');
    FlutterSecureStorage.setMockInitialValues({'access_token': 'token'});
    final searches = <String?>[];
    final client = MockClient((request) async {
      expect(request.url.path, '/api/orders');
      expect(request.headers['Authorization'], 'Bearer token');
      final search = request.url.queryParameters['search'];
      searches.add(search);
      return http.Response(
        jsonEncode(
          search == null
              ? [
                  {
                    'orderId': 1,
                    'orderCode': 'DH001',
                    'paymentStatus': 'Unpaid',
                    'status': 'Pending',
                    'orderType': 'TakeAway',
                    'totalAmount': 10000,
                  },
                ]
              : [],
        ),
        200,
      );
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: OrdersPage()));
      await tester.pumpAndSettle();
      expect(find.text('DH001'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '  Nguyễn & An  ');
      await tester.tap(find.byTooltip('Tìm kiếm'));
      await tester.pumpAndSettle();
      expect(searches.last, 'Nguyễn & An');
      expect(find.text('Không tìm thấy đơn hàng phù hợp.'), findsOneWidget);
      await tester.tap(find.byTooltip('Xóa tìm kiếm'));
      await tester.pumpAndSettle();
      expect(searches.last, isNull);
      expect(find.text('DH001'), findsOneWidget);
    }, () => client);
  });
}
