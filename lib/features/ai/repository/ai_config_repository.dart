import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/repository/ai_config_sync_ledger.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/outbox_service.dart';

/// What "Send settings" re-sends for one AI configuration id: the stored
/// row (a tombstone included) with the stamp its version holds, or, with no
/// [config], the hard deletion that [stamp] alone records.
class AiConfigResend {
  const AiConfigResend({required this.id, this.config, this.stamp});

  final String id;
  final AiConfig? config;
  final int? stamp;

  /// The message carrying this state, stamped so a peer holding a newer
  /// version drops it (ADR 0094).
  SyncMessage toSyncMessage() {
    final config = this.config;
    if (config != null) {
      return SyncMessage.aiConfig(
        aiConfig: config,
        status: SyncEntryStatus.update,
        versionStamp: stamp,
      );
    }
    return SyncMessage.aiConfigDelete(
      id: id,
      hardDelete: true,
      versionStamp: stamp,
    );
  }
}

/// Result object for cascade deletion operations
class CascadeDeletionResult {
  const CascadeDeletionResult({
    required this.deletedModels,
  });

  final List<AiConfigModel> deletedModels;
}

/// The shared [AiConfigRepository]. The app overrides it per service
/// generation in `buildProviderOverrides`; the getIt fallback below only
/// serves scopes built without those overrides.
final aiConfigRepositoryProvider = Provider<AiConfigRepository>(
  aiConfigRepository,
  name: 'aiConfigRepositoryProvider',
);
AiConfigRepository aiConfigRepository(Ref ref) {
  return getIt<AiConfigRepository>();
}

class AiConfigRepository {
  AiConfigRepository(
    this._db, {
    SettingsDb? settingsDb,
    this.retryDelay = const Duration(minutes: 1),
  }) : _settingsDb = settingsDb,
       _ledger = settingsDb == null ? null : AiConfigSyncLedger(settingsDb);

  final AiConfigDb _db;
  final SettingsDb? _settingsDb;

  /// The ids whose latest write the outbox has not accepted yet; null only in
  /// a repository built without settings storage, which then sends
  /// best-effort as before.
  final AiConfigSyncLedger? _ledger;

  /// How long after a failed enqueue the owed ids are tried again.
  final Duration retryDelay;

  Timer? _retryTimer;
  bool _disposed = false;

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

  /// The ids this device holds a hard deletion of (a stamp with no row),
  /// which the reads need to tell a deleted provider from one never seen;
  /// null until first read from the database.
  Set<String>? _hardDeletedIds;

  Future<Set<String>> _loadHardDeletedIds() async =>
      _hardDeletedIds ??= (await _db.hardDeletionStamps()).keys.toSet();

  /// Save or update an AI configuration.
  ///
  /// A local save stamps a new version and, unless [fromSync] is set, sends
  /// it with that stamp. A received version passes the [versionStamp] its
  /// sender gave it and is written only if it is newer than the version held
  /// here, so a late or replayed copy never overwrites a newer one (ADR
  /// 0094). A copy from a sender that predates stamps passes none; it is
  /// ordered by [fallbackStamp] (the Matrix server timestamp) instead, after
  /// the tombstone screen that guarded such copies before. [fromSync] with
  /// neither is a local write that is not sent.
  ///
  /// A received live provider without an API key keeps the key this device
  /// holds: the sender's keychain read came back empty, which is not the user
  /// removing the key. The user removing it is said explicitly — the form
  /// sets [AiConfigInferenceProvider.apiKeyCleared] when a key that was there
  /// is emptied — and only then is the key removed here too. Every received
  /// provider or model version, applied or not, then runs the orphan cleanup
  /// ([_deleteOrphanedModels]), so a model a peer created before it heard of
  /// its provider's deletion does not outlive it.
  ///
  /// A local write owes its message to the peers until the outbox accepts it
  /// ([_send]): the write is durable before the message is staged, so a
  /// failed enqueue, or a crash in between, leaves the id in the
  /// [AiConfigSyncLedger] for [flushPending].
  ///
  /// A model created on this device takes its provider's stamp rather than
  /// the clock: it belongs to the provider as it was, so a deletion of the
  /// provider that outranks that version outranks the model too, whatever
  /// the clocks say. The model TLC checks all this against is
  /// `specs/tla/AiConfigReplication.tla`.
  Future<void> saveConfig(
    AiConfig config, {
    bool fromSync = false,
    int? versionStamp,
    int? fallbackStamp,
  }) async {
    // Only unstamped inbound writes are screened: a local edit of a deleted
    // row is the user acting on this device, and `restoreConfig` is the
    // deliberate way back. A peer replaying its still-active copy is not. A
    // stamped version needs no screen: its stamp already says whether it is
    // newer than the tombstone, and a restore's `updatedAt` can trail the
    // tombstone's when the restoring device's clock runs behind.
    if (fromSync &&
        versionStamp == null &&
        await _isStaleReplayOfTombstone(config)) {
      return;
    }
    final receivedStamp = versionStamp ?? fallbackStamp;
    if (fromSync && receivedStamp != null) {
      final received = _withKeptApiKey(
        config,
        await getConfigById(config.id, includeDeleted: true),
      );
      final applied = await _db.applyConfigVersion(
        received,
        stamp: receivedStamp,
      );
      if (applied) _storeConfig(received);
      switch (received) {
        case AiConfigInferenceProvider(:final id):
          await _deleteOrphanedModels(id);
        case AiConfigModel(:final inferenceProviderId):
          await _deleteOrphanedModels(inferenceProviderId);
        default:
      }
      return;
    }
    // A key that is there is not a cleared one: the marker is for this very
    // write and must not ride along on a later edit from the stored row.
    final written =
        config is AiConfigInferenceProvider &&
            config.apiKeyCleared &&
            config.apiKey.isNotEmpty
        ? config.copyWith(apiKeyCleared: false)
        : config;
    final stamp = await _saveLocal(written);
    _storeConfig(written);
    if (!fromSync) await _enqueue(written, stamp);
  }

  /// Writes a local version of [config] and returns its stamp: a model this
  /// device has never held a version of takes its live provider's stamp,
  /// anything else the next local stamp.
  Future<int> _saveLocal(AiConfig config) async {
    if (config is AiConfigModel && await _db.versionStamp(config.id) == null) {
      final provider = await getConfigById(config.inferenceProviderId);
      final providerStamp = provider == null
          ? null
          : await _db.versionStamp(provider.id);
      if (providerStamp != null &&
          await _db.applyConfigVersion(config, stamp: providerStamp)) {
        return providerStamp;
      }
    }
    return _db.saveConfig(config);
  }

  Future<void> _enqueue(AiConfig config, int stamp) => _send(
    config.id,
    SyncMessage.aiConfig(
      aiConfig: config,
      status: SyncEntryStatus.initial,
      versionStamp: stamp,
    ),
  );

  /// Stages [message], the latest write of [id], owing it until the outbox
  /// accepts the row.
  ///
  /// The write it follows has committed, so a failure is logged, never
  /// thrown: the id stays owed and [flushPending] sends what this device
  /// holds for it then. Without settings storage there is no ledger, and the
  /// failure is only logged, as `enqueueMessage` did.
  Future<void> _send(String id, SyncMessage message) async {
    final ledger = _ledger;
    try {
      await ledger?.owe(id);
      await getIt<OutboxService>().enqueueMessageOrThrow(message);
      await ledger?.settle(id);
    } catch (error, stackTrace) {
      _logError(error, stackTrace, subDomain: 'aiConfig.send');
      if (ledger != null) _scheduleRetry();
    }
  }

  /// Sends every write the ledger still owes: the stored row of each owed
  /// id with its stamp, or the hard deletion its stamp alone records. An id
  /// with neither is forgotten. Called at startup, by the retry timer and by
  /// "Send settings". On the first failure the rest stay owed and a retry is
  /// scheduled.
  Future<void> flushPending() async {
    final ledger = _ledger;
    if (ledger == null) return;
    try {
      for (final id in (await ledger.load()).toList()..sort()) {
        final message = await _owedMessage(id);
        if (message != null) {
          await getIt<OutboxService>().enqueueMessageOrThrow(message);
        }
        await ledger.settle(id);
      }
    } catch (error, stackTrace) {
      _logError(error, stackTrace, subDomain: 'aiConfig.flush');
      _scheduleRetry();
    }
  }

  /// The message carrying what this device holds for [id]: its row with its
  /// stamp, or the hard deletion the stamp alone records; null when the
  /// device holds neither (the orphaned-seed prune forgets both).
  Future<SyncMessage?> _owedMessage(String id) async {
    final stamp = await _db.versionStamp(id);
    if (stamp == null) return null;
    final config = await getConfigById(id, includeDeleted: true);
    if (config != null) {
      return SyncMessage.aiConfig(
        aiConfig: config,
        status: SyncEntryStatus.update,
        versionStamp: stamp,
      );
    }
    return SyncMessage.aiConfigDelete(
      id: id,
      hardDelete: true,
      versionStamp: stamp,
    );
  }

  void _scheduleRetry() {
    if (_disposed) return;
    // The flush never throws: a failure is logged and re-armed inside it.
    _retryTimer ??= Timer(retryDelay, () async {
      _retryTimer = null;
      await flushPending();
    });
  }

  /// Stops the retry timer.
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  void _logError(
    Object error,
    StackTrace stackTrace, {
    required String subDomain,
  }) {
    if (!getIt.isRegistered<DomainLogger>()) return;
    getIt<DomainLogger>().error(
      LogDomain.ai,
      error,
      stackTrace: stackTrace,
      subDomain: subDomain,
    );
  }

  /// A received live provider without a key, holding the key stored here —
  /// but only while it still points where that key was entered for, and
  /// only when the sender did not say the key was removed on purpose.
  ///
  /// A version that changes the provider's endpoint or kind arrives without
  /// this device's key, so a peer cannot redirect a stored key to a host of
  /// its choosing; the user enters the key again for the new endpoint.
  static AiConfig _withKeptApiKey(AiConfig incoming, AiConfig? existing) {
    if (incoming is AiConfigInferenceProvider &&
        incoming.deletedAt == null &&
        incoming.apiKey.isEmpty &&
        !incoming.apiKeyCleared &&
        existing is AiConfigInferenceProvider &&
        existing.apiKey.isNotEmpty &&
        incoming.inferenceProviderType == existing.inferenceProviderType &&
        _sameEndpoint(incoming.baseUrl, existing.baseUrl)) {
      return incoming.copyWith(apiKey: existing.apiKey);
    }
    return incoming;
  }

  /// Whether two base URLs name the same endpoint, ignoring surrounding space,
  /// trailing slashes and the case of the scheme and host.
  static bool _sameEndpoint(String a, String b) {
    String normalized(String url) {
      final trimmed = url.trim().replaceFirst(RegExp(r'/+$'), '');
      final uri = Uri.tryParse(trimmed);
      return uri == null ? trimmed : uri.normalizePath().toString();
    }

    return normalized(a) == normalized(b);
  }

  /// Deletes, and sends the deletion of, every live model of [providerId]
  /// once this device holds that provider's deletion.
  ///
  /// Only a model not newer than the deletion is an orphan. One stamped after
  /// it was written after the deletion — the provider undo restores the
  /// models and the provider as separate messages, and a peer may receive a
  /// model before its provider — so deleting it would defeat that write on
  /// every device.
  ///
  /// The deletion carries the provider deletion's stamp, not this device's
  /// clock, so every device that derives it records the same version, and a
  /// restore stamped past the provider's deletion always outranks it. Each
  /// deletion is stored, then sent owed ([_send]): a send that fails leaves
  /// the deletion recorded here and its id in the ledger for the next flush.
  Future<void> _deleteOrphanedModels(String providerId) async {
    final provider = await getConfigById(providerId, includeDeleted: true);
    if (provider != null && provider.deletedAt == null) return;
    final deletion = await _db.versionStamp(providerId);
    if (deletion == null) return;
    for (final model in await _liveModelsOf(providerId)) {
      final held = await _db.versionStamp(model.id);
      if (held != null && held > deletion) continue;
      if (await _db.applyConfigDeletion(model.id, stamp: deletion)) {
        _noteHardDeleted(model.id);
      }
      await _send(
        model.id,
        SyncMessage.aiConfigDelete(
          id: model.id,
          hardDelete: true,
          versionStamp: deletion,
        ),
      );
    }
  }

  /// The live models of [providerId], whether or not the provider is: the
  /// cleanup and the cascade read models under a deleted provider, which the
  /// user-facing reads hide.
  Future<List<AiConfigModel>> _liveModelsOf(String providerId) async {
    final models = await getConfigsByType(
      AiConfigType.model,
      includeDeleted: true,
    );
    return models
        .whereType<AiConfigModel>()
        .where(
          (model) =>
              model.inferenceProviderId == providerId &&
              model.deletedAt == null,
        )
        .toList(growable: false);
  }

  /// The stamp of the version held for [id], which a resend of the stored
  /// config must carry; see [AiConfigDb.versionStamp].
  Future<int?> versionStamp(String id) => _db.versionStamp(id);

  /// Every hard deletion this device holds, by id, with the stamp a resend of
  /// it must carry; see [AiConfigDb.hardDeletionStamps].
  Future<Map<String, int>> hardDeletionStamps() => _db.hardDeletionStamps();

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
  ///
  /// A received legacy deletion passes its [versionStamp] and is ordered like
  /// any received version.
  Future<void> deleteConfig(
    String id, {
    bool fromSync = false,
    int? versionStamp,
  }) async {
    final config = await getConfigById(id, includeDeleted: true);
    if (config == null) {
      // A legacy delete can arrive before this device has the row. Bundled
      // profiles are reconstructible from their template, so write the
      // tombstone anyway — otherwise seeding recreates exactly what the peer's
      // user deleted. Nothing else is seeded by id, so nothing else can be
      // resurrected this way.
      await _tombstoneUnseenSeed(
        id,
        fromSync: fromSync,
        versionStamp: versionStamp,
      );
      return;
    }
    if (config.deletedAt != null) return;

    // Only profiles and models are ever re-created by the seeding passes, so
    // only they need the row kept as a tombstone. Retaining anything else
    // would keep content the user asked to remove — a deleted prompt's system
    // and user messages, say — and replicate it to peers, which the delete
    // dialog explicitly promises not to do.
    if (!_isSeededType(config)) {
      await hardDeleteConfig(
        id,
        fromSync: fromSync,
        versionStamp: versionStamp,
      );
      return;
    }

    final now = DateTime.now();
    await saveConfig(
      config.copyWith(deletedAt: now, updatedAt: now),
      fromSync: fromSync,
      versionStamp: versionStamp,
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
  Future<void> _tombstoneUnseenSeed(
    String id, {
    required bool fromSync,
    required int? versionStamp,
  }) async {
    final template = ProfileSeedingService.defaultProfiles
        .where((profile) => profile.id == id)
        .firstOrNull;
    if (template == null) {
      // Nothing to tombstone, but a received deletion still takes its stamp,
      // so a copy of the config sent before it cannot create the row when it
      // lands later.
      if (fromSync && versionStamp != null) {
        await hardDeleteConfig(
          id,
          fromSync: true,
          versionStamp: versionStamp,
        );
      }
      return;
    }
    final now = DateTime.now();
    await saveConfig(
      template.copyWith(deletedAt: now, updatedAt: now),
      fromSync: fromSync,
      versionStamp: versionStamp,
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
  /// A local delete stamps the deletion and sends it with that stamp. A
  /// received one passes its [versionStamp] and is skipped when this device
  /// holds a newer version (ADR 0094); either way, a received deletion of a
  /// provider then deletes the models it leaves behind
  /// ([_deleteOrphanedModels]). [fromSync] without a stamp is that prune: it
  /// stays on this device, so the device also forgets the version it held
  /// and a peer's next copy of the config applies again.
  Future<void> hardDeleteConfig(
    String id, {
    bool fromSync = false,
    int? versionStamp,
  }) async {
    if (!fromSync) {
      final stamp = await _db.deleteConfig(id);
      _noteHardDeleted(id);
      await _send(
        id,
        SyncMessage.aiConfigDelete(
          id: id,
          hardDelete: true,
          versionStamp: stamp,
        ),
      );
      return;
    }
    if (versionStamp == null) {
      await _db.forgetConfig(id);
      _hardDeletedIds?.remove(id);
      _invalidateConfig(id);
      return;
    }
    if (await _db.applyConfigDeletion(id, stamp: versionStamp)) {
      _noteHardDeleted(id);
    }
    await _deleteOrphanedModels(id);
  }

  /// Drops [id] from the caches and remembers its hard deletion, which the
  /// model lists need to hide the models of a deleted provider.
  void _noteHardDeleted(String id) {
    _hardDeletedIds?.add(id);
    _invalidateConfig(id);
  }

  /// Clears a `deletedAt` stamp, so the seeding passes may recreate the row.
  ///
  /// Used when the user deliberately sets something up again — re-running
  /// onboarding for a provider whose bundled profile they had deleted — and
  /// by the delete toast's undo of a model or profile. A hard-deleted row
  /// (a prompt, a skill) has no stamp to clear; its undo re-saves it.
  Future<void> restoreConfig(String id) async {
    final config = await getConfigById(id, includeDeleted: true);
    if (config == null || config.deletedAt == null) return;
    // Its local stamp outranks the tombstone it clears, so it wins on any
    // peer applying both.
    await saveConfig(
      config.copyWith(deletedAt: null, updatedAt: DateTime.now()),
    );
  }

  /// Undoes [deleteInferenceProviderWithModels]: re-saves [provider] and
  /// [models] as they were before it, each stamped past its deletion.
  ///
  /// Each row travels as its own message, so a peer may receive a model
  /// before the provider, while it still holds the provider's deletion. It
  /// keeps the model only when the model is newer than that deletion (see
  /// [_deleteOrphanedModels]), so every model is stamped no earlier than the
  /// restored provider — itself past the provider's deletion, which a
  /// model's own deletion need not be when the provider's stamp ran ahead.
  Future<void> restoreProviderWithModels(
    AiConfigInferenceProvider provider,
    List<AiConfigModel> models,
  ) async {
    final providerStamp = await _db.saveConfig(provider);
    _storeConfig(provider);
    await _enqueue(provider, providerStamp);
    for (final model in models) {
      final stamp = await _db.saveConfig(model, notBefore: providerStamp);
      _storeConfig(model);
      await _enqueue(model, stamp);
    }
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
  /// data integrity and prevent partial deletions. Each deletion leaves its
  /// stamp behind (ADR 0094), so no older copy brings a row back, and the
  /// undo is [restoreProviderWithModels].
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
    final deletedIds = <String, int>{};

    final result = await _db.transaction(() async {
      try {
        final associatedModels = await _liveModelsOf(providerId);

        // Hard deletes: re-adding this provider must bring its models back, so
        // the cascade must not leave tombstones behind.
        for (final model in associatedModels) {
          deletedIds[model.id] = await _db.deleteConfig(model.id);
        }

        // Delete the provider itself. Nothing seeds providers, so there is
        // no tombstone to keep.
        try {
          deletedIds[providerId] = await _db.deleteConfig(providerId);
        } catch (e) {
          throw Exception('Failed to delete provider $providerId: $e');
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

    // Committed: only now are the rows really gone, so only now may the caches
    // drop them and the peers hear about it.
    deletedIds.keys.forEach(_noteHardDeleted);
    if (!fromSync) {
      // Deliberately non-fatal. The rows are already gone locally, so
      // throwing here would tell the user the deletion failed and withdraw
      // the undo affordance for work that did happen. A deletion the outbox
      // refuses stays owed in the ledger and is sent by the next flush; no
      // failure skips the rest.
      for (final MapEntry(key: id, value: stamp) in deletedIds.entries) {
        await _send(
          id,
          SyncMessage.aiConfigDelete(
            id: id,
            hardDelete: true,
            versionStamp: stamp,
          ),
        );
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
  /// [getConfigById] — and so is a model whose provider is deleted or
  /// missing ([_isOrphanedModel]).
  Future<List<AiConfig>> getConfigsByType(
    AiConfigType type, {
    bool includeDeleted = false,
  }) async {
    final configs = await _getConfigsByTypeIncludingDeleted(type);
    if (includeDeleted) return configs;
    final live = configs
        .where((config) => config.deletedAt == null)
        .toList(growable: false);
    if (type != AiConfigType.model || live.isEmpty) return live;
    final providers = await _getConfigsByTypeIncludingDeleted(
      AiConfigType.inferenceProvider,
    );
    final hardDeleted = await _loadHardDeletedIds();
    return live
        .where((model) => !_isOrphanedModel(model, providers, hardDeleted))
        .toList(growable: false);
  }

  /// Whether [config] is a model whose provider this device holds a deletion
  /// of: a tombstone among [providers], or a hard deletion in [hardDeleted].
  /// A provider never seen here is not a deletion, and its models stay
  /// listed as before.
  ///
  /// Such a model is a user's edit or restore stamped after the provider's
  /// deletion on a device that had not heard of it, which the receive keeps
  /// (`KeepNewerModels`) because an undo's restore looks the same. It is not
  /// deleted for the user — that would also delete the undo's restore — but
  /// it is not listed either: nothing can be inferred through it, and a
  /// restore of the provider shows it again.
  static bool _isOrphanedModel(
    AiConfig config,
    Iterable<AiConfig> providers,
    Set<String> hardDeleted,
  ) {
    if (config is! AiConfigModel) return false;
    final provider = providers
        .where((p) => p.id == config.inferenceProviderId)
        .firstOrNull;
    if (provider != null) return provider.deletedAt != null;
    return hardDeleted.contains(config.inferenceProviderId);
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
        final providers = type == AiConfigType.model
            ? allConfigs.where(
                (config) =>
                    _typeForConfig(config) == AiConfigType.inferenceProvider,
              )
            : const <AiConfig>[];
        final hardDeleted = _hardDeletedIds ?? const <String>{};
        final filtered = List<AiConfig>.unmodifiable(
          allConfigs
              .where(
                (config) =>
                    _typeForConfig(config) == type &&
                    config.deletedAt == null &&
                    !_isOrphanedModel(config, providers, hardDeleted),
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
    _hardDeletedIds?.remove(config.id);
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
        .then((_) => _loadHardDeletedIds())
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
