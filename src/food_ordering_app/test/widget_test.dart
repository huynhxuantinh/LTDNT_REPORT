import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:trek_bikes_app/auth_pages.dart';

void main() {
  testWidgets('displays login form', (tester) async {
    await tester.pumpWidget(MaterialApp(home: LoginPage(onSessionChanged: () {})));
    expect(find.text('Đăng nhập'), findsWidgets);
    expect(find.text('Chưa có tài khoản? Đăng ký'), findsOneWidget);
  });
}
