import 'dart:convert';

import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/sync/inbox_service.dart';

class SyncConfigService {
  final _storage = const FlutterSecureStorage();
  final sharedSecretKey = 'sharedSecret';
  final imapConfigKey = 'imapConfig';

  Future<String?> getSharedKey() async {
    return _storage.read(key: sharedSecretKey);
  }

  Future<SyncConfig?> getSyncConfig() async {
    final sharedKey = await getSharedKey();
    final imapConfig = await getImapConfig();

    if (sharedKey != null && imapConfig != null) {
      return SyncConfig(
        imapConfig: imapConfig,
        sharedSecret: sharedKey,
      );
    }
    return null;
  }

  Future<void> generateSharedKey() async {
    final key = Key.fromSecureRandom(32);
    final sharedKey = key.base64;
    await _storage.write(key: sharedSecretKey, value: sharedKey);
  }

  Future<void> setSyncConfig(String configJson) async {
    final syncConfig = SyncConfig.fromJson(
      json.decode(configJson) as Map<String, dynamic>,
    );
    await _storage.write(
      key: sharedSecretKey,
      value: syncConfig.sharedSecret,
    );
    await _storage.write(
      key: imapConfigKey,
      value: json.encode(syncConfig.imapConfig.toJson()),
    );
  }

  Future<void> deleteSharedKey() async {
    await _storage.delete(key: sharedSecretKey);
  }

  Future<void> deleteImapConfig() async {
    await _storage.delete(key: imapConfigKey);
  }

  Future<void> setImapConfig(ImapConfig imapConfig) async {
    final json = jsonEncode(imapConfig);
    await _storage.write(key: imapConfigKey, value: json);
  }

  Future<ImapConfig?> getImapConfig() async {
    final imapConfigJson = await _storage.read(key: imapConfigKey);
    ImapConfig? imapConfig;

    if (imapConfigJson != null) {
      imapConfig = ImapConfig.fromJson(
        json.decode(imapConfigJson) as Map<String, dynamic>,
      );
    }

    return imapConfig;
  }

  Future<void> resetOffset() async {
    await _storage.delete(key: lastReadUidKey);
    await getIt<VectorClockService>().setNewHost();
  }
}
