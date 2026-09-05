import 'package:lotti/features/sync/secure_storage.dart';

/// Stores inference-provider credentials outside the AI configuration database.
///
/// Production instances delegate to [SecureStorage], which uses the platform
/// credential store. The in-memory constructor exists solely for isolated
/// database tests and is never used by an installed application.
class AiApiKeyStorage {
  AiApiKeyStorage(SecureStorage storage) : _storage = storage, _values = null;

  AiApiKeyStorage.inMemory() : _storage = null, _values = <String, String>{};

  final SecureStorage? _storage;
  final Map<String, String>? _values;

  Future<String?> read(String key) async =>
      _values?[key] ?? await _storage!.read(key: key);

  Future<void> write({required String key, required String value}) async {
    final values = _values;
    if (values != null) {
      values[key] = value;
      return;
    }
    await _storage!.write(key: key, value: value);
  }

  Future<void> delete(String key) async {
    final values = _values;
    if (values != null) {
      values.remove(key);
      return;
    }
    await _storage!.delete(key: key);
  }
}
