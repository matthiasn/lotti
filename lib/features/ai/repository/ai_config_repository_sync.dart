part of 'ai_config_repository.dart';

/// How [AiConfigRepository] stamps, counts and sends its writes: the vector
/// clock counter each sent write spends (ADR 0136), the local write and its
/// message, a provider's cascade and the cleanup of models a deleted provider
/// leaves behind.
extension _AiConfigRepositorySync on AiConfigRepository {
  /// Runs [write] in a vector-clock scope, so the counters it reserves are
  /// released if it fails.
  Future<T> _counted<T>(Future<T> Function() write) {
    final service = _vectorClockService;
    return service == null ? write() : service.withVcScope(write);
  }

  /// The clock a sent write of [id] carries: this host's next counter on top
  /// of the clock held for [id], reserved for that payload (ADR 0136). Null
  /// in a world that does not sync.
  Future<VectorClock?> _nextClock(String id) async {
    final service = _vectorClockService;
    if (service == null) return null;
    return service.getNextVectorClock(
      previous: await _db.versionClock(id),
      payload: (id: id, type: SyncSequencePayloadType.aiConfig),
    );
  }

  /// Writes a local version of [config] under [clock] and returns its stamp:
  /// a model this device has never held a version of takes its live
  /// provider's stamp, anything else the next local stamp. A version that
  /// would lose at the provider's stamp takes the next local stamp instead,
  /// so what is sent is always the version held (ADR 0136).
  Future<int> _saveLocal(AiConfig config, VectorClock? clock) async {
    if (config is AiConfigModel && await _db.versionStamp(config.id) == null) {
      final provider = await getConfigById(config.inferenceProviderId);
      final providerStamp = provider == null
          ? null
          : await _db.versionStamp(provider.id);
      if (providerStamp != null &&
          await _db.applyConfigVersion(
            config,
            stamp: providerStamp,
            vectorClock: clock,
          )) {
        return providerStamp;
      }
    }
    return _db.saveConfig(config, vectorClock: clock);
  }

  Future<void> _enqueue(AiConfig config, int stamp, VectorClock? clock) =>
      _sender.send(
        config.id,
        SyncMessage.aiConfig(
          aiConfig: config,
          status: SyncEntryStatus.initial,
          versionStamp: stamp,
          vectorClock: clock,
        ),
      );

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
  /// deletion is stored, then sent owed ([AiConfigSyncSender.send]): a send that fails leaves
  /// the deletion recorded here and its id in the ledger for the next flush.
  Future<void> _deleteOrphanedModels(String providerId) async {
    final provider = await getConfigById(providerId, includeDeleted: true);
    if (provider != null && provider.deletedAt == null) return;
    final deletion = await _db.versionStamp(providerId);
    if (deletion == null) return;
    for (final model in await _liveModelsOf(providerId)) {
      final held = await _db.versionStamp(model.id);
      if (held != null && held > deletion) continue;
      await _sender.owing(
        [model.id],
        () => _counted(() async {
          // Not newer than the deletion, the model always loses to it here:
          // the deletion sent is the version held.
          final clock = await _nextClock(model.id);
          if (await _db.applyConfigDeletion(
            model.id,
            stamp: deletion,
            vectorClock: clock,
          )) {
            _noteHardDeleted(model.id);
          }
          await _sender.send(
            model.id,
            SyncMessage.aiConfigDelete(
              id: model.id,
              hardDelete: true,
              versionStamp: deletion,
              vectorClock: clock,
            ),
          );
        }),
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

  Future<CascadeDeletionResult> _deleteCascade(String providerId) async {
    final deletedIds = <String, ({int stamp, VectorClock? clock})>{};
    Future<({int stamp, VectorClock? clock})> delete(String id) async {
      final clock = await _nextClock(id);
      return (
        stamp: await _db.deleteConfig(id, vectorClock: clock),
        clock: clock,
      );
    }

    final result = await _db.transaction(() async {
      try {
        final associatedModels = await _liveModelsOf(providerId);

        // Hard deletes: re-adding this provider must bring its models back, so
        // the cascade must not leave tombstones behind.
        for (final model in associatedModels) {
          deletedIds[model.id] = await delete(model.id);
        }

        // Delete the provider itself. Nothing seeds providers, so there is
        // no tombstone to keep.
        try {
          deletedIds[providerId] = await delete(providerId);
        } catch (e) {
          throw Exception('Failed to delete provider $providerId: $e');
        }

        return CascadeDeletionResult(
          deletedModels: associatedModels,
        );
      } catch (error, stackTrace) {
        AiConfigRepository._logError(
          error,
          stackTrace,
          'deleteInferenceProviderWithModels',
        );
        rethrow; // Re-throw to let the caller handle the error
      }
    });

    // Committed: only now are the rows really gone, so only now may the caches
    // drop them and the peers hear about it.
    deletedIds.keys.forEach(_noteHardDeleted);
    // Non-fatal: the rows are gone locally, and a refused deletion stays
    // owed for the next flush.
    for (final MapEntry(key: id, value: deleted) in deletedIds.entries) {
      await _sender.send(
        id,
        SyncMessage.aiConfigDelete(
          id: id,
          hardDelete: true,
          versionStamp: deleted.stamp,
          vectorClock: deleted.clock,
        ),
      );
    }

    return result;
  }
}
