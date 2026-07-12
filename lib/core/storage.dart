import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppStorage {
  static const _store = FlutterSecureStorage();

  static const _keyAccess  = 'access_token';
  static const _keyRefresh = 'refresh_token';
  static const _keyUserId  = 'user_id';
  static const _keyRole    = 'user_role';
  static const _keyUserJson = 'user_json';

  static Future<void> saveTokens(String access, String refresh) async {
    await _store.write(key: _keyAccess,  value: access);
    await _store.write(key: _keyRefresh, value: refresh);
  }

  static Future<String?> getAccessToken()  async => _store.read(key: _keyAccess);
  static Future<String?> getRefreshToken() async => _store.read(key: _keyRefresh);

  static Future<void> saveUserInfo(int id, String role) async {
    await _store.write(key: _keyUserId, value: id.toString());
    await _store.write(key: _keyRole,   value: role);
  }

  static Future<String?> getRole()   async => _store.read(key: _keyRole);
  static Future<String?> getUserId() async => _store.read(key: _keyUserId);

  // Cache the full user profile so startup never needs a network call
  static Future<void> cacheUser(Map<String, dynamic> json) async {
    await _store.write(key: _keyUserJson, value: jsonEncode(json));
  }

  static Future<Map<String, dynamic>?> getCachedUser() async {
    final raw = await _store.read(key: _keyUserJson);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async => _store.deleteAll();
}
