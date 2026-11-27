import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_ordering_app/auth_pages.dart';

void main() {
  testWidgets('forgot password starts with email only', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ForgotPasswordPage()));
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Gửi mã'), findsOneWidget);
    expect(find.text('Mã 6 số từ email'), findsNothing);
    expect(find.text('Mật khẩu mới'), findsNothing);
    await tester.tap(find.text('Gửi mã'));
    await tester.pump();
    expect(find.text('Email không hợp lệ.'), findsOneWidget);
  });
}
