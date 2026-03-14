import 'dart:async';
import 'dart:convert';

import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/util/provider_type_utils.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ai_config_repository.g.dart';

/// Result object for cascade deletion operations
class CascadeDeletionResult {
  const CascadeDeletionResult({
    required this.deletedModels,
    required this.providerName,
  });

  final List<AiConfigModel> deletedModels;
  final String providerName;
}

@Riverpod(keepAlive: true)
AiConfigRepository aiConfigRepository(Ref ref) {
  return getIt<AiConfigRepository>();
}

class AiConfigRepository {
  AiConfigRepository(this._db);

  final AiConfigDb _db;
  final Map<AiConfigType, List<AiConfig>> _configsByTypeCache =
      <AiConfigType, List<AiConfig>>{};
  final Map<AiConfigType, Future<List<AiConfig>>> _configsByTypeInFlight =
      <AiConfigType, Future<List<AiConfig>>>{};
  final Map<String, AiConfig?> _configByIdCache = <String, AiConfig?>{};
  final Map<String, Future<AiConfig?>> _configByIdInFlight =
      <String, Future<AiConfig?>>{};

  /// Save or update an AI configuration
  Future<void> saveConfig(
    AiConfig config, {
    bool fromSync = false,
  }) async {
    await _db.saveConfig(config);
    _storeConfig(config);
    if (!fromSync) {
      await getIt<OutboxService>().enqueueMessage(
        SyncMessage.aiConfig(
          aiConfig: config,
          status: SyncEntryStatus.initial,
        ),
      );
    }
  }

  /// Delete an AI configuration by its ID
  Future<void> deleteConfig(
    String id, {
    bool fromSync = false,
  }) async {
    await _db.deleteConfig(id);
    _invalidateConfig(id);
    if (!fromSync) {
      await getIt<OutboxService>().enqueueMessage(
        SyncMessage.aiConfigDelete(id: id),
      );
    }
  }

  /// Delete an inference provider and all its associated models.
  ///
  /// This method performs cascade deletion within a transaction to ensure atomicity:
  /// 1. Fetches all models associated with the provider
  /// 2. Deletes each model
  /// 3. Deletes the provider itself
  ///
  /// If any deletion fails, the entire transaction is rolled back to maintain
  /// data integrity and prevent partial deletions.
  ///
  /// Returns detailed information about the deletion operation.
  Future<CascadeDeletionResult> deleteInferenceProviderWithModels(
    String providerId, {
    bool fromSync = false,
  }) async {
    return _db.transaction(() async {
      try {
        // Get the provider first to capture its name
        final provider =
            await getConfigById(providerId) as AiConfigInferenceProvider?;
        final providerName = provider?.name ?? 'Unknown Provider';

        // Get all models to find those associated with this provider
        final allModels = await getConfigsByType(AiConfigType.model);
        final associatedModels = allModels
            .whereType<AiConfigModel>()
            .where((model) => model.inferenceProviderId == providerId)
            .toList();

        // Delete all associated models with detailed error tracking
        for (final model in associatedModels) {
          try {
            await deleteConfig(model.id, fromSync: fromSync);
          } catch (e) {
            // Re-throw to trigger transaction rollback
            rethrow;
          }
        }

        // Delete the provider itself
        try {
          await deleteConfig(providerId, fromSync: fromSync);
        } catch (e) {
          throw Exception('Failed to delete provider $providerId: $e');
        }

        return CascadeDeletionResult(
          deletedModels: associatedModels,
          providerName: providerName,
        );
      } catch (error, stackTrace) {
        if (getIt.isRegistered<LoggingService>()) {
          getIt<LoggingService>().captureException(
            error,
            domain: 'AiConfigRepository',
            subDomain: 'deleteInferenceProviderWithModels',
            stackTrace: stackTrace,
          );
        }
        rethrow; // Re-throw to let the caller handle the error
      }
    });
  }

  /// Get an AI configuration by its ID
  Future<AiConfig?> getConfigById(String id) async {
    if (_configByIdCache.containsKey(id)) {
      return _configByIdCache[id];
    }

    final inFlight = _configByIdInFlight[id];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _db
        .getConfigById(id)
        .then((config) {
          _configByIdCache[id] = config;
          if (config != null) {
            _cacheConfigInTypeList(config);
          }
          return config;
        })
        .whenComplete(() {
          _configByIdInFlight.remove(id);
        });

    _configByIdInFlight[id] = future;
    return future;
  }

  /// Returns cached AI configurations of a specific type, coalescing
  /// overlapping reads against the same database query.
  Future<List<AiConfig>> getConfigsByType(AiConfigType type) async {
    final cached = _configsByTypeCache[type];
    if (cached != null) {
      return cached;
    }

    final inFlight = _configsByTypeInFlight[type];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _db
        .getConfigsByType(type.name)
        .then(_decodeDbEntities)
        .then((configs) {
          _setConfigsByTypeCache(type, configs);
          return configs;
        })
        .whenComplete(() {
          _configsByTypeInFlight.remove(type);
        });

    _configsByTypeInFlight[type] = future;
    return future;
  }

  /// Streams all AI configurations of a specific type while keeping the
  /// repository cache in sync with the latest emitted snapshot.
  Stream<List<AiConfig>> watchConfigsByType(AiConfigType type) {
    return _db.watchConfigsByType(type.name).map(_decodeDbEntities).map((
      configs,
    ) {
      _setConfigsByTypeCache(type, configs);
      return configs;
    });
  }

  /// Returns all inference profiles.
  Future<List<AiConfigInferenceProfile>> getProfiles() async {
    final configs = await getConfigsByType(AiConfigType.inferenceProfile);
    return configs.whereType<AiConfigInferenceProfile>().toList();
  }

  /// Streams all inference profiles.
  Stream<List<AiConfigInferenceProfile>> watchProfiles() {
    return watchConfigsByType(AiConfigType.inferenceProfile).map(
      (configs) => configs.whereType<AiConfigInferenceProfile>().toList(),
    );
  }

  /// Resolves the base URL of the first configured Ollama provider.
  ///
  /// Returns `null` if no Ollama provider is configured.
  Future<String?> resolveOllamaBaseUrl() async {
    final providers = await getConfigsByType(AiConfigType.inferenceProvider);
    final ollamaProvider = providers
        .whereType<AiConfigInferenceProvider>()
        .where(
          (p) => p.inferenceProviderType == InferenceProviderType.ollama,
        )
        .firstOrNull;
    return ollamaProvider?.baseUrl;
  }

  /// Helper method to decode JSON
  Map<String, dynamic> _jsonDecode(String serialized) {
    final map = Map<String, dynamic>.from(
      const JsonDecoder().convert(serialized) as Map,
    );

    // Harden parsing for provider type: normalize known aliases and
    // default to OpenAI-compatible when unknown.
    final dynamic rawType = map['inferenceProviderType'];
    if (rawType is String) {
      map['inferenceProviderType'] = normalizeProviderType(rawType);
    }
    return map;
  }

  List<AiConfig> _decodeDbEntities(List<AiConfigDbEntity> entities) {
    return entities
        .map(
          (entity) => AiConfig.fromJson(
            Map<String, dynamic>.from(_jsonDecode(entity.serialized)),
          ),
        )
        .toList(growable: false);
  }

  void _setConfigsByTypeCache(AiConfigType type, List<AiConfig> configs) {
    final previousIds =
        _configsByTypeCache[type]?.map((config) => config.id).toSet() ??
        const <String>{};
    final nextIds = configs.map((config) => config.id).toSet();

    for (final removedId in previousIds.difference(nextIds)) {
      _configByIdCache.remove(removedId);
      _configByIdInFlight.remove(removedId);
    }

    final cachedConfigs = List<AiConfig>.unmodifiable(configs);
    _configsByTypeCache[type] = cachedConfigs;
    for (final config in cachedConfigs) {
      _configByIdCache[config.id] = config;
    }
  }

  void _storeConfig(AiConfig config) {
    final type = _typeForConfig(config);
    _configByIdCache[config.id] = config;
    _configByIdInFlight.remove(config.id);
    _configsByTypeCache.remove(type);
    _configsByTypeInFlight.remove(type);
  }

  void _invalidateConfig(String id) {
    final cached = _configByIdCache.remove(id);
    _configByIdInFlight.remove(id);

    if (cached != null) {
      final type = _typeForConfig(cached);
      _configsByTypeCache.remove(type);
      _configsByTypeInFlight.remove(type);
      return;
    }

    _configsByTypeCache.clear();
    _configsByTypeInFlight.clear();
  }

  void _cacheConfigInTypeList(AiConfig config) {
    final type = _typeForConfig(config);
    final cachedList = _configsByTypeCache[type];
    if (cachedList == null) {
      return;
    }

    final updatedList = [
      for (final existing in cachedList)
        if (existing.id == config.id) config else existing,
    ];
    final exists = updatedList.any((existing) => existing.id == config.id);
    if (!exists) {
      updatedList.add(config);
    }
    _setConfigsByTypeCache(type, updatedList);
  }

  AiConfigType _typeForConfig(AiConfig config) {
    return config.map(
      inferenceProvider: (_) => AiConfigType.inferenceProvider,
      model: (_) => AiConfigType.model,
      prompt: (_) => AiConfigType.prompt,
      inferenceProfile: (_) => AiConfigType.inferenceProfile,
    );
  }
}
