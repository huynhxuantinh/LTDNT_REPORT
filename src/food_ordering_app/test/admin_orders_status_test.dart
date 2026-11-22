import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trek_bikes_app/admin_orders_page.dart';

void main() {
  setUp(() => dotenv.loadFromString(envString: 'API_URL=http://localhost:5000'));
  testWidgets('delivery order updates via API after confirmation', (
    tester,
  ) async {
    var status = 'Preparing';
    var updates = 0;
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer test-token');
      if (request.method == 'PUT') {
        expect(request.url.path, '/api/admin/orders/42/status');
        expect(jsonDecode(request.body)['status'], 'Delivering');
        updates++;
        status = 'Delivering';
        return http.Response('{}', 200);
      }
      return http.Response(
        jsonEncode({
          'data': [
            {
              'orderId': 42,
              'orderCode': 'DH42',
              'orderType': 'Delivery',
              'status': status,
              'totalAmount': 50000,
            },
          ],
          'meta': {'totalPages': 1},
        }),
        200,
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        home: AdminOrdersPage(
          client: client,
          tokenReader: () async => 'test-token',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chuyển: Đang giao'));
    await tester.pumpAndSettle();
    expect(updates, 0);
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(updates, 1);
    expect(find.text('Chuyển: Hoàn thành'), findsOneWidget);
    client.close();
  });

  testWidgets(
    'offline order skips delivery and completed order cannot change',
    (tester) async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'data': [
              {
                'orderId': 1,
                'orderCode': 'OFF1',
                'orderType': 'DineIn',
                'status': 'Preparing',
                'totalAmount': 10,
              },
              {
                'orderId': 2,
                'orderCode': 'OFF2',
                'orderType': 'TakeAway',
                'status': 'Completed',
                'totalAmount': 20,
              },
            ],
            'meta': {'totalPages': 1},
          }),
          200,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AdminOrdersPage(
            client: client,
            tokenReader: () async => 'test-token',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chuyển: Hoàn thành'), findsOneWidget);
      expect(find.text('Chuyển: Đang giao'), findsNothing);
      expect(find.text('Hủy đơn'), findsOneWidget);
      client.close();
    },
  );
}
