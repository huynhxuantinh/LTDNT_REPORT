import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trek_bikes_app/auth_pages.dart';
import 'package:trek_bikes_app/cart_api.dart';

void main() {
  testWidgets('home restores cart badge from server when opened', (tester) async {
    dotenv.loadFromString(envString: 'API_URL=http://localhost:5000');
    FlutterSecureStorage.setMockInitialValues({'role': 'Member'});
    cartCount.value = 0;
    await tester.pumpWidget(MaterialApp(home: AccountHome(
      onSessionChanged: () {},
      loadCart: () async => const Cart(items: [], totalQuantity: 3, totalAmount: 0),
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('Trang chủ'), findsOneWidget);
    await tester.tap(find.text('Trang chủ'));
    await tester.pumpAndSettle();
    expect(find.text('Thực đơn'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    cartCount.value = 0;
  });
}
