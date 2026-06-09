part of 'outbox_service.dart';

/// Entry-link and simple/typed enqueue helpers of [OutboxService] (entry
/// links, entity definitions, AI config, config flags, notifications, sync
/// node profiles, backfill). Split from [OutboxEnqueueDispatch] for file size;
/// all members are library-private, so no mock delegators are required.
extension OutboxEnqueueDispatchLinks on OutboxService {
  /// Enqueues a SyncEntryLink. Returns true if merge happened (caller should
  /// not call enqueueNextSendRequest again).
  Future<bool> _enqueueEntryLink({
    required SyncEntryLink msg,
    required OutboxCompanion commonFields,
    required String? host,
    required String? hostHash,
  }) async {
    final linkId = msg.entryLink.id;
    final localCounter = msg.entryLink.vectorClock?.vclock[host];
    final subject = localCounter == null
        ? '$hostHash:link'
        : '$hostHash:link:$localCounter';

    // Check for existing pending outbox item for this entry link (merge logic)
    final existingItem = await _syncDatabase.findPendingByEntryId(linkId);

    if (existingItem != null) {
      // Merge: extract old VC and add to coveredVectorClocks
      try {
        final oldMessage = SyncMessage.fromJson(
          json.decode(existingItem.message) as Map<String, dynamic>,
        );

        if (oldMessage is SyncEntryLink) {
          final coveredClocks = VectorClock.mergeUniqueClocks([
            ...?oldMessage.coveredVectorClocks,
            ...?msg.coveredVectorClocks,
            oldMessage.entryLink.vectorClock,
            msg.entryLink.vectorClock,
          ]);

          // Create merged message with covered clocks
          // Note: Unlike journal entities, entry links don't refresh from DB,
          // so each enqueue's VC is captured correctly when oldMessage.VC
          // is added to coveredClocks in subsequent merges.
          final mergedMessage = msg.copyWith(
            coveredVectorClocks: coveredClocks,
          );
          logVectorClockAssignment(
            _loggingService,
            subDomain: 'enqueue.merge',
            action: 'assign',
            type: 'SyncEntryLink',
            entryId: linkId,
            reason: 'pending_merge_cover',
            previous: msg.entryLink.vectorClock,
            assigned: msg.entryLink.vectorClock,
            coveredVectorClocks: coveredClocks,
            extras: {'oldVc': oldMessage.entryLink.vectorClock?.vclock},
          );

          final mergedJson = json.encode(mergedMessage.toJson());
          final mergedSize = utf8.encode(mergedJson).length;
          final mergedPriority = math.min(
            existingItem.priority,
            commonFields.priority.value,
          );
          final affectedRows = await _syncDatabase.updateOutboxMessage(
            itemId: existingItem.id,
            newMessage: mergedJson,
            newSubject: subject,
            payloadSize: mergedSize,
            priority: mergedPriority,
          );

          if (affectedRows == 0) {
            // Row was no longer pending — insert fresh row with merged data
            _loggingService.log(
              LogDomain.sync,
              'enqueue MERGE-MISS type=SyncEntryLink id=$linkId '
              '(row no longer pending, inserting fresh)',
              subDomain: 'enqueueMessage',
            );
            await _syncDatabase.addOutboxItem(
              commonFields.copyWith(
                subject: Value(subject),
                message: Value(mergedJson),
                payloadSize: Value(mergedSize),
                outboxEntryId: Value(linkId),
                priority: Value(mergedPriority),
              ),
            );
          }

          // Log covered clocks for debugging
          final coveredVcStrings = coveredClocks
              ?.map((vc) => vc.vclock)
              .toList();
          final latestVcStr = msg.entryLink.vectorClock?.vclock;
          _loggingService.log(
            LogDomain.sync,
            'enqueue MERGED type=SyncEntryLink id=$linkId '
            'coveredClocks=${coveredClocks?.length ?? 0} covered=$coveredVcStrings '
            'latest=$latestVcStr',
            subDomain: 'enqueueMessage',
          );

          // Still record in sequence log for the new counter
          if (_sequenceLogService != null &&
              msg.entryLink.vectorClock != null) {
            try {
              await _sequenceLogService.recordSentEntryLink(
                linkId: linkId,
                vectorClock: msg.entryLink.vectorClock!,
              );
            } catch (e, st) {
              _loggingService.error(
                LogDomain.sync,
                e,
                stackTrace: st,
                subDomain: 'recordSent',
              );
            }
          }

          unawaited(enqueueNextSendRequest(delay: const Duration(seconds: 1)));
          return true; // Merge happened - don't create new item
        }
      } catch (e, st) {
        _loggingService.error(
          LogDomain.sync,
          e,
          stackTrace: st,
          subDomain: 'enqueueMessage.merge',
        );
        // Fall through to create new item on merge error
      }
    }

    // No existing item or merge failed - create new outbox item with entryId.
    // Enrich covered VCs from the sequence log for already-sent predecessors.
    final enrichedLinkCovered = await _enrichCoveredVcsFromSequenceLog(
      linkId,
      msg.coveredVectorClocks,
    );
    var outboxLinkMsg = msg;
    if (enrichedLinkCovered != msg.coveredVectorClocks) {
      outboxLinkMsg = msg.copyWith(coveredVectorClocks: enrichedLinkCovered);
    }
    final outboxLinkJson = json.encode(outboxLinkMsg.toJson());
    final outboxLinkSize = utf8.encode(outboxLinkJson).length;
    await _syncDatabase.addOutboxItem(
      commonFields.copyWith(
        subject: Value(subject),
        outboxEntryId: Value(linkId),
        message: Value(outboxLinkJson),
        payloadSize: Value(outboxLinkSize),
      ),
    );
    _loggingService.log(
      LogDomain.sync,
      'enqueue type=SyncEntryLink subject=$subject '
      'from=${msg.entryLink.fromId} to=${msg.entryLink.toId}',
      subDomain: 'enqueueMessage',
    );

    // Record in sequence log for backfill support (self-healing sync)
    if (_sequenceLogService != null && msg.entryLink.vectorClock != null) {
      try {
        await _sequenceLogService.recordSentEntryLink(
          linkId: linkId,
          vectorClock: msg.entryLink.vectorClock!,
        );
      } catch (e, st) {
        _loggingService.error(
          LogDomain.sync,
          e,
          stackTrace: st,
          subDomain: 'recordSent',
        );
      }
    }

    return false; // No merge - caller should call enqueueNextSendRequest
  }

  /// Shared helper for simple message types that don't require merge logic.
  /// Adds the item to the outbox and logs the event.
  Future<bool> _enqueueSimple({
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

  Future<bool> _enqueueEntityDefinition({
    required SyncEntityDefinition msg,
    required OutboxCompanion commonFields,
    required String? host,
    required String? hostHash,
  }) async {
    final localCounter = msg.entityDefinition.vectorClock?.vclock[host];
    final subject = '$hostHash:$localCounter';
    return _enqueueSimple(
      commonFields: commonFields,
      subject: subject,
      logMessage:
          'enqueue type=SyncEntityDefinition '
          'subject=$subject id=${msg.entityDefinition.id}',
    );
  }

  Future<bool> _enqueueAiConfig({
    required SyncAiConfig msg,
    required OutboxCompanion commonFields,
  }) => _enqueueSimple(
    commonFields: commonFields,
    subject: 'aiConfig',
    logMessage:
        'enqueue type=SyncAiConfig subject=aiConfig '
        'id=${msg.aiConfig.id}',
  );

  Future<bool> _enqueueAiConfigDelete({
    required SyncAiConfigDelete msg,
    required OutboxCompanion commonFields,
  }) => _enqueueSimple(
    commonFields: commonFields,
    subject: 'aiConfigDelete',
    logMessage:
        'enqueue type=SyncAiConfigDelete subject=aiConfigDelete '
        'id=${msg.id}',
  );

  Future<bool> _enqueueConfigFlag({
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
        unawaited(enqueueNextSendRequest(delay: const Duration(seconds: 1)));
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

  Future<bool> _enqueueThemingSelection({
    required SyncThemingSelection msg,
    required OutboxCompanion commonFields,
  }) => _enqueueSimple(
    commonFields: commonFields,
    subject: 'themingSelection',
    logMessage:
        'enqueue type=SyncThemingSelection subject=themingSelection '
        'light=${msg.lightThemeName} dark=${msg.darkThemeName} '
        'mode=${msg.themeMode}',
  );

  Future<bool> _enqueueNotification({
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

    await _recordNotificationSent(
      entryId: msg.id,
      vectorClock: msg.vectorClock,
      payloadType: SyncSequencePayloadType.notification,
    );
    return false;
  }

  Future<bool> _enqueueNotificationStateUpdate({
    required SyncNotificationStateUpdate msg,
    required OutboxCompanion commonFields,
  }) async {
    final result = await _enqueueSimple(
      commonFields: commonFields,
      subject: 'notificationStateUpdate:${msg.id}',
      logMessage:
          'enqueue type=SyncNotificationStateUpdate '
          'subject=notificationStateUpdate:${msg.id}',
    );
    await _recordNotificationSent(
      entryId: msg.id,
      vectorClock: msg.vectorClock,
      payloadType: SyncSequencePayloadType.notificationStateUpdate,
    );
    return result;
  }

  Future<bool> _enqueueSyncNodeProfile({
    required SyncSyncNodeProfile msg,
    required OutboxCompanion commonFields,
  }) => _enqueueSimple(
    commonFields: commonFields,
    subject: 'syncNodeProfile',
    logMessage:
        'enqueue type=SyncSyncNodeProfile subject=syncNodeProfile '
        'hostId=${msg.profile.hostId} name=${msg.profile.displayName} '
        'caps=${msg.profile.capabilities.length}',
  );

  Future<bool> _enqueueBackfillRequest({
    required SyncBackfillRequest msg,
    required OutboxCompanion commonFields,
  }) => _enqueueSimple(
    commonFields: commonFields,
    subject: 'backfillRequest:batch:${msg.entries.length}',
    logMessage:
        'enqueue type=SyncBackfillRequest '
        'entries=${msg.entries.length}',
  );

  Future<bool> _enqueueBackfillResponse({
    required SyncBackfillResponse msg,
    required OutboxCompanion commonFields,
  }) => _enqueueSimple(
    commonFields: commonFields,
    subject: 'backfillResponse:${msg.hostId}:${msg.counter}',
    logMessage:
        'enqueue type=SyncBackfillResponse hostId=${msg.hostId} '
        'counter=${msg.counter} deleted=${msg.deleted}',
  );
}
