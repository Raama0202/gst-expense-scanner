import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStore {
  SecureStore(this._storage);
  final FlutterSecureStorage _storage;

  static const _tokenKey = 'admin_access_token';
  static const _roleKey = 'admin_role';
  static const _companyKey = 'admin_company_id';
  static const _nameKey = 'admin_display_name';

  Future<String?> get token => _storage.read(key: _tokenKey);
  Future<String?> get role => _storage.read(key: _roleKey);
  Future<String?> get companyId => _storage.read(key: _companyKey);
  Future<String?> get displayName => _storage.read(key: _nameKey);

  Future<void> saveSession({
    required String token,
    required String role,
    String? companyId,
    String? displayName,
  }) async {
    await Future.wait([
      _storage.write(key: _tokenKey, value: token),
      _storage.write(key: _roleKey, value: role),
      _storage.write(key: _companyKey, value: companyId),
      _storage.write(key: _nameKey, value: displayName),
    ]);
  }

  Future<void> clear() => _storage.deleteAll();
}
