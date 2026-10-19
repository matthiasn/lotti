part of 'sync_event_processor.dart';

/// The apply phase of [SyncEventProcessor] — persists a prepared sync event —
/// together with its diagnostics and prepared-event result models. Split from
/// the main file for size.
extension SyncEventProcessorApply on SyncEventProcessor {
  Future<SyncApplyDiagnostics?> _applyMessage({
    required PreparedSyncEvent prepared,
    required JournalDb journalDb,
    AfterCommitSink? afterCommit,
  }) async {
    final event = prepared.event;
    final syncMessage = prepared.syncMessage;
    // Self-echo short-circuit. Prepare flagged this event as one the local
    // host originated; the journal/agent/outbox payload was written locally
    // before the message was sent, so apply has nothing to do for any
    // family. Returning null commits the queue row cleanly (marker
    // advances, no skip count, no retry) and — critically — avoids
    // dereferencing the unpopulated `journalEntity` / `resolvedOutboxBundle`
    // slots that would otherwise null-bang in the per-family branches
    // below.
    if (prepared.isSelfEcho) {
      _trace(
        'apply selfEcho.skip type=${syncMessage.runtimeType} '
        'eventId=${event.eventId}',
        subDomain: 'processor.apply',
      );
      return null;
    }
    switch (syncMessage) {
      case final SyncJournalEntity msg:
        return _applyJournalEntity(
          event: event,
          syncMessage: msg,
          preloaded: prepared.journalEntity,
          isDuplicate: prepared.isDuplicateJournalEntity,
          deferredStaleError: prepared.deferredStaleDescriptorError,
          journalDb: journalDb,
        );
      case final SyncEntryLink msg:
        return _handleEntryLink(
          event: event,
          syncMessage: msg,
          journalDb: journalDb,
        );
      case final SyncEntityDefinition msg:
        await _applyEntityDefinition(msg: msg, journalDb: journalDb);
        return null;
      case SyncAiConfig(
        :final aiConfig,
        :final versionStamp,
        :final vectorClock,
        :final originatingHostId,
      ):
        // Ordered by stamp, not by arrival: a send that timed out and lands
        // after a newer version is dropped (ADR 0094). Older senders carry no
        // stamp; the server's timestamp stands in, as for config flags.
        await _aiConfigRepository.saveConfig(
          aiConfig,
          fromSync: true,
          versionStamp: versionStamp,
          fallbackStamp: event.originServerTs.millisecondsSinceEpoch,
          vectorClock: vectorClock,
        );
        await _recordReceivedAiConfig(
          aiConfig.id,
          vectorClock: vectorClock,
          originatingHostId: originatingHostId,
        );
        await _answerLegacyAiConfig(aiConfig.id, versionStamp);
        return null;
      case SyncAiConfigDelete(
        :final id,
        :final hardDelete,
        :final versionStamp,
        :final vectorClock,
        :final originatingHostId,
      ):
        final stamp =
            versionStamp ?? event.originServerTs.millisecondsSinceEpoch;
        // Current builds only send this envelope, marked, for hard deletes —
        // a deleted prompt or skill, a provider cascade, or a model left
        // under a deleted provider. Applying those softly would keep the
        // deleted content as a hidden record.
        //
        // An absent flag is a *legacy* user deletion from 0.9.1068 or earlier,
        // which had no other way to express one. Hard-deleting it would let
        // seeding recreate the row, undoing that user's deletion, so it
        // becomes a tombstone instead.
        if (hardDelete ?? false) {
          await _aiConfigRepository.hardDeleteConfig(
            id,
            fromSync: true,
            versionStamp: stamp,
            vectorClock: vectorClock,
          );
        } else {
          await _aiConfigRepository.deleteConfig(
            id,
            fromSync: true,
            versionStamp: stamp,
          );
        }
        await _recordReceivedAiConfig(
          id,
          vectorClock: vectorClock,
          originatingHostId: originatingHostId,
        );
        await _answerLegacyAiConfig(id, versionStamp);
        return null;
      case SyncSavedTaskFilter(:final filter):
        await _savedTaskFiltersRepository.upsert(
          filter,
          fromSync: true,
        );
        return null;
      case SyncSavedTaskFilterDelete(:final id, :final deletedAt):
        await _savedTaskFiltersRepository.delete(
          id,
          fromSync: true,
          deletedAt: deletedAt,
        );
        return null;
      case SyncConfigFlag(
        :final name,
        :final description,
        :final status,
        :final updatedAt,
      ):
        final configFlag = ConfigFlag(
          name: name,
          description: description,
          status: status,
        );
        final result = await journalDb.applyConfigFlagVersion(
          configFlag,
          updatedAt: updatedAt ?? event.originServerTs.millisecondsSinceEpoch,
        );
        // A build before stamps (#4517) applies flags in arrival order. It
        // sent this unstamped one, or a stamped one reached it after a newer
        // version: send the version held here, so the newest arrives last
        // (ADR 0131).
        // A new peer ignores the answer, being no newer than what it holds.
        final staleAtOldPeer =
            !result.applied &&
            (result.updatedAt != updatedAt || result.flag != configFlag);
        if (updatedAt == null || staleAtOldPeer) {
          await _answerWithHeld(
            SyncMessage.configFlag(
              name: result.flag.name,
              description: result.flag.description,
              status: result.flag.status,
              updatedAt: result.updatedAt,
            ),
          );
        }
        if (!result.applied) return null;
        if (configFlag.name == 'private') {
          _updateNotifications.notify(
            {privateToggleNotification},
            fromSync: true,
          );
        }
        // A notification preference flipped on a peer governs this device's
        // alarms too: the same consequences the local hook runs, so a kind
        // switched off over there stops alerting here, and one switched on
        // re-arms what is already in the inbox. Those consequences are
        // platform calls and an alarm reconciliation, which must not run
        // inside the flag's owned transaction — they would hold the writer
        // lock for every reader. The flag has committed at this point; a
        // caller-provided after-commit slot can defer the effects further.
        final effects = result.statusChanged
            ? _notificationPreferenceEffects?.call(journalDb)
            : null;
        if (effects != null) {
          Future<void> applyEffects() => effects.apply(configFlag);
          if (afterCommit != null) {
            afterCommit(applyEffects);
          } else {
            await applyEffects();
          }
        }
        return null;
      case SyncThemingSelection(
        :final lightThemeName,
        :final darkThemeName,
        :final themeMode,
        :final updatedAt,
      ):
        try {
          // Normalize themeMode value
          final normalizedMode =
              EnumToString.fromString(
                ThemeMode.values,
                themeMode,
              ) ??
              ThemeMode.system;

          // The values and their freshness stamp must commit together.
          final applied = await _settingsDb.saveSettingsItemsIfNewer(
            {
              lightSchemeNameKey: lightThemeName,
              darkSchemeNameKey: darkThemeName,
              themeModeKey: EnumToString.convertToString(normalizedMode),
              themePrefsUpdatedAtKey: updatedAt.toString(),
            },
            stampKey: themePrefsUpdatedAtKey,
            payloadKeys: [lightSchemeNameKey, darkSchemeNameKey, themeModeKey],
          );
          if (!applied) return null;

          _updateNotifications.notify(
            {settingsNotification},
            fromSync: true,
          );

          _trace(
            'apply themingSelection light=$lightThemeName dark=$darkThemeName mode=$themeMode',
            subDomain: 'processor.apply',
          );
          _loggingService.log(
            LogDomain.theming,
            'apply themingSelection light=$lightThemeName dark=$darkThemeName mode=$themeMode',
            subDomain: 'apply',
          );
        } catch (e, st) {
          _loggingService.error(
            LogDomain.theming,
            e,
            stackTrace: st,
            subDomain: 'apply',
          );
          rethrow;
        }
        return null;
      case SyncCompanionCustomization(:final customization, :final updatedAt):
        try {
          // Stored as received: the companion reads it, and falls back to her
          // defaults for anything it cannot. Value, stamp and published
          // marker commit together, as the greeting name's do.
          final applied = await _settingsDb.saveSettingsItemsIfNewer(
            {
              companionCustomizationKey: customization,
              companionCustomizationUpdatedAtKey: updatedAt.toString(),
              companionCustomizationSyncedAtKey: updatedAt.toString(),
            },
            stampKey: companionCustomizationUpdatedAtKey,
            payloadKeys: [companionCustomizationKey],
          );
          if (!applied) return null;

          _updateNotifications.notify(
            {settingsNotification},
            fromSync: true,
          );

          _trace(
            'apply companionCustomization updatedAt=$updatedAt',
            subDomain: 'processor.apply',
          );
        } catch (e, st) {
          _loggingService.error(
            LogDomain.settings,
            e,
            stackTrace: st,
            subDomain: 'apply',
          );
          rethrow;
        }
        return null;
      case SyncDailyOsUserName(:final userName, :final updatedAt):
        try {
          // A received name is already published. Its value, freshness stamp
          // and bootstrap marker belong to the same atomic settings group.
          final applied = await _settingsDb.saveSettingsItemsIfNewer(
            {
              dailyOsUserNameSettingsKey: userName,
              dailyOsUserNameUpdatedAtSettingsKey: updatedAt.toString(),
              dailyOsUserNameSyncedAtSettingsKey: updatedAt.toString(),
            },
            stampKey: dailyOsUserNameUpdatedAtSettingsKey,
            payloadKeys: [dailyOsUserNameSettingsKey],
          );
          if (!applied) return null;

          _updateNotifications.notify(
            {settingsNotification},
            fromSync: true,
          );

          // Content-free: never log the greeting name itself.
          _trace(
            'apply dailyOsUserName updatedAt=$updatedAt',
            subDomain: 'processor.apply',
          );
        } catch (e, st) {
          _loggingService.error(
            LogDomain.dailyOs,
            e,
            stackTrace: st,
            subDomain: 'apply',
          );
          rethrow;
        }
        return null;
      case SyncGitHubAccount(:final token, :final login, :final updatedAt):
        final applyAccount = _gitHubAccountSink;
        if (applyAccount == null) return null;
        try {
          final applied = await applyAccount(
            token: token?.value,
            login: login,
            updatedAt: updatedAt,
          );
          if (!applied) return null;

          _updateNotifications.notify(
            {gitHubAccountNotification},
            fromSync: true,
          );

          // Content-free: never log the token, nor whose it is.
          _trace(
            'apply gitHubAccount updatedAt=$updatedAt '
            'connected=${token != null}',
            subDomain: 'processor.apply',
          );
        } catch (e, st) {
          _loggingService.error(LogDomain.sync, e, stackTrace: st);
          rethrow;
        }
        return null;
      case SyncOnboardingSnapshotBegin() ||
          SyncOnboardingSnapshotAccepted() ||
          SyncOnboardingTerminalCounters() ||
          SyncOnboardingSnapshotEnd():
        await onboardingSyncService?.handleMessage(syncMessage);
        return null;
      case SyncBackfillRequest():
        // Handle backfill request - another device is asking for a missing entry
        await backfillResponseHandler.handleBackfillRequest(syncMessage);
        return null;
      case final SyncDeepBackfillInventory msg:
        // A peer's deep-backfill inventory batch: diff it, then request and
        // push what differs (`DeepBackfillService.handleInventory`).
        await deepBackfillService?.handleInventory(msg);
        return null;
      case final SyncDeepBackfillRequest msg:
        // A peer asks this device, the advertiser, for current versions.
        await deepBackfillService?.handleRequest(msg);
        return null;
      case final SyncMediaRequest msg:
        // A peer is missing blobs for entries it already holds. Answering is
        // best-effort: the request is broadcast, and a device that lacks the
        // file simply stays quiet.
        await mediaRequestHandler?.handleMediaRequest(msg);
        return null;
      case final SyncAgentWakeCoordination msg:
        // A peer claims, completes or releases an agent wake. Runtime state
        // only: nothing is persisted.
        agentWakeCoordinator?.onMessage(msg);
        return null;
      case SyncBackfillResponse():
        // Handle backfill response - another device responded to our request
        await backfillResponseHandler.handleBackfillResponse(syncMessage);
        return null;
      // Agent entities and links are file-backed often enough that stale
      // descriptors can arrive after a newer local write. The handlers compare
      // local vs incoming vector clocks before upsert and skip dominated
      // payloads while still recording the sequence receipt.
      case final SyncAgentEntity msg:
        await _applyAgentEntityMessage(
          msg: msg,
          resolvedEntity: prepared.resolvedAgentEntity,
          pendingProjectActivityAtWasPresent:
              prepared.pendingProjectActivityAtWasPresent,
        );
        return null;
      case final SyncConsumptionEvent msg:
        await _applyConsumptionEventMessage(msg: msg);
        return null;
      case final SyncAgentLink msg:
        await _applyAgentLinkMessage(
          msg: msg,
          resolvedLink: prepared.resolvedAgentLink,
        );
        return null;
      case final SyncNotification msg:
        await _applyNotificationMessage(
          msg: msg,
          resolvedNotification: prepared.resolvedNotification,
        );
        return null;
      case final SyncNotificationStateUpdate msg:
        await _applyNotificationStateUpdateMessage(msg);
        return null;
      case SyncAgentBundle():
        // Legacy wire variant — already logged + skipped in prepare. Apply
        // is a no-op so the inbound queue marker advances; missing
        // children resurface via the per-(host, counter) backfill path.
        return null;
      case SyncOutboxBundle():
        final bundle = prepared.resolvedOutboxBundle;
        if (bundle == null) return null;
        // Each agent entity of the bundle is read afresh inside its own
        // receive transaction; a snapshot taken before them would be stale.
        await _outboxBundleUnpacker.apply(
          bundle: bundle,
          applyChild: (child) => _applyMessage(
            prepared: child,
            journalDb: journalDb,
            // Bundles have no outer transaction. Complete each child's
            // effects now; a later child's failure must not discard them.
          ),
        );
        return null;
      case SyncSyncNodeProfile(:final profile):
        final repo = _syncNodeProfileRepository;
        if (repo != null) {
          try {
            final changed = await repo.upsertNode(profile);
            _trace(
              'apply syncNodeProfile hostId=${profile.hostId} '
              'name=${profile.displayName} caps=${profile.capabilities.length} '
              'changed=$changed',
              subDomain: 'processor.apply.syncNodeProfile',
            );
          } catch (error, stackTrace) {
            // Log AND rethrow: an upsert failure (e.g. SettingsDb write
            // refused, JSON encode glitch) must leave the inbound event
            // eligible for retry. Swallowing here would silently drop peer
            // profile updates, which the pinning UI relies on to surface
            // capable devices.
            _loggingService.error(
              LogDomain.sync,
              error,
              stackTrace: stackTrace,
              subDomain: 'apply.upsert',
            );
            rethrow;
          }
        }
        return null;
    }
  }

  /// Sends [message] through [SyncEventProcessor.answerWithHeld]. A failure
  /// is logged: the next stale or unstamped arrival answers again.
  Future<void> _answerWithHeld(SyncMessage message) async {
    final answer = answerWithHeld;
    if (answer == null) return;
    try {
      await answer(message);
    } catch (error, stackTrace) {
      _loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'processor.apply.answerWithHeld',
      );
    }
  }

  /// Records the counters of a received AI configuration version in the
  /// sequence log, kept or not: the held version joined its clock, so it
  /// answers for them, and the ones below are gaps to ask for (ADR 0136).
  /// Copies from builds before clocks carry none and are not tracked. A
  /// failure is rethrown, so the receive retries.
  Future<void> _recordReceivedAiConfig(
    String id, {
    required VectorClock? vectorClock,
    required String? originatingHostId,
  }) async {
    final sequenceLog = _sequenceLogService;
    if (sequenceLog == null ||
        vectorClock == null ||
        originatingHostId == null) {
      return;
    }
    try {
      final gaps = await sequenceLog.recordReceivedEntry(
        entryId: id,
        vectorClock: vectorClock,
        originatingHostId: originatingHostId,
        payloadType: SyncSequencePayloadType.aiConfig,
      );
      if (gaps.isNotEmpty) {
        _trace(
          'apply.aiConfig.gapsDetected count=${gaps.length} for config=$id',
          subDomain: 'processor.gapDetection',
        );
      }
    } catch (error, stackTrace) {
      _loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'processor.recordReceivedAiConfig',
      );
      rethrow;
    }
  }

  /// Resends the version of AI configuration [id] held here when the one
  /// received came from a build that applies them in arrival order (no
  /// [receivedStamp]), or was older than the one held: that build keeps
  /// whatever arrives last, so the newest has to arrive last (ADR 0131). A
  /// copy as new as the one held is no answer's cause, so two current
  /// builds never answer each other.
  Future<void> _answerLegacyAiConfig(String id, int? receivedStamp) async {
    try {
      if (receivedStamp != null) {
        final held = await _aiConfigRepository.versionStamp(id);
        if (held == null || held <= receivedStamp) return;
      }
      await _aiConfigRepository.resendHeld(id);
    } catch (error, stackTrace) {
      _loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'processor.apply.answerLegacyAiConfig',
      );
    }
  }
}

class SyncApplyDiagnostics {
  SyncApplyDiagnostics({
    required this.eventId,
    required this.payloadType,
    required this.conflictStatus,
    required this.applied,
    this.skipReason,
  });

  final String eventId;
  final String payloadType;
  final String conflictStatus;
  final bool applied;
  final JournalUpdateSkipReason? skipReason;
}

/// Output of [SyncEventProcessor.prepare]: the decoded envelope plus any
/// file-backed payload that was resolved outside the writer transaction.
/// [SyncEventProcessor.apply] consumes this and runs the DB writes.
class PreparedSyncEvent {
  @visibleForTesting
  PreparedSyncEvent.forTesting({
    required this.event,
    required this.syncMessage,
    this.journalEntity,
    this.isDuplicateJournalEntity = false,
    this.isSelfEcho = false,
    this.deferredStaleDescriptorError,
    this.resolvedAgentEntity,
    this.pendingProjectActivityAtWasPresent,
    this.resolvedAgentLink,
    this.resolvedNotification,
    this.resolvedOutboxBundle,
    this.hasUndecodableParts = false,
  });

  PreparedSyncEvent._({
    required this.event,
    required this.syncMessage,
    this.journalEntity,
    this.isDuplicateJournalEntity = false,
    this.isSelfEcho = false,
    this.deferredStaleDescriptorError,
    this.resolvedAgentEntity,
    this.pendingProjectActivityAtWasPresent,
    this.resolvedAgentLink,
    this.resolvedNotification,
    this.resolvedOutboxBundle,
    this.hasUndecodableParts = false,
  });

  final Event event;
  final SyncMessage syncMessage;

  /// Loaded journal entity when [syncMessage] is a [SyncJournalEntity] that
  /// was not a duplicate and whose descriptor resolved cleanly. Null for
  /// duplicates, stale-descriptor deferrals, and every other message family.
  final JournalEntity? journalEntity;

  /// True when prepare detected a duplicate by (id, vectorClock) fingerprint
  /// and skipped the loader call. Apply still records the duplicate in the
  /// sequence log so hint resolution runs.
  final bool isDuplicateJournalEntity;

  /// True when prepare identified the event as a self-echo (its
  /// `originatingHostId` matches the local host). Self-echoes are events the
  /// local host already wrote before sending; apply has nothing to do for
  /// any message family. The flag is the explicit contract that the
  /// per-family apply branches in `SyncEventProcessor._applyMessage` check
  /// before they expect their resolved-payload slots to be populated. None
  /// of the other slots (`journalEntity`, `resolvedOutboxBundle`, …) are
  /// populated when this is true, so per-family apply must short-circuit
  /// rather than dereference them.
  final bool isSelfEcho;

  /// Captured stale-descriptor error from the loader. Apply first checks
  /// whether the local version already supersedes the incoming one; if not,
  /// this error is rethrown so the pipeline schedules a retry.
  final FileSystemException? deferredStaleDescriptorError;

  /// Resolved entity when [syncMessage] is a [SyncAgentEntity]. Null means
  /// the prepare call returned null (inline missing, no jsonPath, invalid
  /// path, or descriptor-miss without a local file) — apply will treat it as
  /// a terminal skip.
  final AgentDomainEntity? resolvedAgentEntity;

  /// Whether the raw incoming agent-state payload explicitly carried the
  /// `pendingProjectActivityAt` slot. Null means the defensive fallback
  /// fired: prepare found no usable raw JSON to inspect (envelope missing
  /// or malformed). Top-level events and both outbox-bundle delivery paths
  /// (inline children and sidecar manifests) normally carry raw envelopes.
  final bool? pendingProjectActivityAtWasPresent;

  /// Resolved link when [syncMessage] is a [SyncAgentLink]. Same null
  /// semantics as [resolvedAgentEntity].
  final AgentLink? resolvedAgentLink;

  /// Resolved notification when [syncMessage] is a [SyncNotification].
  /// Null means prepare could not materialize a payload and apply will skip it.
  final NotificationEntity? resolvedNotification;

  /// Resolved dequeue-time outbox bundle when [syncMessage] is a
  /// [SyncOutboxBundle]. Each child carries its own [PreparedSyncEvent] so
  /// apply can recurse through the existing per-type pipeline. Null means
  /// the bundle payload could not be resolved and apply will skip it.
  final PreparedOutboxSyncBundle? resolvedOutboxBundle;

  /// Whether part of the event — an outbox bundle's manifest, or one of
  /// its children — did not decode in this build. What did decode is
  /// applied, and the queue then skips the event as undecodable, so its
  /// next start applies it whole again (every child tolerates replay).
  final bool hasUndecodableParts;
}
