import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trek_bikes_app/checkout_page.dart';
import 'package:trek_bikes_app/payment_navigation.dart';
import 'package:trek_bikes_app/vietqr_api.dart';
import 'package:trek_bikes_app/vietqr_payment_page.dart';
import 'package:trek_bikes_app/vnpay_api.dart';
import 'package:trek_bikes_app/vnpay_payment_page.dart';

Widget appWithPayment(Widget payment) => MaterialApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => payment),
                ),
                child: const Text('Mở thanh toán'),
              ),
            ),
          ),
        ),
        child: const Text('Trang chủ'),
      ),
    ),
  ),
);

Future<void> openPayment(WidgetTester tester, Widget payment) async {
  await tester.pumpWidget(appWithPayment(payment));
  await tester.tap(find.text('Trang chủ'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mở thanh toán'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('successful payment does not pop home through checkout', (tester) async {
    await openPayment(tester, CheckoutPage(
      checkout: ({required name, required phone, required address, note}) async => 3,
      vietQrBuilder: (_) => Builder(builder: (context) => Scaffold(body: TextButton(
        onPressed: () => returnHomeAfterPayment(context),
        child: const Text('Thanh toán thành công'),
      ))),
    ));
    await tester.enterText(find.widgetWithText(TextFormField, 'Tên người nhận'), 'An');
    await tester.enterText(find.widgetWithText(TextFormField, 'SĐT'), '0912345678');
    await tester.enterText(find.widgetWithText(TextFormField, 'Địa chỉ'), 'Hà Nội');
    await tester.tap(find.text('Đặt hàng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thanh toán thành công'));
    await tester.pumpAndSettle();
    expect(find.text('Trang chủ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('COD returns home with order placed message', (tester) async {
    await openPayment(tester, CheckoutPage(checkout: ({required name, required phone, required address, note}) async => 3));
    await tester.enterText(find.widgetWithText(TextFormField, 'Tên người nhận'), 'An');
    await tester.enterText(find.widgetWithText(TextFormField, 'SĐT'), '0912345678');
    await tester.enterText(find.widgetWithText(TextFormField, 'Địa chỉ'), 'Hà Nội');
    await tester.tap(find.text('Chuyển khoản VietQR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiền mặt khi nhận hàng (COD)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đặt hàng'));
    await tester.pumpAndSettle();
    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Đặt hàng thành công. Thanh toán khi nhận hàng.'), findsOneWidget);
  });

  testWidgets('VietQR stays on page when unpaid, returns home when paid', (
    tester,
  ) async {
    var status = 'Unpaid';
    await openPayment(
      tester,
      VietQrPaymentPage(
        orderId: 1,
        loadInfo: (_) async => const VietQrInfo(
          orderId: 1,
          orderCode: 'DH1',
          amount: 100,
          bankId: 'Bank',
          accountNo: '123',
          accountName: 'Test',
          transferContent: 'DH1',
          qrImageUrl: 'https://example.test/qr.png',
          paymentStatus: 'Unpaid',
        ),
        checkStatus: (_) async => status,
      ),
    );
    await tester.ensureVisible(find.text('Kiểm tra'));
    await tester.tap(find.text('Kiểm tra'));
    await tester.pumpAndSettle();
    expect(find.text('Thanh toán VietQR'), findsOneWidget);
    expect(find.text('Đơn hàng chưa nhận được tiền.'), findsOneWidget);
    status = 'Paid';
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiểm tra'));
    await tester.pumpAndSettle();
    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Thanh toán thành công.'), findsOneWidget);
  });

  testWidgets('VNPay demo confirmation returns home', (tester) async {
    await openPayment(
      tester,
      VnPayPaymentPage(
        orderId: 2,
        loadInfo: (_) async => const VnPayInfo(
          orderId: 2,
          orderCode: 'DH2',
          amount: 100,
          paymentUrl: 'https://example.test',
          paymentStatus: 'Unpaid',
        ),
        confirmDemo: (_) async => true,
      ),
    );
    await tester.ensureVisible(find.text('Đã chuyển (Demo)'));
    await tester.tap(find.text('Đã chuyển (Demo)'));
    await tester.pumpAndSettle();
    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Đã xác nhận thanh toán demo.'), findsOneWidget);
  });
}
