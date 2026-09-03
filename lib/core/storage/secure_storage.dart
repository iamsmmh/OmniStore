import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:omnistore/core/logger/app_logger.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();
  final _logger = AppLogger.getLogger('SecureStorage');

  static const _keyAuthToken = 'auth_token';
  static const _keyRefreshToken = 'refresh_token';

  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      _logger.severe('Failed to write to secure storage: $key', e);
      rethrow;
    }
  }

  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      _logger.severe('Failed to read from secure storage: $key', e);
      return null;
    }
  }

  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      _logger.severe('Failed to delete from secure storage: $key', e);
    }
  }

  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      _logger.severe('Failed to delete all from secure storage', e);
    }
  }

  Future<bool> containsKey(String key) async {
    try {
      return await _storage.containsKey(key: key);
    } catch (e) {
      _logger.severe('Failed to check key in secure storage: $key', e);
      return false;
    }
  }

  // Convenience methods
  Future<void> saveAuthToken(String token) async {
    await write(_keyAuthToken, token);
  }

  Future<String?> getAuthToken() async {
    return await read(_keyAuthToken);
  }

  Future<void> saveRefreshToken(String token) async {
    await write(_keyRefreshToken, token);
  }

  Future<String?> getRefreshToken() async {
    return await read(_keyRefreshToken);
  }

  Future<void> clearTokens() async {
    await delete(_keyAuthToken);
    await delete(_keyRefreshToken);
  }
}
