import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:trek_bikes_app/auth_pages.dart';

void main() {
  testWidgets('registration begins with email and no password field', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterPage()));
    expect(find.text('Họ và tên'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Gửi mã xác nhận'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsNothing);
  });
  testWidgets('displays login form', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginPage(onSessionChanged: () {})),
    );
    expect(find.text('Đăng nhập'), findsWidgets);
    expect(find.text('Chưa có tài khoản? Đăng ký'), findsOneWidget);
  });

  testWidgets('login requires an identifier and password', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginPage(onSessionChanged: () {})),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pump();
    expect(find.text('Trường này là bắt buộc.'), findsNWidgets(2));
  });
}
