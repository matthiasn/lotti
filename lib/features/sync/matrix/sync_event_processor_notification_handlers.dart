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
    if (db == null) {
      _trace(
        'notification.ignored no database',
        subDomain: 'processor.apply',
      );
      return;
    }
    final notification = resolvedNotification;
    if (notification == null) return;

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

    if (_sequenceLogService != null && msg.originatingHostId.isNotEmpty) {
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
        _loggingService.captureException(
          e,
          domain: 'SYNC_SEQUENCE',
          subDomain: 'recordReceived',
          stackTrace: st,
        );
      }
    }
  }

  Future<void> _applyNotificationStateUpdateMessage(
    SyncNotificationStateUpdate msg,
  ) async {
    final db = _notificationsDb;
    if (db == null) {
      _trace(
        'notificationStateUpdate.ignored no database',
        subDomain: 'processor.apply',
      );
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

    if (_sequenceLogService != null && msg.originatingHostId.isNotEmpty) {
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
        _loggingService.captureException(
          e,
          domain: 'SYNC_SEQUENCE',
          subDomain: 'recordReceived',
          stackTrace: st,
        );
      }
    }
  }
}
