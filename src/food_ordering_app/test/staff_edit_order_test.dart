import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:food_ordering_app/staff_edit_order_page.dart';

void main() {
  testWidgets('staff removes an existing item, adds a food and saves', (
    tester,
  ) async {
    dotenv.loadFromString(envString: 'API_URL=http://localhost:5000');
    FlutterSecureStorage.setMockInitialValues({'access_token': 'token'});
    var saves = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'data': [
              {
                'foodItemId': 2,
                'categoryId': 1,
                'categoryName': 'Nước',
                'name': 'Trà',
                'price': 20,
              },
            ],
            'meta': {'page': 1, 'totalItems': 1, 'totalPages': 1},
          })),
          200,
        );
      }
      expect(request.url.path, '/api/staff/orders/42/items');
      final body =
          jsonDecode(utf8.decode(request.bodyBytes)) as Map<String, dynamic>;
      expect(body['items'], [
        {'foodItemId': 2, 'quantity': 1},
      ]);
      expect(body['expectedItems'], [
        {'orderDetailId': 7, 'quantity': 1},
      ]);
      saves++;
      return http.Response('{}', 200);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StaffEditOrderPage(
                      orderId: 42,
                      items: [
                        {
                          'orderDetailId': 7,
                          'foodItemId': 1,
                          'quantity': 1,
                          'foodNameSnapshot': 'Cơm',
                        },
                      ],
                    ),
                  ),
                ),
                child: const Text('Mở sửa đơn'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở sửa đơn'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Thêm món'));
      await tester.pump();
      final oldRow = find.ancestor(
        of: find.text('Cơm'),
        matching: find.byType(ListTile),
      );
      await tester.tap(
        find.descendant(of: oldRow, matching: find.byTooltip('Giảm hoặc xóa')),
      );
      await tester.pump();
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();
      expect(saves, 1);
      expect(find.text('Mở sửa đơn'), findsOneWidget);
    }, () => client);
  });
}
