import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';
import 'package:lotti/features/ai/util/provider_type_utils.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';

/// Result object for cascade deletion operations
class CascadeDeletionResult {
  const CascadeDeletionResult({
    required this.deletedModels,
    required this.providerName,
  });

  final List<AiConfigModel> deletedModels;
  final String providerName;
}

final aiConfigRepositoryProvider = Provider<AiConfigRepository>(
  aiConfigRepository,
  name: 'aiConfigRepositoryProvider',
);
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
    // Only inbound writes are screened: a local edit of a deleted row is the
    // user acting on this device, and `restoreConfig` is the deliberate way
    // back. A peer replaying its still-active copy is not.
    if (fromSync && await _isStaleReplayOfTombstone(config)) {
      return;
    }
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

  /// Soft-deletes an AI configuration: the row stays and gains a `deletedAt`
  /// stamp, and the change replicates through the normal config sync path.
  ///
  /// Deletion has to leave a trace the seeding passes can see. `seedDefaults`
  /// writes any bundled template whose row is missing, and `backfillNewModels`
  /// recreates any known model a configured provider lacks — both at startup
  /// and again after a provider is saved — so a hard delete is undone within
  /// the session, and on a synced pair each peer re-seeds a default it never
  /// saw removed. Keeping the row makes "deleted" distinguishable from
  /// "missing", in the same database and the same write, and it converges
  /// across devices because it rides the existing `SyncMessage.aiConfig`.
  ///
  /// Reads hide these rows by default; the seeding passes ask for them.
  ///
  /// This mirrors how the journal domain deletes synced entities — see
  /// `CategoryRepository.deleteCategory`.
  Future<void> deleteConfig(
    String id, {
    bool fromSync = false,
  }) async {
    final config = await getConfigById(id, includeDeleted: true);
    if (config == null) {
      // A legacy delete can arrive before this device has the row. Bundled
      // profiles are reconstructible from their template, so write the
      // tombstone anyway — otherwise seeding recreates exactly what the peer's
      // user deleted. Nothing else is seeded by id, so nothing else can be
      // resurrected this way.
      await _tombstoneUnseenSeed(id, fromSync: fromSync);
      return;
    }
    if (config.deletedAt != null) return;

    // Only profiles and models are ever re-created by the seeding passes, so
    // only they need the row kept as a tombstone. Retaining anything else
    // would keep content the user asked to remove — a deleted prompt's system
    // and user messages, say — and replicate it to peers, which the delete
    // dialog explicitly promises not to do.
    if (!_isSeededType(config)) {
      await hardDeleteConfig(id, fromSync: fromSync);
      return;
    }

    final now = DateTime.now();
    await saveConfig(
      config.copyWith(deletedAt: now, updatedAt: now),
      fromSync: fromSync,
    );
  }

  /// Whether a seeding pass could recreate [config] if its row went missing.
  static bool _isSeededType(AiConfig config) => config.map(
    inferenceProvider: (_) => false,
    model: (_) => true,
    prompt: (_) => false,
    inferenceProfile: (_) => true,
    skill: (_) => false,
  );

  /// Writes a tombstone for a bundled profile this device has not seeded yet.
  Future<void> _tombstoneUnseenSeed(String id, {required bool fromSync}) async {
    final template = ProfileSeedingService.defaultProfiles
        .where((profile) => profile.id == id)
        .firstOrNull;
    if (template == null) return;
    final now = DateTime.now();
    await saveConfig(
      template.copyWith(deletedAt: now, updatedAt: now),
      fromSync: fromSync,
    );
  }

  /// Removes the row outright, leaving nothing for the seeding passes to see.
  ///
  /// Reserved for deletions the app performs on the user's behalf and expects
  /// to undo later: `removeOrphanedDefaultSeeds` sheds bundled profiles whose
  /// provider type has no usable provider and deliberately re-seeds them if
  /// that provider returns, so a soft delete there would make the removal
  /// permanent — the opposite of what that pass means.
  Future<void> hardDeleteConfig(
    String id, {
    bool fromSync = false,
  }) async {
    await _db.deleteConfig(id);
    _invalidateConfig(id);
    if (!fromSync) {
      await getIt<OutboxService>().enqueueMessage(
        SyncMessage.aiConfigDelete(id: id, hardDelete: true),
      );
    }
  }

  /// Clears a `deletedAt` stamp, so the seeding passes may recreate the row.
  ///
  /// Used when the user deliberately sets something up again — re-running
  /// onboarding for a provider whose bundled profile they had deleted.
  Future<void> restoreConfig(String id) async {
    final config = await getConfigById(id, includeDeleted: true);
    if (config == null || config.deletedAt == null) return;
    // Stamped so this restore is newer than the tombstone it clears, and
    // therefore wins on any peer applying both.
    await saveConfig(
      config.copyWith(deletedAt: null, updatedAt: DateTime.now()),
    );
  }

  /// Whether an incoming synced [incoming] row would resurrect a local
  /// tombstone without being a deliberate, newer restore.
  ///
  /// A peer that missed a deletion keeps its row active and can replay it —
  /// through the maintenance pass or a queued edit — which would otherwise
  /// upsert `deletedAt: null` over the tombstone. Deletions and restores both
  /// stamp `updatedAt`, so an active row that is not strictly newer than the
  /// local tombstone is a stale replay and is dropped.
  Future<bool> _isStaleReplayOfTombstone(AiConfig incoming) async {
    if (incoming.deletedAt != null) return false;
    final local = await getConfigById(incoming.id, includeDeleted: true);
    final tombstonedAt = local?.deletedAt;
    if (tombstonedAt == null) return false;
    final incomingUpdatedAt = incoming.updatedAt;
    if (incomingUpdatedAt == null) return true;
    final localUpdatedAt = local!.updatedAt ?? tombstonedAt;
    return !incomingUpdatedAt.isAfter(localUpdatedAt);
  }

  /// Delete an inference provider and all its associated models.
  ///
  /// This method performs cascade deletion within a transaction to ensure
  /// atomicity:
  /// 1. Fetches all models associated with the provider
  /// 2. Deletes each model
  /// 3. Deletes the provider itself
  ///
  /// If any deletion fails, the entire transaction is rolled back to maintain
  /// data integrity and prevent partial deletions.
  ///
  /// The transaction performs database writes only. Cache invalidation and the
  /// outbox messages that propagate the deletion to peers run *after* it
  /// commits: enqueuing from inside means a later failure rolls the local rows
  /// back while the peer deletes stay queued, hard-deleting rows on other
  /// devices that still exist here.
  ///
  /// Returns detailed information about the deletion operation.
  Future<CascadeDeletionResult> deleteInferenceProviderWithModels(
    String providerId, {
    bool fromSync = false,
  }) async {
    final deletedIds = <String>[];

    final result = await _db.transaction(() async {
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

        // Hard deletes: re-adding this provider must bring its models back, so
        // the cascade must not leave tombstones behind.
        for (final model in associatedModels) {
          await _db.deleteConfig(model.id);
          deletedIds.add(model.id);
        }

        // Delete the provider itself. Nothing seeds providers, so there is
        // no tombstone to keep.
        try {
          await _db.deleteConfig(providerId);
          deletedIds.add(providerId);
        } catch (e) {
          throw Exception('Failed to delete provider $providerId: $e');
        }

        return CascadeDeletionResult(
          deletedModels: associatedModels,
          providerName: providerName,
        );
      } catch (error, stackTrace) {
        if (getIt.isRegistered<DomainLogger>()) {
          getIt<DomainLogger>().error(
            LogDomain.ai,
            error,
            stackTrace: stackTrace,
            subDomain: 'deleteInferenceProviderWithModels',
          );
        }
        rethrow; // Re-throw to let the caller handle the error
      }
    });

    // Committed: only now are the rows really gone, so only now may the caches
    // drop them and the peers hear about it.
    deletedIds.forEach(_invalidateConfig);
    if (!fromSync) {
      // Best effort, and deliberately non-fatal. The rows are already gone
      // locally, so throwing here would tell the user the deletion failed and
      // withdraw the undo affordance for work that did happen. One failed
      // enqueue must also not skip the rest — a hard delete leaves no row for
      // the maintenance pass to replay, so every id we can queue, we queue.
      for (final id in deletedIds) {
        try {
          await getIt<OutboxService>().enqueueMessage(
            SyncMessage.aiConfigDelete(id: id, hardDelete: true),
          );
        } catch (error, stackTrace) {
          if (getIt.isRegistered<DomainLogger>()) {
            getIt<DomainLogger>().error(
              LogDomain.ai,
              error,
              stackTrace: stackTrace,
              subDomain: 'deleteInferenceProviderWithModels',
            );
          }
        }
      }
    }

    return result;
  }

  /// Get an AI configuration by its ID.
  ///
  /// Soft-deleted rows are hidden unless [includeDeleted] is set. The seeding
  /// passes set it: they need "deleted" to read as *present* so they skip
  /// recreating it, while every user-facing surface must not see it.
  Future<AiConfig?> getConfigById(
    String id, {
    bool includeDeleted = false,
  }) async {
    final config = await _getConfigByIdIncludingDeleted(id);
    if (config == null) return null;
    if (!includeDeleted && config.deletedAt != null) return null;
    return config;
  }

  /// The cached/coalesced read. Caches every row, deleted or not, so both
  /// callers above are served from one query.
  Future<AiConfig?> _getConfigByIdIncludingDeleted(String id) async {
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
  ///
  /// Soft-deleted rows are hidden unless [includeDeleted] is set — see
  /// [getConfigById].
  Future<List<AiConfig>> getConfigsByType(
    AiConfigType type, {
    bool includeDeleted = false,
  }) async {
    final configs = await _getConfigsByTypeIncludingDeleted(type);
    if (includeDeleted) return configs;
    return configs
        .where((config) => config.deletedAt == null)
        .toList(growable: false);
  }

  Future<List<AiConfig>> _getConfigsByTypeIncludingDeleted(
    AiConfigType type,
  ) async {
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
              .where(
                (config) =>
                    _typeForConfig(config) == type && config.deletedAt == null,
              )
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
    await _db.close();
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
