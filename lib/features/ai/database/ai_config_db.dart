import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/features/ai/database/ai_api_key_storage.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/util/provider_type_utils.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/get_it.dart';

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

  @override
  int get schemaVersion => 1;

  /// Saves a config while keeping provider credentials in platform storage.
  ///
  /// [persistApiKey] can be disabled only for callers that intentionally have
  /// no credential (for example, a metadata-only sync update).
  Future<int> saveConfig(
    AiConfig config, {
    bool persistApiKey = true,
    bool preserveExistingApiKeyOnEmpty = false,
  }) async {
    final existingConfig = await configById(config.id).getSingleOrNull();

    final now = clock.now();

    final serializedConfig = await _configForStorage(
      config,
      persistApiKey: persistApiKey,
      preserveExistingApiKeyOnEmpty: preserveExistingApiKeyOnEmpty,
    );
    final dbEntity = AiConfigDbEntity(
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
      createdAt: existingConfig?.createdAt ?? now,
      updatedAt: now,
    );

    return into(aiConfigs).insertOnConflictUpdate(dbEntity);
  }

  Future<void> deleteConfig(String id) async {
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
      final storageKey =
          map['apiKeyStorageKey'] as String? ??
          apiKeyStorageKeyFor(entity.id, namespace: storageNamespace);
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
    final storageKey =
        config.apiKeyStorageKey ??
        apiKeyStorageKeyFor(config.id, namespace: storageNamespace);
    if (persistApiKey) {
      if (config.apiKey.isEmpty && !preserveExistingApiKeyOnEmpty) {
        await _apiKeyStorage.delete(storageKey);
      } else {
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
        ..['apiKeyStorageKey'] =
            config.apiKeyStorageKey ??
            apiKeyStorageKeyFor(config.id, namespace: storageNamespace);
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
