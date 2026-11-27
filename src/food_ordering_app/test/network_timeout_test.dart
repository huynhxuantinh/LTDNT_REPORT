import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:food_ordering_app/admin_orders_page.dart';
import 'package:food_ordering_app/checkout_page.dart';
import 'package:food_ordering_app/network_timeout.dart';
import 'package:food_ordering_app/user_error.dart';

void main() {
  setUp(
    () => dotenv.loadFromString(envString: 'API_URL=http://localhost:5000'),
  );

  test('timeout is reported as an uncertain result', () {
    expect(
      userErrorMessage(TimeoutException('timeout'), 'fallback'),
      contains('kiểm tra kết quả trước khi thử lại'),
    );
  });

  testWidgets('admin orders stops loading when request hangs', (tester) async {
    final pending = Completer<http.Response>();
    final client = MockClient((_) => pending.future);
    await tester.pumpWidget(
      MaterialApp(
        home: AdminOrdersPage(
          client: client,
          tokenReader: () async => 'test-token',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(apiRequestTimeout + const Duration(milliseconds: 1));
    await tester.pump();
    expect(
      find.text('Không thể tải dữ liệu. Kiểm tra kết nối mạng rồi thử lại.'),
      findsOneWidget,
    );
    expect(find.text('Thử lại'), findsOneWidget);
    client.close();
  });

  testWidgets('checkout timeout asks to check orders before retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CheckoutPage(
          checkout: ({
            required name,
            required phone,
            required address,
            note,
          }) async => throw TimeoutException('timeout'),
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tên người nhận'),
      'An',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'SĐT'),
      '0912345678',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Địa chỉ'),
      'Hà Nội',
    );
    await tester.tap(find.text('Đặt hàng'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Chưa xác nhận được kết quả. Hãy kiểm tra đơn hàng trước khi đặt lại.',
      ),
      findsOneWidget,
    );
    expect(find.text('Đặt hàng'), findsOneWidget);
  });
}
