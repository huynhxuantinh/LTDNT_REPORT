import 'package:flutter_test/flutter_test.dart';
import 'package:trek_bikes_app/member_food_api.dart';

void main() {
  test('parses paged member food response', () {
    final page = MemberFoodPage.fromJson({
      'data': [
        {
          'foodItemId': 1,
          'categoryId': 2,
          'categoryName': 'Món chính',
          'name': 'Cơm gà',
          'price': 45000,
        },
      ],
      'meta': {'page': 1, 'pageSize': 10, 'totalItems': 1, 'totalPages': 1},
    });

    expect(page.items.single.name, 'Cơm gà');
    expect(page.totalPages, 1);
  });
}
