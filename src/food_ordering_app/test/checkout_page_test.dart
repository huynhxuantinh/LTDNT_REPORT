import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trek_bikes_app/checkout_page.dart';

void main() {
  testWidgets('Checkout requires recipient, phone and address', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CheckoutPage()));
    await tester.tap(find.text('Đặt hàng'));
    await tester.pump();
    expect(find.text('Bắt buộc'), findsNWidgets(3));
  });
}
