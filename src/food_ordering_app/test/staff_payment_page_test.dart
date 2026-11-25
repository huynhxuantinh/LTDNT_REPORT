import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trek_bikes_app/staff_payment_page.dart';

import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('displays order and unpaid amount without processing payment', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StaffPaymentPage(
          orderId: 1,
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
    expect(find.text('55.000 đ'), findsOneWidget);
    expect(find.text('Quay lại danh sách đơn'), findsOneWidget);
  });

  testWidgets('cash collection shows the nested API error', (tester) async {
    dotenv.loadFromString(envString: 'API_URL=http://localhost:5000');
    FlutterSecureStorage.setMockInitialValues({'access_token': 'token'});
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          const MaterialApp(
            home: StaffPaymentPage(
              orderId: 1,
              orderCode: 'OFF-123',
              orderType: 'DineIn',
              orderStatus: 'Pending',
              paymentStatus: 'Unpaid',
              totalAmount: 55000,
            ),
          ),
        );
        await tester.ensureVisible(find.text('Tiền mặt tại quán'));
        await tester.tap(find.text('Tiền mặt tại quán'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Đã nhận tiền'));
        await tester.pumpAndSettle();
        expect(find.text('Đơn hàng đã thanh toán.'), findsOneWidget);
      },
      () => MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'error': {
                'code': 'order_already_paid',
                'message': 'Đơn hàng đã thanh toán.',
              },
            }),
          ),
          409,
        ),
      ),
    );
  });
}
