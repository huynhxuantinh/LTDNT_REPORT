import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trek_bikes_app/staff_payment_page.dart';

void main() {
  testWidgets('displays order and unpaid amount without processing payment', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StaffPaymentPage(
          orderCode: 'OFF-123',
          orderType: 'DineIn',
          orderStatus: 'Pending',
          paymentStatus: 'Unpaid',
          totalAmount: 55000,
        ),
      ),
    );
    expect(find.text('OFF-123'), findsOneWidget);
    expect(find.text('Ăn tại quán'), findsOneWidget);
    expect(find.text('Chưa thanh toán'), findsOneWidget);
    expect(find.text('55000 đ'), findsOneWidget);
    expect(find.text('Quay lại đơn hàng'), findsOneWidget);
  });
}
