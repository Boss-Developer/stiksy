import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps the Supabase session (refresh token) in the Android Keystore
/// instead of plain SharedPreferences.
class SecureSessionStorage extends LocalStorage {
  const SecureSessionStorage();
  static const _key = 'stiksy_supabase_session';
  static const _store = FlutterSecureStorage();

  @override
  Future<void> initialize() async {}
  @override
  Future<bool> hasAccessToken() => _store.containsKey(key: _key);
  @override
  Future<String?> accessToken() => _store.read(key: _key);
  @override
  Future<void> removePersistedSession() => _store.delete(key: _key);
  @override
  Future<void> persistSession(String persistSessionString) =>
      _store.write(key: _key, value: persistSessionString);
}
