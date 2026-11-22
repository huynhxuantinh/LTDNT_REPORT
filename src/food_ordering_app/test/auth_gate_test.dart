import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trek_bikes_app/auth_pages.dart';
import 'package:trek_bikes_app/main.dart';
import 'package:trek_bikes_app/session_helper.dart';

void main() {
  testWidgets('session change returns to login without async setState error', (tester) async {
    dotenv.loadFromString(envString: 'API_URL=http://localhost:5000');
    FlutterSecureStorage.setMockInitialValues({'access_token': 'token', 'role': 'Member'});
    await tester.pumpWidget(const MaterialApp(home: AuthGate()));
    await tester.pumpAndSettle();
    expect(find.byType(AccountHome), findsOneWidget);

    await SessionHelper.clear();
    tester.widget<AccountHome>(find.byType(AccountHome)).onSessionChanged();
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
