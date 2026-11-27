import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:food_ordering_app/admin_food_items_page.dart';

void main() {
  testWidgets('admin can restore a hidden food from the list', (tester) async {
    dotenv.loadFromString(envString: 'API_URL=http://localhost:5000');
    FlutterSecureStorage.setMockInitialValues({'access_token': 'token'});
    var available = false;
    final client = MockClient((request) async {
      if (request.url.path == '/api/admin/categories')
        return http.Response('[]', 200);
      if (request.url.path == '/api/admin/food-items/1/restore') {
        expect(request.method, 'POST');
        available = true;
        return http.Response('{}', 200);
      }
      expect(request.url.path, '/api/admin/food-items');
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'data': [
              {
                'foodItemId': 1,
                'categoryId': 1,
                'categoryName': 'Món',
                'name': 'Phở',
                'price': 30000,
                'imageUrl': null,
                'isAvailable': available,
                'createdAt': '2026-01-01T00:00:00Z',
              },
            ],
            'meta': {
              'page': 1,
              'pageSize': 10,
              'totalItems': 1,
              'totalPages': 1,
            },
          }),
        ),
        200,
      );
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: AdminFoodItemsPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mở bán lại'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mở bán'));
      await tester.pumpAndSettle();
      expect(available, isTrue);
      expect(find.textContaining('Đang bán'), findsOneWidget);
      expect(find.byTooltip('Mở bán lại'), findsNothing);
    }, () => client);
  });
}
