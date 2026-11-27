import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trek_bikes_app/member_food_api.dart';
import 'package:trek_bikes_app/staff_order_page.dart';

void main() {
  testWidgets('creates one staff order then opens its payment screen', (
    tester,
  ) async {
    dotenv.loadFromString(envString: 'API_URL=http://localhost:5000');
    FlutterSecureStorage.setMockInitialValues({'access_token': 'token'});
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      expect(request.url.path, '/api/staff/orders');
      expect(request.method, 'POST');
      expect(jsonDecode(request.body)['items'], [
        {'foodItemId': 1, 'quantity': 1},
      ]);
      expect(jsonDecode(utf8.decode(request.bodyBytes))['receiverName'], '');
      return http.Response(
        jsonEncode({
          'orderId': 123,
          'orderCode': 'OFF-123',
          'orderType': 'TakeAway',
          'status': 'Pending',
          'paymentStatus': 'Unpaid',
          'totalAmount': 55000,
        }),
        200,
      );
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: StaffOrderPage(
            loadTables: () async => [],
            loadFoods: (page, pageSize, search) async => const MemberFoodPage(
              items: [
                MemberFoodItem(
                  foodItemId: 1,
                  categoryId: 1,
                  categoryName: 'Món',
                  name: 'Phở',
                  price: 55000,
                ),
              ],
              page: 1,
              totalItems: 1,
              totalPages: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ăn tại quán'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mang đi').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_shopping_cart));
      await tester.pump();
      await tester.tap(find.text('Tạo đơn và thanh toán'));
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(find.text('OFF-123'), findsOneWidget);
      expect(find.text('55.000 đ'), findsOneWidget);
      expect(find.text('Chưa thanh toán'), findsOneWidget);
      await tester.ensureVisible(find.text('Quay lại tạo đơn'));
      await tester.tap(find.text('Quay lại tạo đơn'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.add_shopping_cart), findsOneWidget);
      expect(requests, 1);
    }, () => client);
  });
}
