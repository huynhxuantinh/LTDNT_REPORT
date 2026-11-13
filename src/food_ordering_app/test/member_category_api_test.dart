import 'package:flutter_test/flutter_test.dart';
import 'package:trek_bikes_app/member_category_api.dart';

void main() {
  test('parses member category response', () {
    final category = MemberCategory.fromJson({
      'categoryId': 1,
      'name': 'Món chính',
      'description': 'No bụng',
    });

    expect(category.categoryId, 1);
    expect(category.name, 'Món chính');
    expect(category.imageUrl, isNull);
  });
}
