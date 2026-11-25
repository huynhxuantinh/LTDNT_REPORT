import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trek_bikes_app/auth_api.dart';
import 'package:trek_bikes_app/category_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uploads and deletes a category image with authorization', () async {
    dotenv.loadFromString(envString: 'API_URL=http://localhost:5000');
    FlutterSecureStorage.setMockInitialValues({'access_token': 'token'});
    final calls = <String>[];
    final client = MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      expect(request.headers['Authorization'], 'Bearer token');
      if (request.method == 'POST') {
        expect(
          request.headers['content-type'],
          startsWith('multipart/form-data;'),
        );
        expect(request.body, contains('image/png'));
        return http.Response('{"imageUrl":"/uploads/foods/new.png"}', 200);
      }
      return http.Response('', 204);
    });

    await http.runWithClient(() async {
      final url = await CategoryApi.uploadImage(
        7,
        Uint8List.fromList([1, 2]),
        'photo.png',
      );
      expect(url, '/uploads/foods/new.png');
      await CategoryApi.deleteImage(7);
    }, () => client);
    expect(calls, [
      'POST /api/admin/categories/7/image',
      'DELETE /api/admin/categories/7/image',
    ]);
  });

  test('rejects unsupported image extension', () async {
    await expectLater(
      CategoryApi.uploadImage(7, Uint8List.fromList([1]), 'file.gif'),
      throwsA(isA<ApiException>()),
    );
  });
}
