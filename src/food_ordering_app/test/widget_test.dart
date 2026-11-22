import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:trek_bikes_app/auth_pages.dart';

void main() {
  testWidgets('displays login form', (tester) async {
    await tester.pumpWidget(MaterialApp(home: LoginPage(onSessionChanged: () {})));
    expect(find.text('Đăng nhập'), findsWidgets);
    expect(find.text('Chưa có tài khoản? Đăng ký'), findsOneWidget);
  });

  testWidgets('login rejects invalid email and short password', (tester) async {
    await tester.pumpWidget(MaterialApp(home: LoginPage(onSessionChanged: () {})));
    await tester.enterText(find.byType(TextFormField).first, 'invalid');
    await tester.enterText(find.byType(TextFormField).last, 'short');
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pump();
    expect(find.text('Email không hợp lệ.'), findsOneWidget);
    expect(find.text('Mật khẩu tối thiểu 8 ký tự.'), findsOneWidget);
  });
}
