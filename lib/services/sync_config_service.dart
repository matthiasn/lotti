import 'dart:convert';

import 'package:encrypt/encrypt.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/sync/imap_client.dart';
import 'package:lotti/sync/secure_storage.dart';
import 'package:lotti/sync/utils.dart';

class SyncConfigService {
  SyncConfig? _syncConfig;

  Future<String?> getSharedKey() async {
    return getIt<SecureStorage>().read(key: sharedSecretKey);
  }

  Future<SyncConfig?> getSyncConfig() async {
    final sharedKey = await getSharedKey();
    final imapConfig = await getImapConfig();

    if (sharedKey != null && imapConfig != null) {
      _syncConfig = SyncConfig(
        imapConfig: imapConfig,
        sharedSecret: sharedKey,
      );
    }
    return _syncConfig;
  }

  String generateRandomKey() {
    final key = Key.fromSecureRandom(32);
    return key.base64;
  }

  Future<void> generateSharedKey() async {
    await getIt<SecureStorage>().write(
      key: sharedSecretKey,
      value: generateRandomKey(),
    );
    final lastReadUid = await getLastReadUid();
    if (lastReadUid == null) {
      await setLastReadUid(0);
    }

    final host = await getIt<VectorClockService>().getHost();
    if (host == null) {
      await getIt<VectorClockService>().setNewHost();
    }
  }

  Future<void> setSyncConfig(String configJson) async {
    final syncConfig = SyncConfig.fromJson(
      json.decode(configJson) as Map<String, dynamic>,
    );
    await getIt<SecureStorage>().write(
      key: sharedSecretKey,
      value: syncConfig.sharedSecret,
    );
    await getIt<SecureStorage>().write(
      key: imapConfigKey,
      value: json.encode(syncConfig.imapConfig.toJson()),
    );
  }

  Future<void> deleteSharedKey() async {
    await getIt<SecureStorage>().delete(key: sharedSecretKey);
  }

  Future<void> deleteImapConfig() async {
    await getIt<SecureStorage>().delete(key: imapConfigKey);
  }

  Future<void> setImapConfig(ImapConfig imapConfig) async {
    final json = jsonEncode(imapConfig);
    await getIt<SecureStorage>().write(key: imapConfigKey, value: json);
  }

  Future<bool> testConnection(SyncConfig syncConfig) async {
    return getIt<ImapClientManager>().imapAction(
      (client) async => client.isLoggedIn,
      syncConfig: syncConfig,
    );
  }

  Future<ImapConfig?> getImapConfig() async {
    final imapConfigJson =
        await getIt<SecureStorage>().read(key: imapConfigKey);
    ImapConfig? imapConfig;

    if (imapConfigJson != null) {
      imapConfig = ImapConfig.fromJson(
        json.decode(imapConfigJson) as Map<String, dynamic>,
      );
    }

    return imapConfig;
  }

  Future<void> resetHostId() async {
    await getIt<VectorClockService>().setNewHost();
  }

  Future<void> resetOffset() async {
    await getIt<SecureStorage>().delete(key: lastReadUidKey);
    await setLastReadUid(0);
    await resetHostId();
  }
}
