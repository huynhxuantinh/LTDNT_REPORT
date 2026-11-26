import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trek_bikes_app/cart_api.dart';
import 'package:trek_bikes_app/cart_page.dart';
import 'package:trek_bikes_app/food_detail_page.dart';
import 'package:trek_bikes_app/member_food_api.dart';

void main() {
  testWidgets('food detail shows cart count and updates it after adding', (
    tester,
  ) async {
    cartCount.value = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: FoodDetailPage(
          foodId: 1,
          loadFood: (_) async => const MemberFoodItem(
            foodItemId: 1,
            categoryId: 1,
            categoryName: 'Món chính',
            name: 'Cơm gà',
            price: 30000,
          ),
          loadCart: () async =>
              const Cart(items: [], totalQuantity: 2, totalAmount: 0),
          addToCart: (_) async =>
              const Cart(items: [], totalQuantity: 3, totalAmount: 0),
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
    expect(find.byTooltip('Giỏ hàng'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.text('Thêm vào giỏ'));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.byTooltip('Giỏ hàng'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CartPage), findsOneWidget);
    cartCount.value = 0;
  });
}
