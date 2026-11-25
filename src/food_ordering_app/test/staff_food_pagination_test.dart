import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trek_bikes_app/member_food_api.dart';
import 'package:trek_bikes_app/staff_order_page.dart';

void main() {
  testWidgets('staff can select foods across pages without losing quantities', (
    tester,
  ) async {
    final calls = <int>[];
    Future<MemberFoodPage> loadFoods(
      int page,
      int pageSize,
      String search,
    ) async {
      expect(pageSize, 10);
      calls.add(page);
      return MemberFoodPage(
        page: page,
        totalItems: 11,
        totalPages: 2,
        items: [
          MemberFoodItem(
            foodItemId: page,
            categoryId: 1,
            categoryName: 'Món',
            name: 'Món $page',
            price: 10000,
          ),
        ],
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: StaffOrderPage(loadFoods: loadFoods, loadTables: () async => []),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Trang 1/2'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add_shopping_cart));
    await tester.pump();
    await tester.tap(find.byTooltip('Trang sau'));
    await tester.pumpAndSettle();
    expect(find.text('Món 2'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add_shopping_cart));
    await tester.pump();
    await tester.tap(find.byTooltip('Trang trước'));
    await tester.pumpAndSettle();
    expect(find.text('Món 1'), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(calls, [1, 2, 1]);
  });

  testWidgets('search resets page, retains selection and can be cleared', (
    tester,
  ) async {
    final calls = <(int, String)>[];
    Future<MemberFoodPage> loadFoods(
      int page,
      int pageSize,
      String search,
    ) async {
      calls.add((page, search));
      return MemberFoodPage(
        page: page,
        totalItems: 11,
        totalPages: 2,
        items: [
          MemberFoodItem(
            foodItemId: 1,
            categoryId: 1,
            categoryName: 'Món',
            name: 'Phở',
            price: 10000,
          ),
        ],
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: StaffOrderPage(loadFoods: loadFoods, loadTables: () async => []),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_shopping_cart));
    await tester.pump();
    await tester.tap(find.byTooltip('Trang sau'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Phở  ');
    await tester.tap(find.byTooltip('Tìm kiếm'));
    await tester.pumpAndSettle();
    expect(calls.last, (1, 'Phở'));
    expect(find.byIcon(Icons.remove), findsOneWidget);
    await tester.tap(find.byTooltip('Trang sau'));
    await tester.pumpAndSettle();
    expect(calls.last, (2, 'Phở'));
    await tester.tap(find.byTooltip('Xóa tìm kiếm'));
    await tester.pumpAndSettle();
    expect(calls.last, (1, ''));
    expect(find.byIcon(Icons.remove), findsOneWidget);
  });
}
