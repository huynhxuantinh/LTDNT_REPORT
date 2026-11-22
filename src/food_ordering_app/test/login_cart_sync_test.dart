import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trek_bikes_app/auth_api.dart';
import 'package:trek_bikes_app/auth_pages.dart';
import 'package:trek_bikes_app/session_helper.dart';

void main() {
  testWidgets('login succeeds even when local cart sync fails', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    var sessionChanged = false;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          onSessionChanged: () => sessionChanged = true,
          login: ({required email, required password}) async =>
              const AuthSession(
                userId: '1',
                fullName: 'Test',
                email: 'test@example.com',
                role: 'Member',
                accessToken: 'access',
                refreshToken: 'refresh',
              ),
          syncCart: () async => throw Exception('SQLite unavailable'),
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextFormField).first,
      'test@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'Password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pumpAndSettle();
    expect(sessionChanged, isTrue);
    expect(await SessionHelper.accessToken, 'access');
    expect(find.textContaining('Chưa đồng bộ được giỏ hàng'), findsOneWidget);
    expect(find.textContaining('Không thể kết nối máy chủ'), findsNothing);
  });
}
