part of 'sync_event_processor.dart';

extension _NotificationHandlers on SyncEventProcessor {
  Future<NotificationEntity?> _resolveNotification(
    SyncNotification msg,
  ) {
    return _resolveAgentPayload(
      inline: null,
      jsonPath: msg.jsonPath,
      fromJson: NotificationEntity.fromJson,
      typeName: 'notification',
    );
  }

  Future<void> _applyNotificationMessage({
    required SyncNotification msg,
    required NotificationEntity? resolvedNotification,
  }) async {
    final db = _notificationsDb;
    final notification = resolvedNotification;

    if (db != null && notification != null) {
      final saved = await db.upsertNotification(notification);
      if (saved != null) {
        await _notificationScheduler?.schedule(saved);
        _updateNotifications.notify(
          {
            saved.id,
            if (saved.linkedEntityId != null) saved.linkedEntityId!,
            inboxNotification,
          },
          fromSync: true,
        );
        _trace(
          'apply notification id=${saved.id}',
          subDomain: 'processor.apply',
        );
      }
    } else if (db == null) {
      // No notifications DB on this device — still mark received so peers
      // stop requesting backfill for an event we'll never apply.
      _trace(
        'notification.ignored no database',
        subDomain: 'processor.apply',
      );
    } else {
      // db is wired but the JSON payload could not be resolved. Skip the
      // receipt so the event is retried once the attachment arrives.
      _trace(
        'notification.deferred no resolved payload id=${msg.id}',
        subDomain: 'processor.apply',
      );
      return;
    }

    await _recordNotificationReceived(msg);
  }

  Future<void> _applyNotificationStateUpdateMessage(
    SyncNotificationStateUpdate msg,
  ) async {
    final db = _notificationsDb;
    if (db == null) {
      // No notifications DB on this device — still mark received so peers
      // stop requesting backfill for an event we'll never apply.
      _trace(
        'notificationStateUpdate.ignored no database',
        subDomain: 'processor.apply',
      );
      await _recordNotificationStateUpdateReceived(msg);
      return;
    }

    final result = await db.mergeState(
      id: msg.id,
      seenAt: msg.seenAt,
      actedOnAt: msg.actedOnAt,
      deletedAt: msg.deletedAt,
      vectorClock: msg.vectorClock,
      originatingHostId: msg.originatingHostId,
    );
    if (result.isMissing) {
      // Base notification has not arrived yet — leave the event pending so
      // the queue retries once the upstream `SyncNotification` lands.
      throw FileSystemException(
        'notification base not yet available',
        msg.id,
      );
    }

    final updated = result.entity;
    if (updated != null && result.changed) {
      await _notificationScheduler?.schedule(updated);
      _updateNotifications.notify(
        {
          updated.id,
          if (updated.linkedEntityId != null) updated.linkedEntityId!,
          inboxNotification,
        },
        fromSync: true,
      );
      _trace(
        'apply notificationStateUpdate id=${updated.id}',
        subDomain: 'processor.apply',
      );
    }

    await _recordNotificationStateUpdateReceived(msg);
  }

  Future<void> _recordNotificationReceived(SyncNotification msg) async {
    if (_sequenceLogService == null || msg.originatingHostId.isEmpty) return;
    try {
      final gaps = await _sequenceLogService.recordReceivedEntry(
        entryId: msg.id,
        vectorClock: msg.vectorClock,
        originatingHostId: msg.originatingHostId,
        coveredVectorClocks: msg.coveredVectorClocks,
        payloadType: SyncSequencePayloadType.notification,
        jsonPath: msg.jsonPath,
      );
      if (gaps.isNotEmpty) {
        _trace(
          'apply.notification.gapsDetected count=${gaps.length} '
          'for notification=${msg.id}',
          subDomain: 'processor.gapDetection',
        );
      }
    } catch (e, st) {
      _loggingService.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'recordReceived',
      );
    }
  }

  Future<void> _recordNotificationStateUpdateReceived(
    SyncNotificationStateUpdate msg,
  ) async {
    if (_sequenceLogService == null || msg.originatingHostId.isEmpty) return;
    try {
      final gaps = await _sequenceLogService.recordReceivedEntry(
        entryId: msg.id,
        vectorClock: msg.vectorClock,
        originatingHostId: msg.originatingHostId,
        payloadType: SyncSequencePayloadType.notificationStateUpdate,
      );
      if (gaps.isNotEmpty) {
        _trace(
          'apply.notificationStateUpdate.gapsDetected count=${gaps.length} '
          'for notification=${msg.id}',
          subDomain: 'processor.gapDetection',
        );
      }
    } catch (e, st) {
      _loggingService.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'recordReceived',
      );
    }
  }
}
