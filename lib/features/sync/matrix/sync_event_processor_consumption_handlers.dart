part of 'sync_event_processor.dart';

/// Inbound apply path for [SyncConsumptionEvent], split from the main file for
/// size. Consumption events are immutable and append-only, so this is far
/// simpler than the agent handler: there is no concurrent-merge and no
/// scheduling overlay — a fresh id is applied, a replayed id is skipped.
extension SyncEventProcessorConsumptionHandlers on SyncEventProcessor {
  Future<void> _applyConsumptionEventMessage({
    required SyncConsumptionEvent msg,
  }) async {
    final repo = consumptionRepository;
    if (repo == null) {
      _trace(
        'consumptionEvent.ignored no repository',
        subDomain: 'processor.apply',
      );
      return;
    }

    final capsule = msg.event.recoveryCapsule;
    final originatingHostId = msg.originatingHostId;
    final capsuleIsAuthentic =
        capsule == null ||
        (originatingHostId != null &&
            capsule.executor.hostId == originatingHostId);
    final event = capsuleIsAuthentic
        ? msg.event
        : msg.event.copyWith(recoveryCapsule: null);
    if (!capsuleIsAuthentic) {
      _trace(
        'consumptionEvent.recoveryCapsuleRejected id=${event.id}',
        subDomain: 'processor.apply',
      );
    }

    // Append-only dominance: a row is written once and never mutated, so the
    // only inbound outcomes are "new id → apply" and "replay of same id →
    // skip". If a local row exists whose clock dominates or equals the
    // incoming, this is a replay — record it as received and stop.
    final incomingVc = event.vectorClock;
    if (incomingVc != null) {
      final localVc = await repo.getVectorClock(event.id);
      if (localVc != null && _localClockDominates(localVc, incomingVc)) {
        final recoveryCapsule = event.recoveryCapsule;
        if (recoveryCapsule != null) {
          await repo.projectRecoveryCapsule(
            capsule: recoveryCapsule,
            event: event,
          );
        }
        await _recordReceivedConsumptionEvent(msg: msg, event: event);
        return;
      }
    }

    await repo.upsertEvent(event);
    if (event.attributionId == null) {
      try {
        await AiAttributionBackfillService(
          repo,
        ).backfill(consumptionEvents: [event]);
      } catch (error, stackTrace) {
        _loggingService.error(
          LogDomain.ai,
          error,
          stackTrace: stackTrace,
          subDomain: 'processor.aiAttributionBackfill',
        );
      }
    }
    final recoveryCapsule = event.recoveryCapsule;
    if (recoveryCapsule != null) {
      await repo.projectRecoveryCapsule(
        capsule: recoveryCapsule,
        event: event,
      );
    }
    _updateNotifications.notify(
      {
        if (event.taskId != null) event.taskId!,
        if (event.categoryId != null) event.categoryId!,
        aiConsumptionNotification,
      },
      fromSync: true,
    );
    _trace(
      'apply consumptionEvent id=${event.id}',
      subDomain: 'processor.apply',
    );

    await _recordReceivedConsumptionEvent(msg: msg, event: event);
  }

  /// True when [localVc] equals or strictly dominates [incomingVc] — i.e. the
  /// incoming payload carries nothing new. Treats an invalid clock as
  /// non-dominating so the incoming write is applied rather than silently lost.
  bool _localClockDominates(VectorClock localVc, VectorClock incomingVc) {
    try {
      final status = VectorClock.compare(localVc, incomingVc);
      return status == VclockStatus.equal || status == VclockStatus.a_gt_b;
    } catch (_) {
      return false;
    }
  }

  Future<void> _recordReceivedConsumptionEvent({
    required SyncConsumptionEvent msg,
    required AiConsumptionEvent event,
  }) async {
    if (_sequenceLogService == null ||
        event.vectorClock == null ||
        msg.originatingHostId == null) {
      return;
    }
    try {
      final gaps = await _sequenceLogService.recordReceivedEntry(
        entryId: event.id,
        vectorClock: event.vectorClock!,
        originatingHostId: msg.originatingHostId!,
        coveredVectorClocks: msg.coveredVectorClocks,
        payloadType: SyncSequencePayloadType.consumptionEvent,
      );
      if (gaps.isNotEmpty) {
        _trace(
          'apply.consumptionEvent.gapsDetected count=${gaps.length} '
          'for event=${event.id}',
          subDomain: 'processor.gapDetection',
        );
      }
    } catch (e, st) {
      _loggingService.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'processor.recordReceivedConsumptionEvent',
      );
    }
  }
}
