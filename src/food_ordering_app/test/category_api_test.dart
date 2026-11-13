import 'package:flutter_test/flutter_test.dart';
import 'package:trek_bikes_app/category_api.dart';

void main() {
  test('parses category response without optional fields', () {
    final category = AdminCategory.fromJson({
      'categoryId': 7,
      'name': 'Món chính',
      'isActive': true,
      'createdAt': '2026-01-01T00:00:00Z',
    });

    expect(category.categoryId, 7);
    expect(category.description, isNull);
  });
}
