import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  final _storage = const FlutterSecureStorage();
  final _state = <String, String>{};

  Future<String?>? readValue(String key) async {
    final exists = _state[key] != null;

    if (!exists) {
      final fromSecureStorage = await _storage.read(key: key);
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
    debugPrint('writeValue $key $value');
    _state[key] = value;
    EasyDebounce.debounce(
      'writeValue-$key',
      const Duration(seconds: 1),
      () async {
        await _storage.write(
          key: key,
          value: _state[key],
          iOptions: IOSOptions.defaultOptions,
        );
      },
    );
  }

  Future<void> write({
    required String key,
    required String value,
  }) async {
    await writeValue(key, value);
  }

  Future<void> delete({required String key}) async {
    await _storage.delete(key: key);
  }
}
