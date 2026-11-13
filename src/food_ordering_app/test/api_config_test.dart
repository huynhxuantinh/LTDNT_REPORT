import 'package:flutter_test/flutter_test.dart';
import 'package:trek_bikes_app/api_config.dart';

void main() {
  test('normalizes API URL by removing trailing slashes', () {
    expect(
      ApiConfig.normalize('http://10.0.2.2:5000///'),
      'http://10.0.2.2:5000',
    );
  });
}
