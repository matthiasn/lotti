part of 'outbox_enqueue_writer.dart';

/// Simple, merge-free message enqueue methods for [OutboxEnqueueWriter]
/// (entity definitions, AI config, flags, theming, notifications, node
/// profile, backfill). Public extension so cross-library callers keep
/// invoking these on an [OutboxEnqueueWriter] instance.
extension OutboxEnqueueSimple on OutboxEnqueueWriter {
  /// Shared helper for simple message types that don't require merge logic.
  /// Adds the item to the outbox and logs the event.
  Future<bool> enqueueSimple({
    required OutboxCompanion commonFields,
    required String subject,
    required String logMessage,
  }) async {
    await _syncDatabase.addOutboxItem(
      commonFields.copyWith(subject: Value(subject)),
    );
    _loggingService.log(
      LogDomain.sync,
      logMessage,
      subDomain: 'enqueueMessage',
    );
    return false;
  }

  Future<bool> enqueueEntityDefinition({
    required SyncEntityDefinition msg,
    required OutboxCompanion commonFields,
    required String? host,
    required String? hostHash,
  }) async {
    final localCounter = msg.entityDefinition.vectorClock?.vclock[host];
    final subject = '$hostHash:$localCounter';
    return enqueueSimple(
      commonFields: commonFields,
      subject: subject,
      logMessage:
          'enqueue type=SyncEntityDefinition '
          'subject=$subject id=${msg.entityDefinition.id}',
    );
  }

  Future<bool> enqueueAiConfig({
    required SyncAiConfig msg,
    required OutboxCompanion commonFields,
  }) => enqueueSimple(
    commonFields: commonFields,
    subject: 'aiConfig',
    logMessage:
        'enqueue type=SyncAiConfig subject=aiConfig '
        'id=${msg.aiConfig.id}',
  );

  Future<bool> enqueueAiConfigDelete({
    required SyncAiConfigDelete msg,
    required OutboxCompanion commonFields,
  }) => enqueueSimple(
    commonFields: commonFields,
    subject: 'aiConfigDelete',
    logMessage:
        'enqueue type=SyncAiConfigDelete subject=aiConfigDelete '
        'id=${msg.id}',
  );

  /// Enqueues a config-flag change, coalescing with an already-pending row for
  /// the same flag when one exists: the existing row's message is updated in
  /// place (keeping the higher priority) so only the latest value ships.
  /// Returns `true` when it merged into an existing row, `false` when it
  /// inserted a fresh one. The in-place update only matches `status=pending`,
  /// so a row already being sent falls through to a new insert.
  Future<bool> enqueueConfigFlag({
    required SyncConfigFlag msg,
    required OutboxCompanion commonFields,
  }) async {
    final key = 'configFlag:${msg.name}';
    final existingItem = await _syncDatabase.findPendingByEntryId(key);
    if (existingItem != null) {
      final affectedRows = await _syncDatabase.updateOutboxMessage(
        itemId: existingItem.id,
        newMessage: commonFields.message.value,
        newSubject: key,
        payloadSize: commonFields.payloadSize.value,
        priority: math.min(
          existingItem.priority,
          commonFields.priority.value,
        ),
      );
      if (affectedRows > 0) {
        _loggingService.log(
          LogDomain.sync,
          'enqueue MERGED type=SyncConfigFlag subject=$key '
          'status=${msg.status}',
          subDomain: 'enqueueMessage',
        );
        unawaited(_enqueueNextSendRequest(delay: const Duration(seconds: 1)));
        return true;
      }
    }

    await _syncDatabase.addOutboxItem(
      commonFields.copyWith(
        subject: Value(key),
        outboxEntryId: Value(key),
      ),
    );
    _loggingService.log(
      LogDomain.sync,
      'enqueue type=SyncConfigFlag subject=$key '
      'status=${msg.status}',
      subDomain: 'enqueueMessage',
    );
    return false;
  }

  Future<bool> enqueueThemingSelection({
    required SyncThemingSelection msg,
    required OutboxCompanion commonFields,
  }) => enqueueSimple(
    commonFields: commonFields,
    subject: 'themingSelection',
    logMessage:
        'enqueue type=SyncThemingSelection subject=themingSelection '
        'light=${msg.lightThemeName} dark=${msg.darkThemeName} '
        'mode=${msg.themeMode}',
  );

  /// Enqueues a notification message: validates the payload path stays within
  /// the documents root, folds the message's own clock into
  /// `coveredVectorClocks`, sizes the row including the on-disk attachment, and
  /// records the send in the sequence log. Skips (logs and returns `false`)
  /// when the payload path is unsafe.
  Future<bool> enqueueNotification({
    required SyncNotification msg,
    required OutboxCompanion commonFields,
  }) async {
    final fullPath = _safePayloadFullPath(msg.jsonPath);
    if (fullPath == null) {
      _loggingService.log(
        LogDomain.sync,
        'enqueue.skip invalid notification payload path: ${msg.jsonPath}',
        subDomain: 'enqueueMessage',
      );
      return false;
    }

    var fileLength = 0;
    try {
      fileLength = await File(fullPath).length();
    } catch (_) {
      fileLength = 0;
    }

    final covered = VectorClock.mergeUniqueClocks([
      ...?msg.coveredVectorClocks,
      msg.vectorClock,
    ]);
    final outboxMessage = covered == msg.coveredVectorClocks
        ? msg
        : msg.copyWith(coveredVectorClocks: covered);
    final outboxJson = json.encode(outboxMessage.toJson());
    final outboxSize = utf8.encode(outboxJson).length + fileLength;
    await _syncDatabase.addOutboxItem(
      commonFields.copyWith(
        subject: Value('notification:${msg.id}'),
        message: Value(outboxJson),
        filePath: Value(msg.jsonPath),
        outboxEntryId: Value(msg.id),
        payloadSize: Value(outboxSize),
      ),
    );
    _loggingService.log(
      LogDomain.sync,
      'enqueue type=SyncNotification id=${msg.id} attachBytes=$fileLength',
      subDomain: 'enqueueMessage',
    );

    await recordNotificationSent(
      entryId: msg.id,
      vectorClock: msg.vectorClock,
      payloadType: SyncSequencePayloadType.notification,
    );
    return false;
  }

  Future<bool> enqueueNotificationStateUpdate({
    required SyncNotificationStateUpdate msg,
    required OutboxCompanion commonFields,
  }) async {
    final result = await enqueueSimple(
      commonFields: commonFields,
      subject: 'notificationStateUpdate:${msg.id}',
      logMessage:
          'enqueue type=SyncNotificationStateUpdate '
          'subject=notificationStateUpdate:${msg.id}',
    );
    await recordNotificationSent(
      entryId: msg.id,
      vectorClock: msg.vectorClock,
      payloadType: SyncSequencePayloadType.notificationStateUpdate,
    );
    return result;
  }

  Future<bool> enqueueSyncNodeProfile({
    required SyncSyncNodeProfile msg,
    required OutboxCompanion commonFields,
  }) => enqueueSimple(
    commonFields: commonFields,
    subject: 'syncNodeProfile',
    logMessage:
        'enqueue type=SyncSyncNodeProfile subject=syncNodeProfile '
        'hostId=${msg.profile.hostId} name=${msg.profile.displayName} '
        'caps=${msg.profile.capabilities.length}',
  );

  Future<bool> enqueueBackfillRequest({
    required SyncBackfillRequest msg,
    required OutboxCompanion commonFields,
  }) => enqueueSimple(
    commonFields: commonFields,
    subject: 'backfillRequest:batch:${msg.entries.length}',
    logMessage:
        'enqueue type=SyncBackfillRequest '
        'entries=${msg.entries.length}',
  );

  Future<bool> enqueueBackfillResponse({
    required SyncBackfillResponse msg,
    required OutboxCompanion commonFields,
  }) => enqueueSimple(
    commonFields: commonFields,
    subject: 'backfillResponse:${msg.hostId}:${msg.counter}',
    logMessage:
        'enqueue type=SyncBackfillResponse hostId=${msg.hostId} '
        'counter=${msg.counter} deleted=${msg.deleted}',
  );
}
