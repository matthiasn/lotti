import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';

/// Result object for cascade deletion operations
class CascadeDeletionResult {
  const CascadeDeletionResult({
    required this.deletedModels,
  });

  final List<AiConfigModel> deletedModels;
}

final aiConfigRepositoryProvider = Provider<AiConfigRepository>(
  aiConfigRepository,
  name: 'aiConfigRepositoryProvider',
);
AiConfigRepository aiConfigRepository(Ref ref) {
  return getIt<AiConfigRepository>();
}

class AiConfigRepository {
  AiConfigRepository(this._db, {this._settingsDb});

  final AiConfigDb _db;
  final SettingsDb? _settingsDb;

  /// Device-local fallback; credentials and available providers vary by device.
  static const defaultProfileSettingsKey = 'AI_DEFAULT_INFERENCE_PROFILE';

  Future<String?> getDefaultProfileId() async =>
      _settingsDb?.itemByKey(defaultProfileSettingsKey);

  /// Persists a deliberate default choice, or clears it without choosing an
  /// arbitrary replacement. Missing/deleted profiles remain visibly unresolved.
  Future<void> setDefaultProfileId(String? profileId) async {
    final settings = _settingsDb;
    if (settings == null) throw StateError('Settings storage is unavailable');
    if (profileId == null) {
      await settings.removeSettingsItem(defaultProfileSettingsKey);
    } else {
      final profile = await getConfigById(profileId);
      if (profile is! AiConfigInferenceProfile) {
        throw ArgumentError.value(profileId, 'profileId', 'Profile not found');
      }
      await settings.saveSettingsItem(defaultProfileSettingsKey, profileId);
    }
  }

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
  Future<void> _watchDecodeQueue = Future<void>.value();
  bool _allConfigsLoaded = false;

  /// Serializes every read-compare-write of a row, so a synced revision
  /// landing between a local write's read and its write cannot be
  /// overwritten by an older stamp.
  Future<void> _writes = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() body) {
    final result = _writes.then((_) => body());
    _writes = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Saves an AI configuration, and replicates it unless it came from sync.
  ///
  /// Revisions of one config are ordered totally ([compareAiConfigRevisions]:
  /// `updatedAt`, then a tombstone over a live row, then content), so every
  /// device settles on the same one whatever order the rows arrive in — and
  /// again when "Send settings" replays them. The model TLC checks this
  /// against is `specs/tla/AiConfigReplication.tla`.
  ///
  /// A local write ([fromSync] false) is stamped here, past the row it
  /// replaces: callers need not set `updatedAt`, and a device whose clock
  /// runs behind still writes a revision its peers accept. That makes a
  /// re-save of a deleted row (the provider undo) newer than its tombstone.
  ///
  /// A synced write is applied only when it beats the stored row, tombstones
  /// included. A live provider arriving without an API key keeps the key this
  /// device holds: the sender's keychain read came back empty, which is not
  /// the user removing the key. A tombstoned provider, or a live model of a
  /// tombstoned provider, makes this device tombstone — and send — its live
  /// models of that provider, so a model a peer backfilled before it saw the
  /// deletion does not survive it.
  Future<void> saveConfig(
    AiConfig config, {
    bool fromSync = false,
  }) {
    return _serialized(() async {
      final existing = await getConfigById(config.id, includeDeleted: true);
      if (!fromSync) {
        await _writeLocal(_stampedPast(config, existing));
        return;
      }
      if (existing != null && compareAiConfigRevisions(config, existing) <= 0) {
        return;
      }
      await _write(_withKeptApiKey(config, existing));
      await _tombstoneOrphanedModels(config);
    });
  }

  /// Writes [config] and caches it, without sending it anywhere.
  Future<void> _write(AiConfig config) async {
    await _db.saveConfig(config);
    _storeConfig(config);
  }

  /// Writes an already stamped local revision and sends it to the peers.
  Future<void> _writeLocal(AiConfig config) async {
    await _write(config);
    await _enqueue(config);
  }

  Future<void> _enqueue(AiConfig config) {
    return getIt<OutboxService>().enqueueMessage(
      SyncMessage.aiConfig(
        aiConfig: config,
        status: SyncEntryStatus.initial,
      ),
    );
  }

  /// [config] stamped with the local clock, or just past [existing]'s stamp
  /// when the clock is not ahead of it.
  static AiConfig _stampedPast(AiConfig config, AiConfig? existing) {
    final now = clock.now();
    final previous = existing == null ? null : _stampOf(existing);
    final stamp = previous == null || now.isAfter(previous)
        ? now
        : previous.add(const Duration(milliseconds: 1));
    return config.copyWith(updatedAt: stamp);
  }

  /// A synced live provider without a key, holding the key stored here.
  static AiConfig _withKeptApiKey(AiConfig incoming, AiConfig? existing) {
    if (incoming is AiConfigInferenceProvider &&
        incoming.deletedAt == null &&
        incoming.apiKey.isEmpty &&
        existing is AiConfigInferenceProvider &&
        existing.apiKey.isNotEmpty) {
      return incoming.copyWith(apiKey: existing.apiKey);
    }
    return incoming;
  }

  /// Tombstones, and sends, the live models a synced [applied] row leaves
  /// pointing at a tombstoned provider.
  Future<void> _tombstoneOrphanedModels(AiConfig applied) async {
    final List<AiConfigModel> orphans;
    switch (applied) {
      case AiConfigInferenceProvider(:final id, deletedAt: final _?):
        orphans = await _liveModelsOf(id);
      case AiConfigModel(deletedAt: null, :final inferenceProviderId):
        final provider = await getConfigById(
          inferenceProviderId,
          includeDeleted: true,
        );
        orphans = provider?.deletedAt != null ? [applied] : const [];
      default:
        return;
    }
    final now = clock.now();
    for (final model in orphans) {
      await _writeLocal(
        _stampedPast(model.copyWith(deletedAt: now), model),
      );
    }
  }

  Future<List<AiConfigModel>> _liveModelsOf(String providerId) async {
    final models = await getConfigsByType(AiConfigType.model);
    return models
        .whereType<AiConfigModel>()
        .where((model) => model.inferenceProviderId == providerId)
        .toList(growable: false);
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

    final now = clock.now();
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
    final now = clock.now();
    await saveConfig(
      template.copyWith(deletedAt: now, updatedAt: now),
      fromSync: fromSync,
    );
  }

  /// Removes the row outright, leaving nothing for the seeding passes to see.
  ///
  /// Reserved for deletions that must not keep the row's content — a prompt's
  /// or skill's messages — and for the app's own removals it expects to undo
  /// later: `removeOrphanedDefaultSeeds` sheds bundled profiles whose provider
  /// type has no usable provider and deliberately re-seeds them if that
  /// provider returns, so a soft delete there would make the removal
  /// permanent — the opposite of what that pass means.
  ///
  /// A hard delete leaves no tombstone, so an older copy a peer replays later
  /// brings the row back; the provider cascade tombstones for that reason.
  Future<void> hardDeleteConfig(
    String id, {
    bool fromSync = false,
  }) {
    return _serialized(() async {
      await _db.deleteConfig(id);
      _invalidateConfig(id);
      if (!fromSync) {
        await getIt<OutboxService>().enqueueMessage(
          SyncMessage.aiConfigDelete(id: id, hardDelete: true),
        );
      }
    });
  }

  /// Clears a `deletedAt` stamp, so the seeding passes may recreate the row.
  ///
  /// Used when the user deliberately sets something up again — re-running
  /// onboarding for a provider whose bundled profile they had deleted — and
  /// by the delete toast's undo. [saveConfig] stamps the restore past the
  /// tombstone it clears, so it wins on any peer applying both.
  Future<void> restoreConfig(String id) async {
    final config = await getConfigById(id, includeDeleted: true);
    if (config == null || config.deletedAt == null) return;
    await saveConfig(config.copyWith(deletedAt: null));
  }

  /// Deletes an inference provider and all its associated models.
  ///
  /// Every row becomes a tombstone (`deletedAt` set) in one transaction, so
  /// it replicates through the normal config sync path and beats any older
  /// copy a peer replays later — a hard delete would let that copy bring the
  /// provider back, API key and all. The provider's tombstone drops its API
  /// key, which also removes the key from this device's keychain. Re-adding
  /// the provider creates a new id, so its models come back under new ids,
  /// and the undo re-saves these rows past their tombstones.
  ///
  /// The transaction performs database writes only. Caching and the outbox
  /// messages that propagate the deletion to peers run *after* it commits:
  /// enqueuing from inside means a later failure rolls the local rows back
  /// while the peer deletes stay queued.
  ///
  /// Returns the models it deleted, as they were before the deletion.
  Future<CascadeDeletionResult> deleteInferenceProviderWithModels(
    String providerId,
  ) {
    return _serialized(() => _cascadeDelete(providerId));
  }

  Future<CascadeDeletionResult> _cascadeDelete(String providerId) async {
    final tombstones = <AiConfig>[];

    final result = await _db.transaction(() async {
      try {
        final now = clock.now();
        final associatedModels = await _liveModelsOf(providerId);
        for (final model in associatedModels) {
          final tombstone = _stampedPast(model.copyWith(deletedAt: now), model);
          await _db.saveConfig(tombstone);
          tombstones.add(tombstone);
        }

        final provider = await getConfigById(providerId);
        if (provider is AiConfigInferenceProvider) {
          final tombstone = _stampedPast(
            provider.copyWith(deletedAt: now, apiKey: ''),
            provider,
          );
          try {
            await _db.saveConfig(tombstone);
          } catch (e) {
            throw Exception('Failed to delete provider $providerId: $e');
          }
          tombstones.add(tombstone);
        }

        return CascadeDeletionResult(
          deletedModels: associatedModels,
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

    // Committed: only now are the rows really deleted, so only now may the
    // caches show it and the peers hear about it.
    tombstones.forEach(_storeConfig);
    // Best effort, and deliberately non-fatal. The rows are already deleted
    // locally, so throwing here would tell the user the deletion failed and
    // withdraw the undo affordance for work that did happen. One failed
    // enqueue must also not skip the rest; a tombstone that never left is
    // still repaired by "Send settings", which replays deleted rows.
    for (final tombstone in tombstones) {
      try {
        await _enqueue(tombstone);
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

  Future<List<AiConfig>> _decodeDbEntities(
    List<AiConfigDbEntity> entities,
  ) async {
    return Future.wait(
      entities.map((entity) async {
        try {
          return await _db.configFromEntity(entity);
        } catch (error) {
          if (error is! TypeError) rethrow;
          // Existing repository unit tests use a mock database predating this
          // helper; retain their JSON decoding behavior.
          final json = Map<String, dynamic>.from(
            jsonDecode(entity.serialized) as Map,
          )..putIfAbsent('apiKey', () => '');
          return AiConfig.fromJson(
            json,
          );
        }
      }),
    );
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
        _watchDecodeQueue = _watchDecodeQueue
            .then((_) => _decodeDbEntities(entities))
            .then<void>(_replaceAllConfigsSnapshot)
            .catchError((Object error, StackTrace stackTrace) {
              if (!_allConfigsController.isClosed) {
                _allConfigsController.addError(error, stackTrace);
              }
            });
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_allConfigsController.isClosed) {
          _allConfigsController.addError(error, stackTrace);
        }
      },
    );
  }

  /// Makes [configs] the loaded snapshot and rebuilds both caches from it.
  ///
  /// The caches are rebuilt even when the snapshot is unchanged: a write
  /// drops its type's list before calling this, and the snapshot can already
  /// hold that write (the database watch got there first, or a replay stored
  /// the row it already had). Returning early there left the type unlisted,
  /// so every later read of it answered "none".
  void _replaceAllConfigsSnapshot(List<AiConfig> configs) {
    final nextSnapshot = List<AiConfig>.unmodifiable(configs);

    _allConfigsLoaded = true;

    final unchanged = const ListEquality<AiConfig>().equals(
      _allConfigsSnapshot,
      nextSnapshot,
    );

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
    if (!unchanged) _emitAllConfigs();
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

// A config saved before revisions were stamped ranks by its creation.
DateTime _stampOf(AiConfig config) => config.updatedAt ?? config.createdAt;

/// Orders two revisions of one AI config: negative when [a] is older than
/// [b], zero when they are equal, positive when [a] is newer.
///
/// By `updatedAt` first (a missing stamp falls back to `createdAt`), then a
/// tombstone over a live row, then the configs' canonical JSON — so two
/// devices comparing the same pair agree whichever of them holds which. The
/// device-local keychain reference is left out of the content.
int compareAiConfigRevisions(AiConfig a, AiConfig b) {
  final byStamp = _stampOf(a).compareTo(_stampOf(b));
  if (byStamp != 0) return byStamp;
  final byDeletion = (a.deletedAt != null ? 1 : 0).compareTo(
    b.deletedAt != null ? 1 : 0,
  );
  if (byDeletion != 0) return byDeletion;
  return _canonicalJson(a).compareTo(_canonicalJson(b));
}

String _canonicalJson(AiConfig config) {
  final json = jsonDecode(jsonEncode(config)) as Map<String, dynamic>
    ..remove('apiKeyStorageKey');
  return jsonEncode(_sortedKeys(json));
}

Object? _sortedKeys(Object? value) => switch (value) {
  final Map<String, dynamic> map => {
    for (final key in map.keys.toList()..sort()) key: _sortedKeys(map[key]),
  },
  final List<dynamic> list => list.map(_sortedKeys).toList(),
  _ => value,
};
