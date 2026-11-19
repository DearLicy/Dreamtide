import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProviderKeyStore {
  static const _secureKey = 'dreamtide.provider.apiKey';
  static const _webKey = 'dreamtide.provider.apiKey.web';
  static final FlutterSecureStorage _secure = const FlutterSecureStorage();

  String? _sessionKey;

  Future<String?> read({required bool persistent}) async {
    if (kIsWeb) {
      if (!persistent) return _sessionKey;
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_webKey);
    }
    return _secure.read(key: _secureKey);
  }

  Future<void> write(String value, {required bool persistent}) async {
    if (kIsWeb) {
      _sessionKey = value;
      final prefs = await SharedPreferences.getInstance();
      if (persistent) {
        await prefs.setString(_webKey, value);
      } else {
        await prefs.remove(_webKey);
      }
      return;
    }
    if (value.isEmpty) {
      await _secure.delete(key: _secureKey);
    } else {
      await _secure.write(key: _secureKey, value: value);
    }
  }

  Future<void> clear() async {
    _sessionKey = null;
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_webKey);
      return;
    }
    await _secure.delete(key: _secureKey);
  }
}
