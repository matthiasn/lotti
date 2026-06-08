// ignore_for_file: avoid_setters_without_getters

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart'
    show CheckedFromJsonException;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_update_result.dart';
import 'package:lotti/database/notifications_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/sync/agent_concurrent_resolver.dart';
import 'package:lotti/features/agents/sync/agent_lww_timestamp.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/notifications/scheduler/notification_scheduler.dart';
import 'package:lotti/features/settings/constants/theming_settings_keys.dart';
import 'package:lotti/features/sync/backfill/backfill_response_handler.dart';
import 'package:lotti/features/sync/matrix/journal_entity_dedup_cache.dart';
import 'package:lotti/features/sync/matrix/outbox_bundle_unpacker.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/smart_journal_entity_loader.dart';
import 'package:lotti/features/sync/matrix/sync_journal_entity_loader.dart';
import 'package:lotti/features/sync/matrix/utils/attachment_decoding.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/repository/sync_node_profile_repository.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:matrix/matrix.dart';

export 'package:lotti/features/sync/matrix/descriptor_downloader.dart';
export 'package:lotti/features/sync/matrix/smart_journal_entity_loader.dart';
export 'package:lotti/features/sync/matrix/sync_journal_entity_loader.dart';
export 'package:lotti/features/sync/matrix/vector_clock_validator.dart';

// Per-domain method bodies live in part files so they share the orchestrator's
// private state (dedup cache, sequence log service, agent repository) without
// dependency-injection plumbing for every collaborator.
part 'sync_event_processor_journal_handlers.dart';
part 'sync_event_processor_agent_handlers.dart';
part 'sync_event_processor_descriptor_cache.dart';
part 'sync_event_processor_notification_handlers.dart';
part 'sync_event_processor_outbox_bundle.dart';

/// Sync message bodies below this base64 length are decoded inline; anything
/// longer hands off to a worker isolate via `compute`. The break-even point
/// covers the `compute` spin-up cost on typical desktop hardware — small
/// pointer-style payloads (attachment descriptors) stay fast inline, while
/// large embedded-entity payloads (journal entries with linked entries,
/// long transcripts) decode off the UI isolate.
const int _inlineSyncDecodeThreshold = 4 * 1024;

/// Worker entry point for `compute`. Must be a top-level function so the
/// runtime can hand it to a background isolate. Decodes a base64-encoded
/// Matrix sync message body into its JSON map representation.
Map<String, dynamic> _decodeSyncEventPayload(String raw) {
  final decoded = utf8.decode(base64.decode(raw));
  return json.decode(decoded) as Map<String, dynamic>;
}

/// Test seam for [_decodeSyncEventPayload], the `compute` worker entry point.
/// Exposes the pure base64→utf8→json decode so the compute-offload path can be
/// pinned without spinning up a background isolate.
@visibleForTesting
Map<String, dynamic> decodeSyncEventPayloadForTesting(String raw) =>
    _decodeSyncEventPayload(raw);

/// Decodes timeline events from Matrix and persists them locally.
class SyncEventProcessor {
  SyncEventProcessor({
    required this._loggingService,
    required this._updateNotifications,
    required this._aiConfigRepository,
    required this._settingsDb,
    this._domainLogger,
    SyncJournalEntityLoader? journalEntityLoader,
    this._sequenceLogService,
    this._attachmentIndex,
    this._journalDb,
    this._vectorClockService,
    this._notificationsDb,
    this._notificationScheduler,
    this._syncNodeProfileRepository,
  }) : _journalEntityLoader =
           journalEntityLoader ?? const FileSyncJournalEntityLoader();

  final DomainLogger _loggingService;
  final DomainLogger? _domainLogger;
  final UpdateNotifications _updateNotifications;
  final AiConfigRepository _aiConfigRepository;
  final SettingsDb _settingsDb;
  final SyncJournalEntityLoader _journalEntityLoader;
  final SyncSequenceLogService? _sequenceLogService;
  final AttachmentIndex? _attachmentIndex;
  // Optional prepare-phase DB handle — only the outbox bundle resolver uses
  // it today, for a single bulk vector-clock dominance check across every
  // journal entity in the manifest. Apply-phase DB writes still flow
  // through the writer-transaction `journalDb` parameter (separate handle)
  // so this stays read-only by convention.
  final JournalDb? _journalDb;

  // Resolves the local host id used to short-circuit self-echoes during
  // the prepare phase. Optional so the existing test harnesses that
  // construct a [SyncEventProcessor] without a vector-clock service keep
  // working — they just lose the self-echo skip and process every event
  // (which is what they tested before).
  final VectorClockService? _vectorClockService;
  final NotificationsDb? _notificationsDb;
  final NotificationScheduler? _notificationScheduler;

  // Optional so existing test harnesses that construct a processor without
  // wiring the node-profile directory keep working. When null, incoming
  // `SyncSyncNodeProfile` messages are still acknowledged but the directory
  // upsert is skipped.
  final SyncNodeProfileRepository? _syncNodeProfileRepository;

  // Cached local host id. Resolved lazily on the first event that carries
  // an `originatingHostId`. Vector-clock host ids are stable for the life
  // of an install, so a single lookup per processor instance is enough.
  String? _localHostId;
  bool _localHostIdResolved = false;

  final JournalEntityDedupCache _dedupCache = JournalEntityDedupCache();

  // Dedupe concurrent descriptor fetches for the same attachment event.
  // Two text events that reference the same `jsonPath` during a single
  // catch-up or live-scan wave would otherwise each launch an independent
  // download/decrypt/decode for the identical Matrix attachment. Keyed by
  // `(indexKey, descriptorEventId)` so a newer descriptor for the same
  // path still gets its own fetch.
  final Map<String, Future<String?>> _inFlightDescriptorFetches =
      <String, Future<String?>>{};

  /// Backfill response handler. Set exactly once during DI boot via the
  /// public setter (declared `late final` so reads before assignment throw
  /// loudly instead of silently no-oping). The set-once assignment, rather
  /// than constructor injection, breaks the cycle
  /// `SyncEventProcessor` ← `MatrixService` ← `OutboxService` ←
  /// `BackfillResponseHandler` during get_it wiring.
  late final BackfillResponseHandler backfillResponseHandler;

  /// Agent repository, injected after construction to avoid circular
  /// dependency. When set, incoming agent entities and links are upserted
  /// directly (no outbox enqueue — prevents echo loops).
  AgentRepository? agentRepository;

  /// Wake orchestrator, injected after agent infrastructure starts. Used to
  /// remove subscriptions when an incoming sync message pauses or destroys
  /// an agent.
  WakeOrchestrator? wakeOrchestrator;

  void Function(SyncApplyDiagnostics diag)? applyObserver;

  /// Startup timestamp - events with backfill requests older than this
  /// are skipped to prevent re-processing on every restart.
  /// Set this to the read marker timestamp at app startup.
  num? startupTimestamp;

  void _trace(String message, {String? subDomain}) {
    final sub = subDomain ?? 'processor';
    final domainLogger = _domainLogger;
    if (domainLogger != null) {
      domainLogger.log(LogDomain.sync, message, subDomain: sub);
      return;
    }
    // Fallback for callers that did not inject a DomainLogger (e.g. tests).
    // Emitting directly under the `sync` domain keeps sync-file routing in
    // DomainLogger working so the log line still lands in the sync file.
    _loggingService.log(
      LogDomain.sync,
      message,
      subDomain: sub,
    );
  }

  set cachePurgeListener(void Function()? listener) {
    final loader = _journalEntityLoader;
    if (loader is SmartJournalEntityLoader) {
      loader.onCachePurge = listener;
    }
  }

  set descriptorPendingListener(void Function(String path)? listener) {
    final loader = _journalEntityLoader;
    if (loader is SmartJournalEntityLoader) {
      loader.onMissingDescriptorPath = listener;
    }
  }

  Future<void> process({
    required Event event,
    required JournalDb journalDb,
  }) async {
    final prepared = await prepare(event: event);
    if (prepared == null) return;
    await apply(prepared: prepared, journalDb: journalDb);
  }

  /// Phase 1 of the two-phase pipeline: decodes the envelope and resolves any
  /// file-backed payloads (journal entity JSON, agent entity/link
  /// descriptors). All network, gzip, and disk I/O happens here so the caller
  /// can run this phase **outside** a `JournalDb.transaction` and keep the
  /// SQLite writer lock short-lived during [apply].
  ///
  /// Returns `null` when the envelope cannot be decoded into a [SyncMessage]
  /// (malformed payload, unknown enum). Throws [FileSystemException] for
  /// retriable attachment failures (not-yet-available, stale-but-not-
  /// superseded) so the pipeline can schedule a retry.
  Future<PreparedSyncEvent?> prepare({required Event event}) async {
    try {
      final raw = event.text;
      // Base64-decoding + utf8-decoding + JSON parsing a large sync payload is
      // synchronous CPU work. A catch-up slice routinely carries dozens of
      // these events in one transaction; done inline they drop UI frames and
      // extend the writer-lock hold time. Offload to a worker isolate when
      // the base64 body is large enough that the compute overhead is paid
      // back by the saved main-isolate time. Small payloads (attachment
      // pointers, short messages) stay inline.
      final Map<String, dynamic> messageJson;
      if (raw.length >= _inlineSyncDecodeThreshold) {
        messageJson = await compute(_decodeSyncEventPayload, raw);
      } else {
        final decoded = utf8.decode(base64.decode(raw));
        messageJson = json.decode(decoded) as Map<String, dynamic>;
      }
      final SyncMessage syncMessage;
      try {
        syncMessage = SyncMessage.fromJson(messageJson);
        // Rethrow anything that isn't a deserialization error.
        // ArgumentError comes from $enumDecode for unknown enum values,
        // FormatException from malformed JSON sub-fields.
      } catch (e) {
        if (e is! ArgumentError &&
            e is! FormatException &&
            e is! CheckedFromJsonException) {
          rethrow;
        }
        _trace(
          'skipping undeserializable sync message: $e '
          'eventId=${event.eventId}',
          subDomain: 'processor.skipUnrecoverable',
        );
        return null;
      }

      // Old backfill responses are NEVER skipped. The handleBackfillResponse
      // method is idempotent — at worst it stores a hint and does a no-op
      // verification. Skipping responses when the counter doesn't exist in
      // the local sequence log caused a deadlock: device A requests counter X,
      // device B responds, but A's sequence log doesn't have counter X for
      // its own hostId (gap detection skips own host), so A drops the response
      // and the counter stays in "requested" state forever.
      //
      // Old backfill requests are also not skipped (see above).

      _trace(
        'processing ${event.originServerTs} ${event.eventId}',
        subDomain: 'processor.SyncEventProcessor',
      );

      // `await` so exceptions from prepare flow through the `catch` below
      // (Dart does not hook `catch` onto a returned future without it).
      return await _prepareForMessage(event: event, syncMessage: syncMessage);
    } catch (error, stackTrace) {
      if (error is! FileSystemException) {
        _loggingService.error(
          LogDomain.sync,
          error,
          stackTrace: stackTrace,
          subDomain: 'SyncEventProcessor',
        );
      }
      rethrow;
    }
  }

  /// Phase 2 of the two-phase pipeline: applies the already-resolved
  /// [prepared] event to local stores. This is pure DB work plus in-memory
  /// notifications — callers run it **inside** a `JournalDb.transaction` so
  /// per-slice writes coalesce into a single stream emission without holding
  /// the writer lock for any attachment I/O.
  Future<SyncApplyDiagnostics?> apply({
    required PreparedSyncEvent prepared,
    required JournalDb journalDb,
  }) async {
    try {
      final diag = await _applyMessage(
        prepared: prepared,
        journalDb: journalDb,
      );
      if (diag != null) {
        applyObserver?.call(diag);
      }
      return diag;
    } catch (error, stackTrace) {
      if (error is! FileSystemException) {
        _loggingService.error(
          LogDomain.sync,
          error,
          stackTrace: stackTrace,
          subDomain: 'SyncEventProcessor',
        );
      }
      rethrow;
    }
  }

  bool _isStaleDescriptorError(FileSystemException error) {
    final message = error.message;
    return message.contains('stale attachment json');
  }

  // ---------------------------------------------------------------------------
  // Prepare-phase helpers (I/O only, no DB writes)
  // ---------------------------------------------------------------------------

  /// Returns true when [message] carries a non-null `originatingHostId`
  /// equal to the local host's vector-clock id — i.e. the event is one we
  /// just sent looping back through `/sync` or arriving via catch-up. The
  /// local host id is resolved once per processor instance (vector-clock
  /// host ids are stable for the lifetime of an install) and cached.
  Future<bool> _isLocalSelfEcho(SyncMessage message) async {
    final origin = _originatingHostIdOf(message);
    if (origin == null) return false;
    final localId = await _resolveLocalHostId();
    if (localId == null) return false;
    return origin == localId;
  }

  Future<String?> _resolveLocalHostId() async {
    if (_localHostIdResolved) return _localHostId;
    final service = _vectorClockService;
    if (service == null) {
      _localHostIdResolved = true;
      return null;
    }
    try {
      _localHostId = await service.getHost();
    } catch (e, st) {
      _loggingService.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'processor.selfEcho.hostLookup',
      );
      _localHostId = null;
    }
    _localHostIdResolved = true;
    return _localHostId;
  }

  /// Returns the `originatingHostId` field for any [SyncMessage] family
  /// that carries one. Families without the field (`SyncEntityDefinition`,
  /// `SyncAiConfig`, `SyncAiConfigDelete`, `SyncThemingSelection`,
  /// `SyncBackfillRequest`, `SyncBackfillResponse`) return null and bypass
  /// the self-echo check.
  static String? _originatingHostIdOf(SyncMessage message) => switch (message) {
    final SyncJournalEntity m => m.originatingHostId,
    final SyncEntryLink m => m.originatingHostId,
    final SyncConfigFlag m => m.originatingHostId,
    final SyncAgentEntity m => m.originatingHostId,
    final SyncAgentLink m => m.originatingHostId,
    final SyncNotification m => m.originatingHostId,
    final SyncNotificationStateUpdate m => m.originatingHostId,
    final SyncAgentBundle m => m.originatingHostId,
    final SyncOutboxBundle m => m.originatingHostId,
    _ => null,
  };

  /// Dispatches the prepare phase per sync message family. Only
  /// [SyncJournalEntity], [SyncAgentEntity], and [SyncAgentLink] need I/O
  /// (attachment resolution); every other family is a passthrough.
  Future<PreparedSyncEvent> _prepareForMessage({
    required Event event,
    required SyncMessage syncMessage,
  }) async {
    // Self-echo short-circuit: every Matrix event the local host sends
    // loops back through `/sync` (and again on catch-up after a
    // reconnect). The `SentEventRegistry` already drops most of those at
    // the live ingress, but it has a 5-minute TTL and only covers the
    // live arrival path — bulk re-sends and catch-up after a stretch of
    // disconnect can leak self-echoes through to prepare. Compare the
    // envelope's `originatingHostId` (stamped by `MatrixMessageSender`)
    // against the local host id and skip the heavy prepare work for
    // anything we sent. The apply phase is idempotent under VC dedup
    // anyway; this just stops us from burning CPU on a manifest decode,
    // descriptor download, or per-child saveJson for our own data.
    if (await _isLocalSelfEcho(syncMessage)) {
      _trace(
        'selfEcho.skip type=${syncMessage.runtimeType}',
        subDomain: 'processor.selfEcho',
      );
      return PreparedSyncEvent._(
        event: event,
        syncMessage: syncMessage,
        isSelfEcho: true,
      );
    }
    switch (syncMessage) {
      case final SyncJournalEntity msg:
        return _prepareJournalEntity(event: event, syncMessage: msg);
      case final SyncAgentEntity msg:
        final resolved = await _resolveAgentEntity(msg);
        return PreparedSyncEvent._(
          event: event,
          syncMessage: msg,
          resolvedAgentEntity: resolved,
        );
      case final SyncAgentLink msg:
        final resolved = await _resolveAgentLink(msg);
        return PreparedSyncEvent._(
          event: event,
          syncMessage: msg,
          resolvedAgentLink: resolved,
        );
      case final SyncNotification msg:
        final resolved = await _resolveNotification(msg);
        return PreparedSyncEvent._(
          event: event,
          syncMessage: msg,
          resolvedNotification: resolved,
        );
      case final SyncAgentBundle msg:
        // Legacy wire variant — agent wake-cycle bundling has been
        // removed. The variant is retained on the wire so messages from
        // peers that still ship it parse without error, but we no longer
        // resolve or apply them: the bundle's children are recorded
        // individually in the sender's sequence log, so backfill picks
        // them up via the per-entity / per-link path. Logging at info so
        // a sudden reappearance in production surfaces.
        _trace(
          'legacyAgentBundle.skip eventId=${event.eventId} '
          'agentId=${msg.agentId} wakeRunKey=${msg.wakeRunKey}',
          subDomain: 'processor.resolve.legacyAgentBundle',
        );
        return PreparedSyncEvent._(event: event, syncMessage: msg);
      case final SyncOutboxBundle msg:
        final resolved = await _outboxBundleUnpacker.prepare(
          event: event,
          msg: msg,
          resolveSidecar: _resolveOutboxBundleManifest,
          prepareChild: (childEvent, childMsg) =>
              _prepareForMessage(event: childEvent, syncMessage: childMsg),
        );
        return PreparedSyncEvent._(
          event: event,
          syncMessage: msg,
          resolvedOutboxBundle: resolved,
        );
      default:
        return PreparedSyncEvent._(event: event, syncMessage: syncMessage);
    }
  }

  @visibleForTesting
  Future<SyncOutboxBundle?> resolveOutboxBundleManifestForTesting(
    String? jsonPath,
  ) => _resolveOutboxBundleManifest(jsonPath);

  late final OutboxBundleUnpacker _outboxBundleUnpacker = OutboxBundleUnpacker(
    loggingService: _loggingService,
    trace: _trace,
  );

  Future<SyncApplyDiagnostics?> _applyMessage({
    required PreparedSyncEvent prepared,
    required JournalDb journalDb,
    Map<String, AgentDomainEntity?>? prefetchedAgentEntitiesById,
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
      case SyncEntityDefinition(:final entityDefinition):
        await journalDb.upsertEntityDefinition(entityDefinition);
        final typeNotification = switch (entityDefinition) {
          CategoryDefinition() => categoriesNotification,
          HabitDefinition() => habitsNotification,
          DashboardDefinition() => dashboardsNotification,
          MeasurableDataType() => measurablesNotification,
          LabelDefinition() => labelsNotification,
        };
        _updateNotifications.notify(
          {entityDefinition.id, typeNotification},
          fromSync: true,
        );
        return null;
      case SyncAiConfig(:final aiConfig):
        await _aiConfigRepository.saveConfig(
          aiConfig,
          fromSync: true,
        );
        return null;
      case SyncAiConfigDelete(:final id):
        await _aiConfigRepository.deleteConfig(
          id,
          fromSync: true,
        );
        return null;
      case SyncConfigFlag(:final name, :final description, :final status):
        final configFlag = ConfigFlag(
          name: name,
          description: description,
          status: status,
        );
        await journalDb.upsertConfigFlag(configFlag);
        if (configFlag.name == 'private') {
          _updateNotifications.notify(
            {privateToggleNotification},
            fromSync: true,
          );
        }
        return null;
      case SyncThemingSelection(
        :final lightThemeName,
        :final darkThemeName,
        :final themeMode,
        :final updatedAt,
      ):
        try {
          // Check if incoming update is newer than local
          final localUpdatedAtStr = await _settingsDb.itemByKey(
            themePrefsUpdatedAtKey,
          );
          final localUpdatedAt = localUpdatedAtStr != null
              ? int.tryParse(localUpdatedAtStr)
              : 0;

          if (updatedAt < (localUpdatedAt ?? 0)) {
            _trace(
              'themingSync.ignored.stale incoming=$updatedAt local=$localUpdatedAt',
              subDomain: 'processor.apply',
            );
            _loggingService.log(
              LogDomain.theming,
              'themingSync.ignored.stale incoming=$updatedAt local=$localUpdatedAt',
              subDomain: 'apply',
            );
            return null;
          }

          // Normalize themeMode value
          final normalizedMode =
              EnumToString.fromString(
                ThemeMode.values,
                themeMode,
              ) ??
              ThemeMode.system;

          // Apply all three settings
          await _settingsDb.saveSettingsItem(
            lightSchemeNameKey,
            lightThemeName,
          );
          await _settingsDb.saveSettingsItem(
            darkSchemeNameKey,
            darkThemeName,
          );
          await _settingsDb.saveSettingsItem(
            themeModeKey,
            EnumToString.convertToString(normalizedMode),
          );
          await _settingsDb.saveSettingsItem(
            themePrefsUpdatedAtKey,
            updatedAt.toString(),
          );

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
        }
        return null;
      case SyncBackfillRequest():
        // Handle backfill request - another device is asking for a missing entry
        await backfillResponseHandler.handleBackfillRequest(syncMessage);
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
          prefetchedAgentEntitiesById: prefetchedAgentEntitiesById,
        );
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
        await _withPrefetchedAgentEntities(
          bundle: bundle,
          apply: (prefetchedAgentEntitiesById) => _outboxBundleUnpacker.apply(
            bundle: bundle,
            applyChild: (child) => _applyMessage(
              prepared: child,
              journalDb: journalDb,
              prefetchedAgentEntitiesById: prefetchedAgentEntitiesById,
            ),
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
}

Future<T> runWithDeferredMissingEntryNudges<T>(
  SyncEventProcessor processor,
  Future<T> Function() action,
) {
  // Production always uses the concrete SyncEventProcessor. Tests often inject
  // mock implementations of its interface; fall back to the plain action there
  // so the helper does not force new stubs across unrelated test suites.
  if (processor.runtimeType != SyncEventProcessor) {
    return action();
  }
  final sequenceLogService = processor._sequenceLogService;
  if (sequenceLogService == null) {
    return action();
  }
  return sequenceLogService.runWithDeferredMissingEntries(action);
}

class SyncApplyDiagnostics {
  SyncApplyDiagnostics({
    required this.eventId,
    required this.payloadType,
    required this.vectorClock,
    required this.conflictStatus,
    required this.applied,
    this.skipReason,
  });

  final String eventId;
  final String payloadType;
  final Object? vectorClock;
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
    this.resolvedAgentLink,
    this.resolvedNotification,
    this.resolvedOutboxBundle,
  });

  PreparedSyncEvent._({
    required this.event,
    required this.syncMessage,
    this.journalEntity,
    this.isDuplicateJournalEntity = false,
    this.isSelfEcho = false,
    this.deferredStaleDescriptorError,
    this.resolvedAgentEntity,
    this.resolvedAgentLink,
    this.resolvedNotification,
    this.resolvedOutboxBundle,
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
  /// per-family apply branches in [SyncEventProcessor._applyMessage] check
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
}
