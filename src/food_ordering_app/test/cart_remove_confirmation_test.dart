import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_ordering_app/cart_api.dart';
import 'package:food_ordering_app/cart_page.dart';

void main() {
  testWidgets('minimum quantity is one and deletion requires confirmation', (
    tester,
  ) async {
    var deletes = 0;
    var updates = 0;
    const cart = Cart(
      items: [
        CartItem(
          cartItemId: 7,
          foodItemId: 2,
          name: 'Bún bò',
          unitPrice: 30000,
          quantity: 1,
        ),
      ],
      totalQuantity: 1,
      totalAmount: 30000,
    );
    const empty = Cart(items: [], totalQuantity: 0, totalAmount: 0);
    await tester.pumpWidget(
      MaterialApp(
        home: CartPage(
          loadCart: () async => cart,
          setQuantity: (id, quantity) async {
            updates++;
            return cart;
          },
          removeItem: (id) async {
            deletes++;
            return empty;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<IconButton>(find.ancestor(of: find.byIcon(Icons.remove_circle_outline), matching: find.byType(IconButton))).onPressed,
      isNull,
    );
    expect(updates, 0);
    await tester.tap(find.byTooltip('Xóa món'));
    await tester.pumpAndSettle();
    expect(find.text('Bạn muốn xóa Bún bò khỏi giỏ hàng?'), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(deletes, 0);
    expect(find.text('Bún bò'), findsOneWidget);
    await tester.tap(find.byTooltip('Xóa món'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Xóa món'));
    await tester.pumpAndSettle();
    expect(deletes, 1);
    expect(find.text('Giỏ hàng đang trống.'), findsOneWidget);
  });
}
