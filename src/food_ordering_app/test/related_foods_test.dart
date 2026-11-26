import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trek_bikes_app/cart_api.dart';
import 'package:trek_bikes_app/food_detail_page.dart';
import 'package:trek_bikes_app/member_food_api.dart';
import 'package:trek_bikes_app/related_foods_section.dart';

MemberFoodItem food(int id, String name) => MemberFoodItem(
  foodItemId: id,
  categoryId: 1,
  categoryName: 'Món chính',
  name: name,
  price: 30000,
);

void main() {
  test(
    'requests related foods with pagination and decodes Vietnamese',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      dotenv.loadFromString(envString: 'API_URL=http://localhost:5000');
      final client = MockClient((request) async {
        expect(request.url.path, '/api/foods/12/related');
        expect(request.url.queryParameters, {'page': '2', 'pageSize': '4'});
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'data': [
                {
                  'foodItemId': 4,
                  'categoryId': 1,
                  'categoryName': 'Món chính',
                  'name': 'Bún bò',
                  'price': 30000,
                },
              ],
              'meta': {'page': 2, 'totalItems': 5, 'totalPages': 2},
            }),
          ),
          200,
        );
      });
      await http.runWithClient(() async {
        final result = await MemberFoodApi.getRelated(
          foodId: 12,
          page: 2,
          pageSize: 4,
        );
        expect(result.items.single.name, 'Bún bò');
        expect(result.totalPages, 2);
      }, () => client);
    },
  );

  testWidgets('related section switches pages, adds to cart and opens a food', (
    tester,
  ) async {
    final calls = <(int, int)>[];
    var added = 0;
    Future<MemberFoodPage> related(int id, int page, int size) async {
      expect(size, 4);
      calls.add((id, page));
      if (id != 1)
        return const MemberFoodPage(
          items: [],
          page: 1,
          totalItems: 0,
          totalPages: 0,
        );
      return MemberFoodPage(
        items: [page == 1 ? food(2, 'Bún bò') : food(3, 'Cơm gà')],
        page: page,
        totalItems: 5,
        totalPages: 2,
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: FoodDetailPage(
          foodId: 1,
          loadFood: (id) async => food(id, id == 1 ? 'Phở' : 'Cơm gà'),
          loadCart: () async =>
              const Cart(items: [], totalQuantity: 0, totalAmount: 0),
          addToCart: (id) async {
            added = id;
            return const Cart(items: [], totalQuantity: 1, totalAmount: 30000);
          },
          loadRelated: related,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Món liên quan'), findsOneWidget);
    expect(find.text('Bún bò'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Thêm Bún bò vào giỏ'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Thêm Bún bò vào giỏ'));
    await tester.pumpAndSettle();
    expect(added, 2);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Trang món liên quan sau'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Trang món liên quan sau'));
    await tester.pumpAndSettle();
    expect(find.text('Cơm gà'), findsOneWidget);
    expect(calls, contains((1, 2)));
    await tester.tap(find.text('Cơm gà'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết món'), findsOneWidget);
    expect(find.text('Cơm gà'), findsOneWidget);
    expect(calls, contains((3, 1)));
  });

  testWidgets('related section lets the user retry after an error', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RelatedFoodsSection(
            foodId: 1,
            onOpen: (_) {},
            onAdd: (_) {},
            loadRelated: (_, _, _) async {
              calls++;
              if (calls == 1) throw Exception('network');
              return const MemberFoodPage(
                items: [],
                page: 1,
                totalItems: 0,
                totalPages: 0,
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không thể tải món liên quan.'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có món liên quan.'), findsOneWidget);
  });
}
