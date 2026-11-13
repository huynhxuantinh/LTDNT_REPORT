import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:trek_bikes_app/auth_api.dart';

class SessionHelper {
  static const _storage = FlutterSecureStorage();
  static Future<void> save(
    dynamic sessionOrEmail, [
    String? legacyAccessToken,
  ]) async {
    if (sessionOrEmail is AuthSession) {
      await _storage.write(key: 'email', value: sessionOrEmail.email);
      await _storage.write(
        key: 'access_token',
        value: sessionOrEmail.accessToken,
      );
      await _storage.write(
        key: 'refresh_token',
        value: sessionOrEmail.refreshToken,
      );
      await _storage.write(key: 'role', value: sessionOrEmail.role);
      return;
    }
    await _storage.write(key: 'email', value: sessionOrEmail as String);
    await _storage.write(key: 'access_token', value: legacyAccessToken);
  }

  static Future<void> clear() => _storage.deleteAll();
  static Future<void> delete() => clear();
  static Future<String?> get email => _storage.read(key: 'email');
  static Future<String?> get accessToken => _storage.read(key: 'access_token');
  static Future<String?> get token => accessToken;
  static Future<String?> get refreshToken =>
      _storage.read(key: 'refresh_token');
  static Future<String?> get role => _storage.read(key: 'role');
}
