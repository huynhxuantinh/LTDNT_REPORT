import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trek_bikes_app/app_states.dart';

void main() {
  testWidgets('renders shared loading, error and empty states', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppLoadingState())),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AppErrorState(onRetry: () {})),
      ),
    );
    expect(find.text('Thử lại'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppEmptyState(message: 'Chưa có dữ liệu.')),
      ),
    );
    expect(find.text('Chưa có dữ liệu.'), findsOneWidget);
  });
}
