import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SecureStorage {
  SecureStorage();

  final _storage = const FlutterSecureStorage();
  final _state = <String, String>{};

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
