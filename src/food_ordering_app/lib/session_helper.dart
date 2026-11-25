import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:trek_bikes_app/auth_api.dart';

class SessionHelper {
  static const _storage = FlutterSecureStorage();
  static final sessionExpired = ValueNotifier<int>(0);
  static Future<void> _writes = Future.value();
  static Future<String?>? _refreshing;
  static int? _refreshGeneration;
  static int _generation = 0;

  static Future<T> _write<T>(Future<T> Function() action) {
    final result = _writes.then((_) => action());
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  static Future<void> save(
    dynamic sessionOrEmail, [
    String? legacyAccessToken,
  ]) {
    _generation++;
    return _write(() => _save(sessionOrEmail, legacyAccessToken));
  }

  static Future<void> _save(
    dynamic sessionOrEmail,
    String? legacyAccessToken,
  ) async {
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

  static Future<void> clear() {
    _generation++;
    return _write(() => _storage.deleteAll());
  }

  static Future<void> delete() => clear();
  static Future<String?> get email => _storage.read(key: 'email');
  static Future<String?> get accessToken async {
    await _writes;
    final token = await _storage.read(key: 'access_token');
    if (token == null || !_needsRefresh(token)) return token;
    final generation = _generation;
    if (_refreshing != null && _refreshGeneration == generation)
      return _refreshing;
    final future = _refresh(token, generation);
    _refreshing = future;
    _refreshGeneration = generation;
    try {
      return await future;
    } finally {
      if (identical(_refreshing, future)) {
        _refreshing = null;
        _refreshGeneration = null;
      }
    }
  }

  static bool _needsRefresh(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final exp = payload is Map ? payload['exp'] : null;
      if (exp is! num) return false;
      return DateTime.fromMillisecondsSinceEpoch(
        exp.toInt() * 1000,
        isUtc: true,
      ).isBefore(DateTime.now().toUtc().add(const Duration(seconds: 60)));
    } catch (_) {
      return false;
    }
  }

  static Future<String?> _refresh(String oldToken, int generation) async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (generation != _generation) {
      await _writes;
      return _storage.read(key: 'access_token');
    }
    if (refreshToken == null || refreshToken.isEmpty) {
      if (await _expireSession(generation)) return null;
      await _writes;
      return _storage.read(key: 'access_token');
    }
    try {
      final session = await AuthApi.refresh(refreshToken: refreshToken);
      return await _write(() async {
        if (generation != _generation)
          return _storage.read(key: 'access_token');
        await _save(session, null);
        if (generation != _generation) return null;
        return session.accessToken;
      });
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        if (await _expireSession(generation)) return null;
        await _writes;
        return _storage.read(key: 'access_token');
      }
      if (generation == _generation) return oldToken;
      await _writes;
      return _storage.read(key: 'access_token');
    } catch (_) {
      // Preserve the local session and offline data when the service is unavailable.
      if (generation == _generation) return oldToken;
      await _writes;
      return _storage.read(key: 'access_token');
    }
  }

  static Future<bool> _expireSession(int generation) async {
    final expired = await _write(() async {
      if (generation != _generation) return false;
      _generation++;
      await _storage.deleteAll();
      return true;
    });
    if (expired) sessionExpired.value++;
    return expired;
  }

  static Future<String?> get token => accessToken;
  static Future<String?> get refreshToken =>
      _storage.read(key: 'refresh_token');
  static Future<String?> get role => _storage.read(key: 'role');
}
