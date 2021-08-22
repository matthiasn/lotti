import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static final _storage = new FlutterSecureStorage();

  static readValue(String key) async {
    String? value = await _storage.read(key: key);
    print(value);
    return value;
  }

  static writeValue(String key, String value) async {
    final options = IOSOptions(accessibility: IOSAccessibility.first_unlock);
    await _storage.write(key: key, value: value, iOptions: options);

    readValue(key);
  }
}
