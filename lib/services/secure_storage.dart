import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Read-through cache over the platform keychain ([FlutterSecureStorage]) for
/// sync secrets (the Matrix config JSON, etc.).
///
/// Values are namespaced by the app's package name (iOS/macOS `accountName`)
/// so multiple build flavours do not collide in the shared keychain. The
/// in-memory [_state] map caches the first read of each key for the process
/// lifetime; [writeValue] deletes before writing to keep the cache and the
/// backing store consistent.
class SecureStorage {
  SecureStorage();

  final _storage = const FlutterSecureStorage();
  final _state = <String, String>{};

  /// Returns the value for [key], reading from the keychain on a cache miss
  /// and memoising the result. `null` when the key is absent in both the cache
  /// and the keychain.
  Future<String?>? readValue(String key) async {
    final exists = _state[key] != null;

    if (!exists) {
      final info = await PackageInfo.fromPlatform();
      final fromSecureStorage = await _storage.read(
        key: key,
        iOptions: IOSOptions(
          accountName: info.packageName,
        ),
        mOptions: MacOsOptions(
          accountName: info.packageName,
        ),
      );
      if (fromSecureStorage != null) {
        _state[key] = fromSecureStorage;
      }
    }

    return _state[key];
  }

  Future<String?>? read({required String key}) async {
    return readValue(key);
  }

  /// Persists [value] under [key] in both the in-memory cache and the
  /// keychain, deleting any prior entry first so the two stay in sync.
  Future<void> writeValue(String key, String value) async {
    await delete(key: key);
    _state[key] = value;

    final info = await PackageInfo.fromPlatform();

    await _storage.write(
      key: key,
      value: value,
      iOptions: IOSOptions(
        accountName: info.packageName,
      ),
      mOptions: MacOsOptions(
        accountName: info.packageName,
      ),
    );
  }

  Future<void> write({
    required String key,
    required String value,
  }) async {
    await writeValue(key, value);
  }

  /// Removes [key] from both the in-memory cache and the keychain.
  Future<void> delete({required String key}) async {
    _state.remove(key);
    final info = await PackageInfo.fromPlatform();
    await _storage.delete(
      key: key,
      iOptions: IOSOptions(
        accountName: info.packageName,
      ),
      mOptions: MacOsOptions(
        accountName: info.packageName,
      ),
    );
  }
}
