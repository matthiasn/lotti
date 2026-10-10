import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/features/ai/database/ai_api_key_storage.dart';
import 'package:lotti/features/ai/util/provider_type_utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/secure_storage.dart';

part 'ai_config_db.g.dart';

const aiConfigDbFileName = 'ai_config.sqlite';

@DriftDatabase(include: {'ai_config_db.drift'})
class AiConfigDb extends _$AiConfigDb {
  AiConfigDb({
    this.inMemoryDatabase = false,
    AiApiKeyStorage? apiKeyStorage,
    this.storageNamespace = 'default',
    Future<Directory> Function()? documentsDirectoryProvider,
    Future<Directory> Function()? tempDirectoryProvider,
  }) : _apiKeyStorage =
           apiKeyStorage ??
           (inMemoryDatabase
               ? AiApiKeyStorage.inMemory()
               : getIt.isRegistered<SecureStorage>()
               ? AiApiKeyStorage(getIt<SecureStorage>())
               : AiApiKeyStorage.inMemory()),
       super(
         openDbConnection(
           aiConfigDbFileName,
           inMemoryDatabase: inMemoryDatabase,
           documentsDirectoryProvider: documentsDirectoryProvider,
           tempDirectoryProvider: tempDirectoryProvider,
         ),
       );

  bool inMemoryDatabase = false;
  final AiApiKeyStorage _apiKeyStorage;
  final String storageNamespace;

  /// The schema this build writes. A restored backup may carry an
  /// older schema, which Drift migrates, but never a newer one.
  static const int currentSchemaVersion = 2;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) => m.createAll(),
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.createTable(aiConfigVersions);
          // Every existing row gets the time this device last wrote it, in
          // milliseconds (Drift stores DATETIME in seconds). Without a stamp
          // the row's next resend would carry none, and a receiver would
          // apply it in arrival order — the very overwrite ADR 0094 closes.
          await customStatement(
            'INSERT INTO ai_config_versions (id, stamp) '
            'SELECT id, COALESCE(updated_at, created_at) * 1000 '
            'FROM ai_configs',
          );
        }
      },
    );
  }

  /// The stamp of the version this device holds for [id]: its config's, or
  /// its deletion's once the config is gone. Null when no version is known.
  Future<int?> versionStamp(String id) =>
      versionStampById(id).getSingleOrNull();

  /// The hard deletions this device holds, by id: every stamp in
  /// `ai_config_versions` with no config row. "Send settings" re-sends them,
  /// since a deletion has no row of its own to replay.
  Future<Map<String, int>> hardDeletionStamps() async {
    final rows = await hardDeletions().get();
    return {for (final row in rows) row.id: row.stamp};
  }

  /// Saves a local edit of [config] and returns the stamp its version took.
  ///
  /// The stamp is the current time in milliseconds, or one past the stamp
  /// already held when the clock has not moved beyond it, so every local
  /// version outranks the one it replaces. The config, its stamp and the
  /// provider credential commit together; a sync message of this version
  /// must carry the returned stamp (ADR 0094).
  ///
  /// [notBefore] raises the stamp to at least that value, so a version can be
  /// made to outrank another config's: the provider undo stamps each model it
  /// restores no earlier than the provider it restores with it.
  ///
  /// [persistApiKey] can be disabled only for callers that intentionally have
  /// no credential (for example, a metadata-only sync update).
  Future<int> saveConfig(
    AiConfig config, {
    int? notBefore,
    bool persistApiKey = true,
    bool preserveExistingApiKeyOnEmpty = false,
  }) => transaction(() async {
    final stamp = _nextLocalStamp(
      await versionStamp(config.id),
      notBefore: notBefore,
    );
    await _writeConfig(
      config,
      stamp: stamp,
      existing: await configById(config.id).getSingleOrNull(),
      persistApiKey: persistApiKey,
      preserveExistingApiKeyOnEmpty: preserveExistingApiKeyOnEmpty,
    );
    return stamp;
  });

  /// Applies a received version of [config] stamped [stamp], unless this
  /// device already holds a newer one. Returns whether it was written.
  ///
  /// A greater stamp wins. On equal stamps a held deletion wins, and two
  /// configs are ordered by their content ([_orderingKey]) so every device
  /// keeps the same one; an identical copy changes nothing. So a timed-out
  /// send that lands after a newer version, or a replay of an older one, is
  /// dropped instead of overwriting the newer value. Nothing — not even the
  /// provider credential — is written for a dropped version.
  Future<bool> applyConfigVersion(
    AiConfig config, {
    required int stamp,
  }) => transaction(() async {
    final held = await versionStamp(config.id);
    final existing = await configById(config.id).getSingleOrNull();
    if (held != null) {
      if (stamp < held) return false;
      if (stamp == held) {
        // A version row with no config is a deletion, which wins a tie.
        if (existing == null) return false;
        // A stored provider keeps its credential in the keychain, not the
        // row; the ordering key ignores it anyway.
        final heldConfig = _configFromMap({
          'apiKey': '',
          ...jsonDecode(existing.serialized) as Map<String, dynamic>,
        });
        if (_orderingKey(config).compareTo(_orderingKey(heldConfig)) <= 0) {
          return false;
        }
      }
    }
    await _writeConfig(
      config,
      stamp: stamp,
      existing: existing,
      persistApiKey: true,
      preserveExistingApiKeyOnEmpty: false,
    );
    return true;
  });

  /// Deletes [id] locally and returns the stamp the deletion took.
  ///
  /// The stamp stays behind in `ai_config_versions`, so a copy of the config
  /// sent before the deletion cannot bring it back when it lands late. A
  /// sync message of this deletion must carry the returned stamp.
  Future<int> deleteConfig(String id) => transaction(() async {
    final stamp = _nextLocalStamp(await versionStamp(id));
    await _removeConfig(id);
    await _writeStamp(id, stamp);
    return stamp;
  });

  /// Applies a received deletion of [id] stamped [stamp], unless this device
  /// holds a newer version of it. A deletion wins a tie with a config.
  /// Returns whether a deletion was recorded.
  Future<bool> applyConfigDeletion(
    String id, {
    required int stamp,
  }) => transaction(() async {
    final held = await versionStamp(id);
    if (held != null && stamp < held) return false;
    await _removeConfig(id);
    await _writeStamp(id, stamp);
    return true;
  });

  /// Deletes [id] and the version this device held for it, as if it had
  /// never been seen here.
  ///
  /// For a removal that stays on this device (the orphaned-seed prune): it
  /// sends no deletion, so it must not outrank the version peers still hold
  /// either — their next copy of it applies again.
  Future<void> forgetConfig(String id) => transaction(() async {
    await _removeConfig(id);
    await (delete(
      aiConfigVersions,
    )..where((row) => row.id.equals(id))).go();
  });

  static int _nextLocalStamp(int? held, {int? notBefore}) {
    final now = clock.now().millisecondsSinceEpoch;
    final stamp = held != null && now <= held ? held + 1 : now;
    return notBefore != null && stamp < notBefore ? notBefore : stamp;
  }

  /// The content order that breaks a tie between two versions with the same
  /// stamp. It reads only what the payload carries, never the credential or
  /// this device's keychain name, so every device ranks the pair alike.
  static String _orderingKey(AiConfig config) => jsonEncode(
    Map<String, dynamic>.from(config.toJson())
      ..remove('apiKey')
      ..remove('apiKeyStorageKey'),
  );

  Future<void> _writeConfig(
    AiConfig config, {
    required int stamp,
    required AiConfigDbEntity? existing,
    required bool persistApiKey,
    required bool preserveExistingApiKeyOnEmpty,
  }) async {
    final now = clock.now();
    final serializedConfig = await _configForStorage(
      config,
      persistApiKey: persistApiKey,
      preserveExistingApiKeyOnEmpty: preserveExistingApiKeyOnEmpty,
    );
    await into(aiConfigs).insertOnConflictUpdate(
      AiConfigDbEntity(
        id: config.id,
        type: config.map(
          inferenceProvider: (_) => 'inferenceProvider',
          model: (_) => 'model',
          prompt: (_) => 'prompt',
          inferenceProfile: (_) => 'inferenceProfile',
          skill: (_) => 'skill',
        ),
        name: config.name,
        serialized: jsonEncode(_databaseJson(serializedConfig)),
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
    await _writeStamp(config.id, stamp);
  }

  Future<void> _writeStamp(String id, int stamp) => into(
    aiConfigVersions,
  ).insertOnConflictUpdate(AiConfigVersionEntity(id: id, stamp: stamp));

  Future<void> _removeConfig(String id) async {
    final existing = await configById(id).getSingleOrNull();
    if (existing != null) {
      final raw = jsonDecode(existing.serialized) as Map<String, dynamic>;
      if (raw['runtimeType'] == 'inferenceProvider') {
        final storageKey =
            raw['apiKeyStorageKey'] as String? ??
            apiKeyStorageKeyFor(id, namespace: storageNamespace);
        await _apiKeyStorage.delete(storageKey);
      }
    }
    await delete(aiConfigs).delete(AiConfigsCompanion(id: Value(id)));
  }

  Future<List<AiConfigDbEntity>> getConfigsByType(String type) {
    return configsByType(type).get();
  }

  Future<List<AiConfigDbEntity>> getAllConfigs() {
    return allConfigs().get();
  }

  Stream<List<AiConfigDbEntity>> watchAllConfigs() {
    return allConfigs().watch();
  }

  Future<AiConfig?> getConfigById(String id) async {
    final dbEntity = await configById(id).getSingleOrNull();
    if (dbEntity == null) return null;
    return configFromEntity(dbEntity);
  }

  /// Decodes [entity], migrating a legacy plaintext provider key if present.
  /// This is public because repository list/stream reads start from Drift rows.
  Future<AiConfig> configFromEntity(AiConfigDbEntity entity) async {
    final raw = jsonDecode(entity.serialized) as Map<String, dynamic>;
    final map = Map<String, dynamic>.from(raw);

    if (map['runtimeType'] == 'inferenceProvider') {
      final storageKey = apiKeyStorageKeyFor(
        entity.id,
        namespace: storageNamespace,
      );
      final legacyApiKey = map.remove('apiKey');
      final needsMigration =
          legacyApiKey != null || map['apiKeyStorageKey'] != storageKey;
      if (legacyApiKey is String && legacyApiKey.isNotEmpty) {
        // Write first. If platform storage is unavailable, retain the legacy
        // row so the next launch can retry without losing the credential.
        await _apiKeyStorage.write(key: storageKey, value: legacyApiKey);
      }
      map['apiKeyStorageKey'] = storageKey;
      if (needsMigration) {
        await (update(
          aiConfigs,
        )..where((row) => row.id.equals(entity.id))).write(
          AiConfigsCompanion(serialized: Value(jsonEncode(map))),
        );
      }
      final config = _configFromMap({...map, 'apiKey': ''});
      return (config as AiConfigInferenceProvider).copyWith(
        apiKey: await _apiKeyStorage.read(storageKey) ?? '',
        apiKeyStorageKey: storageKey,
      );
    }

    return _configFromMap(map);
  }

  Future<AiConfig> _configForStorage(
    AiConfig config, {
    required bool persistApiKey,
    required bool preserveExistingApiKeyOnEmpty,
  }) async {
    if (config is! AiConfigInferenceProvider) return config;
    // Never trust an identifier received from another world/device. The
    // namespace is derived from this database instance so equal config IDs in
    // real and demo worlds cannot overwrite each other's credentials.
    final storageKey = apiKeyStorageKeyFor(
      config.id,
      namespace: storageNamespace,
    );
    if (persistApiKey) {
      if (config.apiKey.isEmpty && !preserveExistingApiKeyOnEmpty) {
        await _apiKeyStorage.delete(storageKey);
      } else if (config.apiKey.isNotEmpty) {
        await _apiKeyStorage.write(key: storageKey, value: config.apiKey);
      }
    }
    return config.copyWith(apiKeyStorageKey: storageKey);
  }

  Map<String, dynamic> _databaseJson(AiConfig config) {
    final json = Map<String, dynamic>.from(config.toJson());
    if (config is AiConfigInferenceProvider) {
      json
        ..remove('apiKey')
        ..['apiKeyStorageKey'] = config.apiKeyStorageKey;
    }
    return json;
  }

  AiConfig _configFromMap(Map<String, dynamic> map) {
    // Harden parsing for legacy/unknown provider types to avoid crashes when
    // reading single configs (e.g., during delete actions).
    final dynamic rawType = map['inferenceProviderType'];
    final normalized = normalizeProviderType(
      rawType is String ? rawType : (rawType?.toString() ?? ''),
    );
    map['inferenceProviderType'] = normalized;

    return AiConfig.fromJson(map);
  }
}

/// Stable platform-keychain name for one provider configuration.
String apiKeyStorageKeyFor(String configId, {String namespace = 'default'}) =>
    'ai_provider_api_key:$namespace:$configId';
