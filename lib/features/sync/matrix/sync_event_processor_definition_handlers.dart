part of 'sync_event_processor.dart';

/// Inbound apply path for [SyncEntityDefinition], split from the apply phase
/// for size. The journal's recency gate decides what is stored
/// (DefinitionClocks.tla); this side reindexes and announces a written
/// version, stamps a clockless row that kept its place against a clocked
/// copy, and records the copy's counters in the sequence log either way.
extension SyncEventProcessorDefinitionHandlers on SyncEventProcessor {
  Future<void> _applyEntityDefinition({
    required SyncEntityDefinition msg,
    required JournalDb journalDb,
  }) async {
    final entityDefinition = msg.entityDefinition;
    final measurable = entityDefinition is MeasurableDataType
        ? entityDefinition
        : null;
    final fts5Db = _fts5Db;
    final previousMeasurable = measurable != null && fts5Db != null
        ? await journalDb.getMeasurableDataTypeById(measurable.id)
        : null;
    final linesAffected = await journalDb.upsertEntityDefinition(
      entityDefinition,
    );
    if (linesAffected == 0) {
      // The journal kept its copy. Its content did not change, so there is
      // nothing to reindex or announce — reindexing from this copy would
      // rewrite search rows with labels the app no longer shows.
      _loggingService.log(
        LogDomain.sync,
        'Kept stored definition ${entityDefinition.id}',
        subDomain: 'processor.apply.entityDefinition.skipped',
      );
      await _stampIfKeptClockless(entityDefinition, journalDb: journalDb);
    } else {
      if (measurable != null &&
          fts5Db != null &&
          measurementDefinitionAffectsFts(previousMeasurable, measurable)) {
        try {
          final entries = await journalDb.getMeasurementsByTypeIncludingPrivate(
            type: measurable.id,
            rangeStart: DateTime(1),
            rangeEnd: DateTime(9999, 12, 31, 23, 59, 59, 999),
          );
          await fts5Db.reindexMeasurements(measurable, entries);
        } catch (exception, stackTrace) {
          // Search rows are derived. Keep the synced definition even if its
          // local index cannot be refreshed right now.
          _loggingService.error(
            LogDomain.sync,
            exception,
            stackTrace: stackTrace,
            subDomain: 'processor.apply.entityDefinition.reindex',
          );
        }
      }
      final typeNotification = switch (entityDefinition) {
        CategoryDefinition() => categoriesNotification,
        HabitDefinition() => habitsNotification,
        DashboardDefinition() => dashboardsNotification,
        MeasurableDataType() => measurablesNotification,
        LabelDefinition() => labelsNotification,
        SpeechDictionaryEntry() => speechDictionaryNotification,
      };
      _updateNotifications.notify(
        {entityDefinition.id, typeNotification},
        fromSync: true,
      );
    }
    await _recordReceivedEntityDefinition(msg);
  }

  /// A clockless row — written by an older build and not yet migrated —
  /// that kept its place against a clocked copy is newer than it. Stamping
  /// it on top of that copy's clock makes it supersede the copy on every
  /// device, so the newer content is not lost while the copy's sender holds
  /// a clock.
  Future<void> _stampIfKeptClockless(
    EntityDefinition incoming, {
    required JournalDb journalDb,
  }) async {
    final stamper = definitionClockStamper;
    final incomingClock = incoming.vectorClock;
    if (stamper == null || incomingClock == null) return;
    final stored = await journalDb.definitionStamp(incoming);
    if (stored == null || stored.vectorClock != null) return;
    try {
      await stamper.stamp(incoming.id, over: incomingClock);
    } catch (exception, stackTrace) {
      // The row stays clockless and is stamped by the next clocked arrival
      // or the manual migration; the received copy is still recorded.
      _loggingService.error(
        LogDomain.sync,
        exception,
        stackTrace: stackTrace,
        subDomain: 'processor.apply.entityDefinition.stamp',
      );
    }
  }

  Future<void> _recordReceivedEntityDefinition(
    SyncEntityDefinition msg,
  ) async {
    final vectorClock = msg.entityDefinition.vectorClock;
    final originatingHostId = msg.originatingHostId;
    if (_sequenceLogService == null ||
        vectorClock == null ||
        originatingHostId == null) {
      return;
    }
    try {
      final gaps = await _sequenceLogService.recordReceivedEntry(
        entryId: msg.entityDefinition.id,
        vectorClock: vectorClock,
        originatingHostId: originatingHostId,
        payloadType: SyncSequencePayloadType.entityDefinition,
      );
      if (gaps.isNotEmpty) {
        _trace(
          'apply.entityDefinition.gapsDetected count=${gaps.length} '
          'for definition=${msg.entityDefinition.id}',
          subDomain: 'processor.gapDetection',
        );
      }
    } catch (e, st) {
      _loggingService.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'processor.recordReceivedEntityDefinition',
      );
      rethrow;
    }
  }
}
