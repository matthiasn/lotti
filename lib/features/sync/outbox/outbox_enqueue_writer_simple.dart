part of 'outbox_enqueue_writer.dart';

/// Simple message enqueue methods for [OutboxEnqueueWriter]
/// (entity definitions, AI config, flags, theming, notifications, node
/// profile, backfill). Public extension so cross-library callers keep
/// invoking these on an [OutboxEnqueueWriter] instance.
extension OutboxEnqueueSimple on OutboxEnqueueWriter {
  /// Shared helper for message types whose row needs nothing but a subject.
  /// Adds the item to the outbox and logs the event.
  Future<void> enqueueSimple({
    required OutboxCompanion commonFields,
    required String subject,
    required String logMessage,
  }) async {
    await _syncDatabase.addOutboxItem(
      commonFields.copyWith(subject: Value(subject)),
    );
    _logEnqueueSample(
      logMessage,
      sampleKey: 'insert.simple',
    );
  }

  Future<void> enqueueEntityDefinition({
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

  Future<void> enqueueAiConfig({
    required SyncAiConfig msg,
    required OutboxCompanion commonFields,
  }) => enqueueSimple(
    commonFields: commonFields,
    subject: 'aiConfig',
    logMessage:
        'enqueue type=SyncAiConfig subject=aiConfig '
        'id=${msg.aiConfig.id}',
  );

  Future<void> enqueueAiConfigDelete({
    required SyncAiConfigDelete msg,
    required OutboxCompanion commonFields,
  }) => enqueueSimple(
    commonFields: commonFields,
    subject: 'aiConfigDelete',
    logMessage:
        'enqueue type=SyncAiConfigDelete subject=aiConfigDelete '
        'id=${msg.id}',
  );

  Future<void> enqueueSavedTaskFilter({
    required SyncSavedTaskFilter msg,
    required OutboxCompanion commonFields,
  }) => enqueueSimple(
    commonFields: commonFields,
    subject: 'savedTaskFilter',
    logMessage:
        'enqueue type=SyncSavedTaskFilter subject=savedTaskFilter '
        'id=${msg.filter.id}',
  );

  Future<void> enqueueSavedTaskFilterDelete({
    required SyncSavedTaskFilterDelete msg,
    required OutboxCompanion commonFields,
  }) => enqueueSimple(
    commonFields: commonFields,
    subject: 'savedTaskFilterDelete',
    logMessage:
        'enqueue type=SyncSavedTaskFilterDelete subject=savedTaskFilterDelete '
        'id=${msg.id}',
  );

  /// Appends a config-flag row keyed by the flag name. Rows are never merged:
  /// when the processor sends, it collapses the flag's pending rows onto the
  /// one enqueued last, so only the latest value ships (ADR 0086).
  Future<void> enqueueConfigFlag({
    required SyncConfigFlag msg,
    required OutboxCompanion commonFields,
  }) async {
    final key = 'configFlag:${msg.name}';
    await _syncDatabase.addOutboxItem(
      commonFields.copyWith(
        subject: Value(key),
        outboxEntryId: Value(key),
      ),
    );
    _logEnqueueSample(
      'enqueue type=SyncConfigFlag subject=$key '
      'status=${msg.status}',
      sampleKey: 'insert.SyncConfigFlag',
    );
  }

  Future<void> enqueueThemingSelection({
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

  Future<void> enqueueDailyOsUserName({
    required SyncDailyOsUserName msg,
    required OutboxCompanion commonFields,
  }) => enqueueSimple(
    commonFields: commonFields,
    subject: 'dailyOsUserName',
    logMessage:
        'enqueue type=SyncDailyOsUserName subject=dailyOsUserName '
        'updatedAt=${msg.updatedAt}',
  );

  /// Enqueues a notification message: validates the payload path stays within
  /// the documents root, folds the message's own clock into
  /// `coveredVectorClocks`, sizes the row including the on-disk attachment, and
  /// records the send in the sequence log. Skips (logs and returns)
  /// when the payload path is unsafe.
  Future<void> enqueueNotification({
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
      return;
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
    _logEnqueueSample(
      'enqueue type=SyncNotification id=${msg.id} attachBytes=$fileLength',
      sampleKey: 'insert.SyncNotification',
    );

    await recordNotificationSent(
      entryId: msg.id,
      vectorClock: msg.vectorClock,
      payloadType: SyncSequencePayloadType.notification,
    );
  }

  Future<void> enqueueNotificationStateUpdate({
    required SyncNotificationStateUpdate msg,
    required OutboxCompanion commonFields,
  }) async {
    await enqueueSimple(
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
  }

  /// Enqueues an AI consumption event. These are immutable and append-only
  /// (unique id, so they never collapse) and ride inline (no attachment), so this
  /// just writes the row with the event id and records the send in the sequence
  /// log for gap detection/backfill. [recordAgentSent] is the generic
  /// sequence-log recorder (accepts any [SyncSequencePayloadType]).
  Future<void> enqueueConsumptionEvent({
    required SyncConsumptionEvent msg,
    required OutboxCompanion commonFields,
  }) async {
    final id = msg.event.id;
    await enqueueSimple(
      commonFields: commonFields.copyWith(outboxEntryId: Value(id)),
      subject: 'consumptionEvent:$id',
      logMessage:
          'enqueue type=SyncConsumptionEvent subject=consumptionEvent:$id',
    );
    await recordAgentSent(
      entryId: id,
      vectorClock: msg.event.vectorClock,
      payloadType: SyncSequencePayloadType.consumptionEvent,
    );
  }

  Future<void> enqueueSyncNodeProfile({
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

  Future<void> enqueueBackfillRequest({
    required SyncBackfillRequest msg,
    required OutboxCompanion commonFields,
  }) async {
    if (msg.entries.isEmpty && msg.requesterSequenceHead != null) {
      // Keep at most one pending/in-flight announcement per origin. Never
      // change a leased row; the next periodic tick can announce a newer head.
      await _syncDatabase.transaction(() async {
        if (await _syncDatabase.hasPendingSequenceHeadAnnouncement(
          msg.requesterId,
        )) {
          return;
        }
        await enqueueSimple(
          commonFields: commonFields,
          subject: 'backfillRequest:head:${msg.requesterId}',
          logMessage:
              'enqueue sequenceHead host=${msg.requesterId} '
              'counter=${msg.requesterSequenceHead}',
        );
      });
      return;
    }
    await enqueueSimple(
      commonFields: commonFields,
      subject: 'backfillRequest:batch:${msg.entries.length}',
      logMessage:
          'enqueue type=SyncBackfillRequest '
          'entries=${msg.entries.length}',
    );
  }

  Future<void> enqueueMediaRequest({
    required SyncMediaRequest msg,
    required OutboxCompanion commonFields,
  }) => enqueueSimple(
    commonFields: commonFields,
    subject: 'mediaRequest:batch:${msg.entryIds.length}',
    logMessage:
        'enqueue type=SyncMediaRequest '
        'entries=${msg.entryIds.length} requester=${msg.requesterId}',
  );

  Future<void> enqueueBackfillResponse({
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
