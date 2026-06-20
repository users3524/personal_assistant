library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class ApiKeyStore {
  Future<String?> read();
  Future<void> write(String? apiKey);
  Future<void> delete();
}

class SecureApiKeyStore implements ApiKeyStore {
  SecureApiKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const key = 'ai_api_key';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: key);

  @override
  Future<void> write(String? apiKey) async {
    final normalized = apiKey?.trim() ?? '';
    if (normalized.isEmpty) {
      await delete();
      return;
    }
    await _storage.write(key: key, value: normalized);
  }

  @override
  Future<void> delete() => _storage.delete(key: key);
}

class InMemoryApiKeyStore implements ApiKeyStore {
  String? _apiKey;

  InMemoryApiKeyStore([this._apiKey]);

  @override
  Future<String?> read() async => _apiKey;

  @override
  Future<void> write(String? apiKey) async {
    final normalized = apiKey?.trim() ?? '';
    _apiKey = normalized.isEmpty ? null : normalized;
  }

  @override
  Future<void> delete() async {
    _apiKey = null;
  }
}
