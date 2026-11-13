import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String get baseUrl =>
      normalize(dotenv.env['API_URL'] ?? 'http://10.0.2.2:5000');

  static String normalize(String url) => url.replaceFirst(RegExp(r'/+$'), '');
}
