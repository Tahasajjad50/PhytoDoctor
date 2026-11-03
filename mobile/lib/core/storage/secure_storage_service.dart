import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';

class SecureStorageService {
  static const String _keyAccessToken = 'phyto_access_token';
  static const String _keyRefreshToken = 'phyto_refresh_token';
  static const String _keyUserData = 'phyto_user_data';

  final FlutterSecureStorage _storage;
  // In-memory fallback for test harnesses or environments where native keychain is unavailable
  final Map<String, String> _memoryCache = {};

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  Future<void> saveTokens({required String accessToken, String? refreshToken}) async {
    _memoryCache[_keyAccessToken] = accessToken;
    if (refreshToken != null) _memoryCache[_keyRefreshToken] = refreshToken;

    try {
      await _storage.write(key: _keyAccessToken, value: accessToken);
      if (refreshToken != null) {
        await _storage.write(key: _keyRefreshToken, value: refreshToken);
      }
    } catch (_) {
      // Fallback kept in memory cache
    }
  }

  Future<String?> getAccessToken() async {
    if (_memoryCache.containsKey(_keyAccessToken)) {
      return _memoryCache[_keyAccessToken];
    }
    try {
      final token = await _storage.read(key: _keyAccessToken);
      if (token != null) _memoryCache[_keyAccessToken] = token;
      return token;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUserSession(UserModel user) async {
    final jsonStr = jsonEncode(user.toJson());
    _memoryCache[_keyUserData] = jsonStr;
    try {
      await _storage.write(key: _keyUserData, value: jsonStr);
    } catch (_) {
      // Fallback kept in memory cache
    }
  }

  Future<UserModel?> getUserSession() async {
    String? jsonStr = _memoryCache[_keyUserData];
    if (jsonStr == null) {
      try {
        jsonStr = await _storage.read(key: _keyUserData);
      } catch (_) {
        jsonStr = null;
      }
    }

    if (jsonStr != null) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return UserModel.fromJson(map);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> clearAll() async {
    _memoryCache.clear();
    try {
      await _storage.deleteAll();
    } catch (_) {
      // Memory cleared
    }
  }
}
