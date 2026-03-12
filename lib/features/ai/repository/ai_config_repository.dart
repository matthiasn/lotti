import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
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
  final StreamController<List<AiConfig>> _allConfigsController =
      StreamController<List<AiConfig>>.broadcast(sync: true);
  List<AiConfig> _allConfigsSnapshot = const <AiConfig>[];
  Future<void>? _allConfigsBootstrap;
  StreamSubscription<List<AiConfigDbEntity>>? _allConfigsSubscription;
  bool _allConfigsLoaded = false;

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

    if (_allConfigsLoaded) {
      return null;
    }

    final inFlight = _configByIdInFlight[id];
    if (inFlight != null) {
      return inFlight;
    }

    late final Future<AiConfig?> future;
    future = _db
        .getConfigById(id)
        .then((config) {
          if (identical(_configByIdInFlight[id], future)) {
            _configByIdCache[id] = config;
            if (config != null) {
              _cacheConfigInTypeList(config);
            }
          }
          return config;
        })
        .whenComplete(() {
          if (identical(_configByIdInFlight[id], future)) {
            _configByIdInFlight.remove(id);
          }
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

    if (_allConfigsLoaded) {
      return const <AiConfig>[];
    }

    final inFlight = _configsByTypeInFlight[type];
    if (inFlight != null) {
      return inFlight;
    }

    late final Future<List<AiConfig>> future;
    future = _db
        .getConfigsByType(type.name)
        .then(_decodeDbEntities)
        .then((configs) {
          if (identical(_configsByTypeInFlight[type], future)) {
            _setConfigsByTypeCache(type, configs);
          }
          return configs;
        })
        .whenComplete(() {
          if (identical(_configsByTypeInFlight[type], future)) {
            _configsByTypeInFlight.remove(type);
          }
        });

    _configsByTypeInFlight[type] = future;
    return future;
  }

  /// Streams all AI configurations of a specific type while keeping the
  /// repository cache in sync with the latest emitted snapshot.
  Stream<List<AiConfig>> watchConfigsByType(AiConfigType type) {
    return Stream<List<AiConfig>>.multi((controller) {
      StreamSubscription<List<AiConfig>>? subscription;
      List<AiConfig>? lastEmitted;

      void emit(List<AiConfig> allConfigs) {
        final filtered = List<AiConfig>.unmodifiable(
          allConfigs
              .where((config) => _typeForConfig(config) == type)
              .toList(growable: false),
        );
        final previous = lastEmitted;
        if (previous != null &&
            const ListEquality<AiConfig>().equals(previous, filtered)) {
          return;
        }
        lastEmitted = filtered;
        controller.add(filtered);
      }

      subscription = _allConfigsController.stream.listen(
        emit,
        onError: controller.addError,
        onDone: controller.close,
      );

      final cached = _configsByTypeCache[type];
      if (cached != null) {
        emit(_allConfigsLoaded ? _allConfigsSnapshot : cached);
      }

      if (_allConfigsLoaded) {
        emit(_allConfigsSnapshot);
        _ensureWatchingAllConfigs();
      } else {
        Future<void>(() async {
          await _ensureAllConfigsLoaded();
          emit(_allConfigsSnapshot);
        });
      }

      controller.onCancel = () => subscription?.cancel();
    }, isBroadcast: true);
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

    if (_allConfigsLoaded) {
      final updatedSnapshot = [
        for (final existing in _allConfigsSnapshot)
          if (existing.id == config.id) config else existing,
      ];
      if (!updatedSnapshot.any((existing) => existing.id == config.id)) {
        updatedSnapshot.add(config);
      }
      updatedSnapshot.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _replaceAllConfigsSnapshot(updatedSnapshot);
      return;
    }

    _cacheConfigInTypeList(config);
  }

  void _invalidateConfig(String id) {
    final cached = _configByIdCache.remove(id);
    _configByIdInFlight.remove(id);

    if (cached != null) {
      final type = _typeForConfig(cached);
      _configsByTypeCache.remove(type);
      _configsByTypeInFlight.remove(type);
      if (_allConfigsLoaded) {
        _replaceAllConfigsSnapshot(
          _allConfigsSnapshot
              .where((config) => config.id != id)
              .toList(growable: false),
        );
        return;
      }
      return;
    }

    if (_allConfigsLoaded) {
      _replaceAllConfigsSnapshot(
        _allConfigsSnapshot
            .where((config) => config.id != id)
            .toList(growable: false),
      );
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

  Future<void> _ensureAllConfigsLoaded() {
    final existingBootstrap = _allConfigsBootstrap;
    if (existingBootstrap != null) {
      return existingBootstrap;
    }

    late final Future<void> future;
    future = _db
        .getAllConfigs()
        .then(_decodeDbEntities)
        .then(_replaceAllConfigsSnapshot)
        .then((_) => _ensureWatchingAllConfigs())
        .whenComplete(() {
          if (identical(_allConfigsBootstrap, future)) {
            if (_allConfigsLoaded) {
              _allConfigsBootstrap = Future<void>.value();
            } else {
              _allConfigsBootstrap = null;
            }
          }
        });

    _allConfigsBootstrap = future;
    return future;
  }

  void _ensureWatchingAllConfigs() {
    _allConfigsSubscription ??= _db.watchAllConfigs().listen(
      (entities) {
        _replaceAllConfigsSnapshot(_decodeDbEntities(entities));
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_allConfigsController.isClosed) {
          _allConfigsController.addError(error, stackTrace);
        }
      },
    );
  }

  void _replaceAllConfigsSnapshot(List<AiConfig> configs) {
    final nextSnapshot = List<AiConfig>.unmodifiable(configs);

    _allConfigsLoaded = true;

    if (const ListEquality<AiConfig>().equals(
      _allConfigsSnapshot,
      nextSnapshot,
    )) {
      return;
    }

    _allConfigsSnapshot = nextSnapshot;
    _configByIdCache
      ..clear()
      ..addEntries(nextSnapshot.map((config) => MapEntry(config.id, config)));
    _configsByTypeCache
      ..clear()
      ..addEntries(
        AiConfigType.values.map(
          (type) => MapEntry(
            type,
            List<AiConfig>.unmodifiable(
              nextSnapshot
                  .where((config) => _typeForConfig(config) == type)
                  .toList(growable: false),
            ),
          ),
        ),
      );
    _emitAllConfigs();
  }

  void _emitAllConfigs() {
    if (!_allConfigsController.isClosed) {
      _allConfigsController.add(_allConfigsSnapshot);
    }
  }

  Future<void> close() async {
    await _allConfigsSubscription?.cancel();
    await _allConfigsController.close();
  }

  AiConfigType _typeForConfig(AiConfig config) {
    return config.map(
      inferenceProvider: (_) => AiConfigType.inferenceProvider,
      model: (_) => AiConfigType.model,
      prompt: (_) => AiConfigType.prompt,
      inferenceProfile: (_) => AiConfigType.inferenceProfile,
      skill: (_) => AiConfigType.skill,
    );
  }
}
