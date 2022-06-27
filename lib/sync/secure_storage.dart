import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  final _storage = const FlutterSecureStorage();

  Future<String?>? readValue(String key) async {
    return _storage.read(key: key);
  }

  Future<String?>? read({required String key}) async {
    return readValue(key);
  }

  Future<void> writeValue(String key, String value) async {
    const options = IOSOptions(accessibility: IOSAccessibility.first_unlock);
    await _storage.write(key: key, value: value, iOptions: options);
    await readValue(key);
  }

  Future<void> write({
    required String key,
    required String value,
  }) async {
    await writeValue(key, value);
    await readValue(key);
  }

  Future<void> delete({required String key}) async {
    await _storage.delete(key: key);
  }
}
