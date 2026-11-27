import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_ordering_app/orders_page.dart';

void main() {
  for (final status in ['Cancelled', 'Pending']) {
    testWidgets('payment buttons reflect order status $status', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OrderDetailPage(
            id: 1,
            loadOrder: (_) async => {
              'orderCode': 'DH1',
              'orderType': 'Delivery',
              'status': status,
              'paymentStatus': 'Unpaid',
              'receiverName': 'An',
              'receiverPhone': '0912345678',
              'deliveryAddress': 'Hà Nội',
              'createdAt': '2026-01-01T12:00:00Z',
              'totalAmount': 60000,
              'items': [],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('VietQR'),
        status == 'Cancelled' ? findsNothing : findsOneWidget,
      );
      expect(
        find.text('VNPay'),
        status == 'Cancelled' ? findsNothing : findsOneWidget,
      );
    });
  }
  testWidgets('order detail displays delivery recipient and address', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OrderDetailPage(
          id: 1,
          loadOrder: (_) async => {
            'orderCode': 'DH1',
            'orderType': 'Delivery',
            'status': 'Pending',
            'paymentStatus': 'Paid',
            'receiverName': 'Nguyễn An',
            'receiverPhone': '0912345678',
            'deliveryAddress': 'Hà Nội',
            'note': 'Gọi trước',
            'createdAt': '2026-01-01T12:00:00Z',
            'totalAmount': 60000,
            'items': [
              {'foodNameSnapshot': 'Bún bò', 'quantity': 2, 'unitPrice': 30000},
            ],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nguyễn An'), findsOneWidget);
    expect(find.text('0912345678'), findsOneWidget);
    expect(find.text('Hà Nội'), findsOneWidget);
    expect(find.text('Gọi trước'), findsOneWidget);
    expect(find.text('Giao hàng'), findsOneWidget);
    expect(find.text('60.000 đ'), findsOneWidget);
  });
}
