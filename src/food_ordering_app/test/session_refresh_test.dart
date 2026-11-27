import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:food_ordering_app/auth_api.dart';
import 'package:food_ordering_app/session_helper.dart';

String token(DateTime expiry) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'exp': expiry.millisecondsSinceEpoch ~/ 1000}))).replaceAll('=', '')}.signature';
Map<String, Object> session(String access, String refresh) => {
  'userId': '1',
  'fullName': 'An',
  'email': 'an@example.com',
  'role': 'Member',
  'accessToken': access,
  'refreshToken': refresh,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    dotenv.loadFromString(envString: 'API_URL=http://localhost:5000');
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('expired token is refreshed once for concurrent requests and rotated tokens are saved', () async {
    final old = token(DateTime.now().subtract(const Duration(minutes: 1)));
    final updated = token(DateTime.now().add(const Duration(minutes: 30)));
    await SessionHelper.save(AuthSession.fromJson(session(old, 'old-refresh')));
    var count = 0;
    final client = MockClient((request) async {
      count++;
      expect(request.url.path, '/api/auth/refresh');
      expect(jsonDecode(request.body)['refreshToken'], 'old-refresh');
      return http.Response(jsonEncode(session(updated, 'new-refresh')), 200);
    });
    await http.runWithClient(() async {
      expect(
        await Future.wait(List.generate(5, (_) => SessionHelper.accessToken)),
        List.filled(5, updated),
      );
      expect(await SessionHelper.accessToken, updated);
      expect(await SessionHelper.refreshToken, 'new-refresh');
      expect(count, 1);
    }, () => client);
  });

  test(
    'unauthorized refresh clears session and notifies the application',
    () async {
      await SessionHelper.save(
        AuthSession.fromJson(
          session(
            token(DateTime.now().subtract(const Duration(seconds: 1))),
            'invalid',
          ),
        ),
      );
      final revision = SessionHelper.sessionExpired.value;
      await http.runWithClient(
        () async {
          expect(await SessionHelper.accessToken, isNull);
          expect(await SessionHelper.refreshToken, isNull);
          expect(SessionHelper.sessionExpired.value, revision + 1);
        },
        () => MockClient(
          (_) async => http.Response.bytes(
            utf8.encode('{"error":{"message":"Phiên hết hạn."}}'),
            401,
          ),
        ),
      );
    },
  );

  test(
    'network or server failure preserves the session for offline use',
    () async {
      final expired = token(
        DateTime.now().subtract(const Duration(minutes: 1)),
      );
      await SessionHelper.save(
        AuthSession.fromJson(session(expired, 'refresh')),
      );
      await http.runWithClient(
        () async {
          expect(await SessionHelper.accessToken, expired);
          expect(await SessionHelper.refreshToken, 'refresh');
          expect(await SessionHelper.email, 'an@example.com');
        },
        () => MockClient(
          (_) async => http.Response.bytes(
            utf8.encode('{"error":{"message":"Thử lại."}}'),
            503,
          ),
        ),
      );
    },
  );

  test(
    'a refresh completing after logout cannot restore the old session',
    () async {
      final old = token(DateTime.now().subtract(const Duration(minutes: 1)));
      final updated = token(DateTime.now().add(const Duration(minutes: 30)));
      await SessionHelper.save(
        AuthSession.fromJson(session(old, 'old-refresh')),
      );
      final received = Completer<void>();
      final response = Completer<http.Response>();
      await http.runWithClient(
        () async {
          final pending = SessionHelper.accessToken;
          await received.future;
          await SessionHelper.clear();
          response.complete(
            http.Response(jsonEncode(session(updated, 'new-refresh')), 200),
          );
          expect(await pending, isNull);
          expect(await SessionHelper.accessToken, isNull);
          expect(await SessionHelper.refreshToken, isNull);
        },
        () => MockClient((_) {
          received.complete();
          return response.future;
        }),
      );
    },
  );
}
