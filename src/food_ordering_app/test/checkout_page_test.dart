import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_ordering_app/checkout_page.dart';
import 'package:food_ordering_app/auth_api.dart';

void main() {
  testWidgets('Checkout requires recipient, phone and address', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CheckoutPage()));
    await tester.tap(find.text('Đặt hàng'));
    await tester.pump();
    expect(find.text('Bắt buộc'), findsNWidgets(3));
  });

  testWidgets('checkout explains when a food is no longer available', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CheckoutPage(
          checkout:
              ({required name, required phone, required address, note}) async {
                throw const ApiException(
                  'Có món không còn bán.',
                  code: 'food_not_available',
                );
              },
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tên người nhận'),
      'An',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'SĐT'),
      '0123456789',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Địa chỉ'),
      'Địa chỉ',
    );
    await tester.ensureVisible(find.text('Đặt hàng'));
    await tester.tap(find.text('Đặt hàng'));
    await tester.pump();
    expect(find.text('Có món không còn bán.'), findsOneWidget);
  });

  testWidgets('price changes require customer to return to the cart', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CheckoutPage(
                    checkout:
                        ({
                          required name,
                          required phone,
                          required address,
                          note,
                        }) async {
                          throw const ApiException(
                            'Vui lòng kiểm tra lại giỏ hàng.',
                            code: 'cart_price_changed',
                          );
                        },
                  ),
                ),
              ),
              child: const Text('Mở đặt hàng'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở đặt hàng'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tên người nhận'),
      'An',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'SĐT'),
      '0123456789',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Địa chỉ'),
      'Địa chỉ',
    );
    await tester.ensureVisible(find.text('Đặt hàng'));
    await tester.tap(find.text('Đặt hàng'));
    await tester.pumpAndSettle();
    expect(find.text('Giá món đã thay đổi'), findsOneWidget);
    await tester.tap(find.text('Xem lại giỏ hàng'));
    await tester.pumpAndSettle();
    expect(find.text('Mở đặt hàng'), findsOneWidget);
  });
}
