import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trek_bikes_app/admin_food_items_page.dart';
import 'package:trek_bikes_app/cart_api.dart';
import 'package:trek_bikes_app/food_detail_page.dart';
import 'package:trek_bikes_app/member_food_api.dart';

void main() {
  testWidgets('admin selects several images and deletes one saved image', (
    tester,
  ) async {
    dotenv.loadFromString(envString: 'API_URL=http://localhost:5000');
    FlutterSecureStorage.setMockInitialValues({'access_token': 'token'});
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
    );
    var created = false;
    var extra = false;
    var deletes = 0;
    var uploads = 0;
    Map<String, Object?> food() => {
      'foodItemId': 1,
      'categoryId': 1,
      'categoryName': 'Món',
      'name': 'Phở',
      'description': '',
      'price': 30000,
      'imageUrl': '/uploads/foods/a.png',
      'isAvailable': true,
      'createdAt': '2026-01-01T00:00:00Z',
    };
    http.Response json(Object value, int status) => http.Response.bytes(
      utf8.encode(jsonEncode(value)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path == '/api/admin/categories')
        return json([
          {
            'categoryId': 1,
            'name': 'Món',
            'description': null,
            'imageUrl': null,
            'isActive': true,
            'createdAt': '2026-01-01T00:00:00Z',
          },
        ], 200);
      if (path == '/api/admin/food-items' && request.method == 'GET')
        return json({
          'data': created ? [food()] : [],
          'meta': {
            'page': 1,
            'pageSize': 10,
            'totalItems': created ? 1 : 0,
            'totalPages': created ? 1 : 0,
          },
        }, 200);
      if (path == '/api/admin/food-items' && request.method == 'POST') {
        created = true;
        return json(food(), 201);
      }
      if (path == '/api/admin/food-items/1' && request.method == 'PUT')
        return json(food(), 200);
      if (path == '/api/admin/food-items/1/images' &&
          request.method == 'POST') {
        uploads++;
        extra = true;
        return json({
          'imageId': 7,
          'imageUrl': '/uploads/foods/b.png',
          'isCover': false,
        }, 200);
      }
      if (path == '/api/admin/food-items/1/images' && request.method == 'GET')
        return json([
          {
            'imageId': null,
            'imageUrl': '/uploads/foods/a.png',
            'isCover': true,
          },
          if (extra)
            {
              'imageId': 7,
              'imageUrl': '/uploads/foods/b.png',
              'isCover': false,
            },
        ], 200);
      if (path == '/api/admin/food-items/1/images/7' &&
          request.method == 'DELETE') {
        extra = false;
        deletes++;
        return http.Response('', 204);
      }
      throw StateError('Unexpected request ${request.method} $path');
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdminFoodItemsPage(
            pickImages: () async => [
              (bytes: Uint8List.fromList(png), name: 'a.png'),
              (bytes: Uint8List.fromList(png), name: 'b.png'),
              (bytes: Uint8List.fromList(png), name: 'c.png'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thêm món'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tên món *'),
        'Phở',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Giá (VNĐ) *'),
        '30000',
      );
      await tester.ensureVisible(find.text('Chọn ảnh món *'));
      await tester.tap(find.text('Chọn ảnh món *'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Xóa ảnh'), findsNWidgets(3));
      await tester.ensureVisible(find.bySemanticsLabel('Xóa ảnh').last);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Xóa ảnh').last);
      await tester.pump();
      expect(find.bySemanticsLabel('Xóa ảnh'), findsNWidgets(2));
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(created, isTrue);
      expect(extra, isTrue);
      expect(uploads, 1);
      await tester.tap(find.byTooltip('Sửa món'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Xóa ảnh'), findsNWidgets(2));
      await tester.ensureVisible(find.bySemanticsLabel('Xóa ảnh').last);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Xóa ảnh').last);
      await tester.pump();
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(deletes, 1);
      expect(extra, isFalse);
    }, () => client);
  });

  testWidgets('food detail displays multiple images and allows swiping', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FoodDetailPage(
          foodId: 1,
          loadFood: (_) async => const MemberFoodItem(
            foodItemId: 1,
            categoryId: 1,
            categoryName: 'Món',
            name: 'Phở',
            price: 30000,
          ),
          loadImages: (_) async => [
            'https://example.invalid/a.jpg',
            'https://example.invalid/b.jpg',
          ],
          loadCart: () async =>
              const Cart(items: [], totalQuantity: 0, totalAmount: 0),
          loadRelated: (_, _, _) async => const MemberFoodPage(
            items: [],
            page: 1,
            totalItems: 0,
            totalPages: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ảnh 1/2'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('Ảnh 2/2'), findsOneWidget);
  });
}
