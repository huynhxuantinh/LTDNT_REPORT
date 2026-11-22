import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trek_bikes_app/auth_pages.dart';

void main() {
  testWidgets('login password can be shown and hidden', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginPage(onSessionChanged: () {})),
    );
    final password = find.widgetWithText(TextFormField, 'Mật khẩu');
    final editable = find.descendant(of: password, matching: find.byType(EditableText));
    expect(tester.widget<EditableText>(editable).obscureText, isTrue);
    await tester.tap(find.byTooltip('Hiện mật khẩu'));
    await tester.pump();
    expect(tester.widget<EditableText>(editable).obscureText, isFalse);
    await tester.tap(find.byTooltip('Ẩn mật khẩu'));
    await tester.pump();
    expect(tester.widget<EditableText>(editable).obscureText, isTrue);
  });
}
