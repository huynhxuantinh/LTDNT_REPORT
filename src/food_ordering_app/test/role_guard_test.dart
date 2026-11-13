import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trek_bikes_app/role_guard.dart';

void main() {
  testWidgets('blocks Member from Admin route', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RoleGuard(
          role: 'Member',
          allowedRoles: {'Admin'},
          child: Text('Admin screen'),
        ),
      ),
    );

    expect(find.text('Bạn không có quyền truy cập.'), findsOneWidget);
    expect(find.text('Admin screen'), findsNothing);
  });
}
