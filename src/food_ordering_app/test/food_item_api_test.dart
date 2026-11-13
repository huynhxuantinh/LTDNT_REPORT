import 'package:flutter_test/flutter_test.dart';
import 'package:trek_bikes_app/food_item_api.dart';

void main() {
  test('parses paged admin food item response', () {
    final response = AdminFoodPage.fromJson({
      'data': [
        {
          'foodItemId': 3,
          'categoryId': 1,
          'categoryName': 'Món chính',
          'name': 'Cơm gà',
          'price': 55000,
          'isAvailable': true,
          'createdAt': '2026-01-01T00:00:00Z',
        },
      ],
      'meta': {'page': 1, 'pageSize': 10, 'totalItems': 12, 'totalPages': 2},
    });

    expect(response.items.single.name, 'Cơm gà');
    expect(response.totalPages, 2);
  });
}
