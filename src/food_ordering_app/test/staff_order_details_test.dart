import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trek_bikes_app/staff_orders_page.dart';

void main() {
  testWidgets(
    'dine-in shows table and details without status actions; takeaway retains them',
    (tester) async {
      dotenv.loadFromString(envString: 'API_URL=http://localhost:5000');
      FlutterSecureStorage.setMockInitialValues({'access_token': 'token'});
      final dineIn = {
        'orderId': 1,
        'orderCode': 'OFF-1',
        'orderType': 'DineIn',
        'tableCode': 'B01',
        'createdBy': 'Nhân viên An',
        'receiverName': 'Khách Bình',
        'status': 'Pending',
        'paymentStatus': 'Unpaid',
        'totalAmount': 70000,
        'createdAt': '2026-01-01T12:00:00Z',
      };
      final takeaway = {
        ...dineIn,
        'orderId': 2,
        'orderCode': 'OFF-2',
        'orderType': 'TakeAway',
        'tableCode': null,
      };
      final client = MockClient((request) async {
        if (request.url.path == '/api/staff/orders') {
          return http.Response.bytes(
            utf8.encode(jsonEncode([dineIn, takeaway])),
            200,
          );
        }
        expect(request.url.path, '/api/staff/orders/1');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              ...dineIn,
              'items': [
                {'foodNameSnapshot': 'Phở', 'unitPrice': 35000, 'quantity': 2},
              ],
            }),
          ),
          200,
        );
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: StaffOrdersPage()));
        await tester.pumpAndSettle();
        final dineCard = find.ancestor(
          of: find.text('OFF-1'),
          matching: find.byType(Card),
        );
        final takeCard = find.ancestor(
          of: find.text('OFF-2'),
          matching: find.byType(Card),
        );
        expect(
          find.descendant(of: dineCard, matching: find.text('Bàn: B01')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: dineCard,
            matching: find.text('Khách: Khách Bình'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: dineCard,
            matching: find.textContaining('Chuyển:'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(of: dineCard, matching: find.text('Hủy đơn')),
          findsNothing,
        );
        expect(
          find.descendant(
            of: takeCard,
            matching: find.text('Chuyển: Đã xác nhận'),
          ),
          findsOneWidget,
        );
        await tester.tap(
          find.descendant(of: dineCard, matching: find.text('Xem chi tiết')),
        );
        await tester.pumpAndSettle();
        expect(find.text('B01'), findsOneWidget);
        expect(find.text('Phở'), findsOneWidget);
        expect(find.text('35.000 đ × 2'), findsOneWidget);
        expect(find.text('Tổng cộng: 70.000 đ'), findsOneWidget);
        expect(find.text('Trạng thái'), findsNothing);
      final payment = find.widgetWithText(FilledButton, 'Thanh toán');
      await tester.ensureVisible(payment);
      await tester.pumpAndSettle();
      await tester.tap(payment);
        await tester.pumpAndSettle();
        expect(find.text('Thanh toán đơn tại quán'), findsOneWidget);
        expect(find.text('70.000 đ'), findsOneWidget);
        expect(find.text('Trạng thái đơn'), findsNothing);
      }, () => client);
    },
  );
}
