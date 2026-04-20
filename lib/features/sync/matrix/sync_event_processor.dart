// ignore_for_file: one_member_abstracts, avoid_setters_without_getters

import 'dart:async';
import 'dart:collection';
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
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_update_result.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/settings/constants/theming_settings_keys.dart';
import 'package:lotti/features/sync/backfill/backfill_response_handler.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/utils/atomic_write.dart';
import 'package:lotti/features/sync/matrix/utils/attachment_decoding.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:matrix/matrix.dart';
import 'package:path/path.dart' as path;

enum VectorClockDecision {
  accept,
  retryAfterPurge,
  staleAfterRefresh,
  circuitBreaker,
  missingVectorClock,
}

class VectorClockValidator {
  VectorClockValidator({required LoggingService loggingService})
    : _logging = loggingService;

  static const int maxStaleDescriptorFailures = 5;

  final LoggingService _logging;
  final Map<String, int> _staleDescriptorFailures = <String, int>{};

  VectorClockDecision evaluate({
    required String jsonPath,
    required VectorClock incomingVectorClock,
    required JournalEntity candidate,
    required int attempt,
  }) {
    final candidateVc = candidate.meta.vectorClock;
    if (candidateVc == null) {
      _logging.captureEvent(
        'smart.fetch.missing_vc path=$jsonPath expected=$incomingVectorClock',
        domain: 'MATRIX_SERVICE',
        subDomain: 'SmartLoader.fetch',
      );
      reset(jsonPath);
      return VectorClockDecision.missingVectorClock;
    }

    final status = VectorClock.compare(candidateVc, incomingVectorClock);
    if (status == VclockStatus.b_gt_a) {
      final failures = (_staleDescriptorFailures[jsonPath] ?? 0) + 1;
      _staleDescriptorFailures[jsonPath] = failures;
      if (failures >= maxStaleDescriptorFailures) {
        _logging.captureEvent(
          'smart.fetch.stale_vc.breaker path=$jsonPath retries=$failures limit=$maxStaleDescriptorFailures',
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetch',
        );
        return VectorClockDecision.circuitBreaker;
      }
      if (attempt == 0) {
        _logging.captureEvent(
          'smart.fetch.stale_vc path=$jsonPath expected=$incomingVectorClock got=$candidateVc',
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetch',
        );
        return VectorClockDecision.retryAfterPurge;
      }
      _logging.captureEvent(
        'smart.fetch.stale_vc.pending path=$jsonPath expected=$incomingVectorClock got=$candidateVc',
        domain: 'MATRIX_SERVICE',
        subDomain: 'SmartLoader.fetch',
      );
      return VectorClockDecision.staleAfterRefresh;
    }

    reset(jsonPath);
    return VectorClockDecision.accept;
  }

  void reset(String jsonPath) {
    _staleDescriptorFailures.remove(jsonPath);
  }
}

class DescriptorDownloadResult {
  const DescriptorDownloadResult({
    required this.json,
    required this.bytesLength,
  });

  final String json;
  final int bytesLength;
}

class DescriptorDownloader {
  DescriptorDownloader({
    required LoggingService loggingService,
    required VectorClockValidator validator,
    this.onCachePurge,
  }) : _logging = loggingService,
       _validator = validator;

  static const int maxDescriptorDownloadAttempts = 2;

  final LoggingService _logging;
  final VectorClockValidator _validator;
  void Function()? onCachePurge;

  Future<DescriptorDownloadResult> download({
    required Event descriptorEvent,
    required VectorClock incomingVectorClock,
    required String jsonPath,
  }) async {
    for (var attempt = 0; attempt < maxDescriptorDownloadAttempts; attempt++) {
      final matrixFile = await descriptorEvent.downloadAndDecryptAttachment();
      final downloadedBytes = matrixFile.bytes;
      if (downloadedBytes.isEmpty) {
        throw const FileSystemException('empty attachment bytes');
      }
      final bytes = await decodeAttachmentBytes(
        event: descriptorEvent,
        downloadedBytes: downloadedBytes,
        relativePath: jsonPath,
        logging: _logging,
      );
      final candidateJson = utf8.decode(bytes);
      final decoded = json.decode(candidateJson) as Map<String, dynamic>;
      final candidate = JournalEntity.fromJson(decoded);
      final decision = _validator.evaluate(
        jsonPath: jsonPath,
        incomingVectorClock: incomingVectorClock,
        candidate: candidate,
        attempt: attempt,
      );
      switch (decision) {
        case VectorClockDecision.accept:
          _validator.reset(jsonPath);
          return DescriptorDownloadResult(
            json: candidateJson,
            bytesLength: bytes.length,
          );
        case VectorClockDecision.retryAfterPurge:
          final purged = await _maybePurgeCachedDescriptor(
            descriptorEvent,
            jsonPath,
          );
          if (purged) {
            onCachePurge?.call();
          }
          _logging.captureEvent(
            'smart.fetch.stale_vc.refresh path=$jsonPath',
            domain: 'MATRIX_SERVICE',
            subDomain: 'SmartLoader.fetch',
          );
          continue;
        case VectorClockDecision.staleAfterRefresh:
          throw const FileSystemException(
            'stale attachment json after refresh',
          );
        case VectorClockDecision.circuitBreaker:
          throw const FileSystemException(
            'stale attachment json (circuit breaker)',
          );
        case VectorClockDecision.missingVectorClock:
          throw const FileSystemException('missing attachment vector clock');
      }
    }

    throw const FileSystemException('stale attachment json');
  }

  Future<bool> _maybePurgeCachedDescriptor(
    Event event,
    String jsonPath,
  ) async {
    try {
      final uri = event.attachmentOrThumbnailMxcUrl();
      if (uri == null) {
        _logging.captureEvent(
          'smart.fetch.stale_vc.purge.skipped path=$jsonPath reason=no_mxc',
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetch',
        );
        return false;
      }
      await event.room.client.database.deleteFile(uri);
      _logging.captureEvent(
        'smart.fetch.stale_vc.purge path=$jsonPath mxc=$uri',
        domain: 'MATRIX_SERVICE',
        subDomain: 'SmartLoader.fetch',
      );
      return true;
    } catch (e, st) {
      _logging.captureException(
        e,
        domain: 'MATRIX_SERVICE',
        subDomain: 'SmartLoader.purge',
        stackTrace: st,
      );
      return false;
    }
  }
}

/// Abstraction for loading journal entities and related attachments when
/// processing sync messages.
abstract class SyncJournalEntityLoader {
  Future<JournalEntity> load({
    required String jsonPath,
    VectorClock? incomingVectorClock,
  });
}

/// Loads journal entities from the documents directory on disk.
class FileSyncJournalEntityLoader implements SyncJournalEntityLoader {
  const FileSyncJournalEntityLoader();

  @override
  Future<JournalEntity> load({
    required String jsonPath,
    VectorClock? incomingVectorClock,
  }) async {
    final candidateFile = resolveJsonCandidateFile(jsonPath);
    final docPath = path.normalize(getDocumentsDirectory().path);
    final jsonRelative = path.relative(candidateFile.path, from: docPath);
    return readEntityFromJson(jsonRelative);
  }
}

/// Smart loader that ensures JSON presence/currency based on an incoming vector
/// clock. It uses the AttachmentIndex to fetch missing/stale JSON and writes
/// atomically before parsing.
class SmartJournalEntityLoader implements SyncJournalEntityLoader {
  SmartJournalEntityLoader({
    required AttachmentIndex attachmentIndex,
    required LoggingService loggingService,
    void Function()? onCachePurge,
  }) : _attachmentIndex = attachmentIndex,
       _logging = loggingService {
    _vectorClockValidator = VectorClockValidator(
      loggingService: loggingService,
    );
    _descriptorDownloader = DescriptorDownloader(
      loggingService: loggingService,
      validator: _vectorClockValidator,
      onCachePurge: onCachePurge,
    );
  }

  final AttachmentIndex _attachmentIndex;
  final LoggingService _logging;
  late final VectorClockValidator _vectorClockValidator;
  late final DescriptorDownloader _descriptorDownloader;

  set onCachePurge(void Function()? listener) {
    _descriptorDownloader.onCachePurge = listener;
  }

  void Function(String path)? _onMissingDescriptorPath;

  set onMissingDescriptorPath(void Function(String path)? listener) {
    _onMissingDescriptorPath = listener;
  }

  @override
  Future<JournalEntity> load({
    required String jsonPath,
    VectorClock? incomingVectorClock,
  }) async {
    final targetFile = resolveJsonCandidateFile(jsonPath);
    // Build a canonical index key once and reuse it to avoid inconsistencies
    // across platforms (Windows vs. POSIX). The key always uses forward slashes
    // and has a single leading '/'. Any leading '/' or '\\' characters are trimmed.
    final indexKey = _buildIndexKey(jsonPath);
    // If we have an incoming vector clock, decide whether a fetch is needed.
    if (incomingVectorClock != null) {
      try {
        final local = await const FileSyncJournalEntityLoader().load(
          jsonPath: jsonPath,
        );
        final localVc = local.meta.vectorClock;
        if (localVc != null) {
          final status = VectorClock.compare(localVc, incomingVectorClock);
          if (status == VclockStatus.a_gt_b || status == VclockStatus.equal) {
            return local; // local is current or newer; no fetch
          }
        }
      } on FileSystemException {
        // Expected when text arrives before the descriptor: treat as a local miss.
        // We fetch via AttachmentIndex below; log as an info event rather than exception.
        _logging.captureEvent(
          'smart.local.miss path=$jsonPath',
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.localMiss',
        );
      } catch (e, st) {
        // Unexpected read failure – keep as exception for diagnostics.
        _logging.captureException(
          e,
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.localRead',
          stackTrace: st,
        );
      }

      // Resolve descriptor via AttachmentIndex
      final eventForPath = _attachmentIndex.find(indexKey);
      if (eventForPath == null) {
        // Descriptor not yet available; let caller retry later.
        _logging.captureEvent(
          'smart.fetch.miss path=$jsonPath key=$indexKey',
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetch',
        );
        throw FileSystemException(
          'attachment descriptor not yet available',
          jsonPath,
        );
      }
      try {
        final descriptor = await _descriptorDownloader.download(
          descriptorEvent: eventForPath,
          incomingVectorClock: incomingVectorClock,
          jsonPath: jsonPath,
        );
        await saveJson(targetFile.path, descriptor.json);
        _logging.captureEvent(
          'smart.json.written path=$jsonPath bytes=${descriptor.bytesLength}',
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetch',
        );
      } catch (e, st) {
        _logging.captureException(
          e,
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetchJson',
          stackTrace: st,
        );
        rethrow;
      }
    } else {
      // No incoming vector clock: fetch if file is missing/empty, else read.
      var needsFetch = false;
      try {
        // ignore: avoid_slow_async_io
        if (!await targetFile.exists()) {
          needsFetch = true;
        } else {
          final len = await targetFile.length();
          needsFetch = len == 0;
        }
      } catch (_) {
        needsFetch = true;
      }
      if (needsFetch) {
        final eventForPath = _attachmentIndex.find(indexKey);
        if (eventForPath == null) {
          _logging.captureEvent(
            'smart.fetch.miss(noVc) path=$jsonPath key=$indexKey',
            domain: 'MATRIX_SERVICE',
            subDomain: 'SmartLoader.fetch',
          );
          throw FileSystemException(
            'attachment descriptor not yet available',
            jsonPath,
          );
        }
        try {
          final matrixFile = await eventForPath.downloadAndDecryptAttachment();
          final downloadedBytes = matrixFile.bytes;
          if (downloadedBytes.isEmpty) {
            throw const FileSystemException('empty attachment bytes');
          }
          final bytes = await decodeAttachmentBytes(
            event: eventForPath,
            downloadedBytes: downloadedBytes,
            relativePath: jsonPath,
            logging: _logging,
          );
          final jsonString = utf8.decode(bytes);
          await saveJson(targetFile.path, jsonString);
          _logging.captureEvent(
            'smart.json.written(noVc) path=$jsonPath bytes=${bytes.length}',
            domain: 'MATRIX_SERVICE',
            subDomain: 'SmartLoader.fetch',
          );
        } catch (e, st) {
          _logging.captureException(
            e,
            domain: 'MATRIX_SERVICE',
            subDomain: 'SmartLoader.fetchJson.noVc',
            stackTrace: st,
          );
          rethrow;
        }
      }
    }

    // Read and return the entity from disk (either pre-existing or freshly written).
    final entity = await const FileSyncJournalEntityLoader().load(
      jsonPath: jsonPath,
    );

    // Missing media must not block entity application. The JSON payload is the
    // authoritative state; referenced audio/image files can arrive later via
    // the attachment pipeline or descriptor catch-up.
    await _ensureMediaOnMissing(entity);
    return entity;
  }

  String _buildIndexKey(String rawPath) => normalizeAttachmentIndexKey(rawPath);

  Future<void> _ensureMediaOnMissing(JournalEntity e) async {
    switch (e) {
      case JournalImage():
        await _ensureMediaFile(getRelativeImagePath(e), mediaType: 'image');
      case JournalAudio():
        await _ensureMediaFile(
          AudioUtils.getRelativeAudioPath(e),
          mediaType: 'audio',
        );
      default:
        return; // No media to ensure
    }
  }

  Future<void> _ensureMediaFile(
    String relativePath, {
    String? mediaType,
  }) async {
    final docDir = getDocumentsDirectory();
    final rp = relativePath;
    // Trim any leading '/' or '\\' to avoid accidental absolute paths on Windows.
    final rpRel = rp.replaceFirst(RegExp(r'^[\\/]+'), '');
    final fp = path.normalize(path.join(docDir.path, rpRel));
    final f = File(fp);
    try {
      // ignore: avoid_slow_async_io
      if (await f.exists()) {
        final len = await f.length();
        if (len > 0) return; // present
      }
    } catch (e, st) {
      _logging.captureException(
        e,
        domain: 'MATRIX_SERVICE',
        subDomain: 'SmartLoader.pathCheck',
        stackTrace: st,
      );
    }

    final descriptorKey = _buildIndexKey(rp);
    final ev = _attachmentIndex.find(descriptorKey);
    if (ev == null) {
      _logging.captureEvent(
        'smart.media.miss path=$rp key=$descriptorKey',
        domain: 'MATRIX_SERVICE',
        subDomain: 'SmartLoader.fetchMedia',
      );
      _onMissingDescriptorPath?.call(descriptorKey);
      return;
    }
    try {
      final file = await ev.downloadAndDecryptAttachment();
      final downloadedBytes = file.bytes;
      if (downloadedBytes.isEmpty) {
        throw const FileSystemException('empty attachment bytes');
      }
      final bytes = await decodeAttachmentBytes(
        event: ev,
        downloadedBytes: downloadedBytes,
        relativePath: rp,
        logging: _logging,
      );
      await atomicWriteBytes(
        bytes: bytes,
        filePath: fp,
        logging: _logging,
        subDomain: 'SmartLoader.writeMedia',
      );
    } catch (e, st) {
      _logging.captureException(
        e,
        domain: 'MATRIX_SERVICE',
        subDomain: 'SmartLoader.fetchMedia',
        stackTrace: st,
      );
      _onMissingDescriptorPath?.call(descriptorKey);
    }
  }
}

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

/// Decodes timeline events from Matrix and persists them locally.
class SyncEventProcessor {
  SyncEventProcessor({
    required LoggingService loggingService,
    required UpdateNotifications updateNotifications,
    required AiConfigRepository aiConfigRepository,
    required SettingsDb settingsDb,
    DomainLogger? domainLogger,
    SyncJournalEntityLoader? journalEntityLoader,
    SyncSequenceLogService? sequenceLogService,
    AttachmentIndex? attachmentIndex,
    this.backfillResponseHandler,
  }) : _loggingService = loggingService,
       _domainLogger = domainLogger,
       _updateNotifications = updateNotifications,
       _aiConfigRepository = aiConfigRepository,
       _settingsDb = settingsDb,
       _journalEntityLoader =
           journalEntityLoader ?? const FileSyncJournalEntityLoader(),
       _sequenceLogService = sequenceLogService,
       _attachmentIndex = attachmentIndex;

  final LoggingService _loggingService;
  final DomainLogger? _domainLogger;
  final UpdateNotifications _updateNotifications;
  final AiConfigRepository _aiConfigRepository;
  final SettingsDb _settingsDb;
  final SyncJournalEntityLoader _journalEntityLoader;
  final SyncSequenceLogService? _sequenceLogService;
  final AttachmentIndex? _attachmentIndex;

  static const int _recentJournalEntityLimit = 500;
  final LinkedHashMap<String, String> _recentJournalEntityFingerprints =
      LinkedHashMap<String, String>();

  // Dedupe concurrent descriptor fetches for the same attachment event.
  // Two text events that reference the same `jsonPath` during a single
  // catch-up or live-scan wave would otherwise each launch an independent
  // download/decrypt/decode for the identical Matrix attachment. Keyed by
  // `(indexKey, descriptorEventId)` so a newer descriptor for the same
  // path still gets its own fetch.
  final Map<String, Future<String?>> _inFlightDescriptorFetches =
      <String, Future<String?>>{};

  /// Backfill response handler, injected after construction
  /// to resolve circular dependency in DI setup.
  BackfillResponseHandler? backfillResponseHandler;

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
      domainLogger.log(LogDomains.sync, message, subDomain: sub);
      return;
    }
    // Fallback for callers that did not inject a DomainLogger (e.g. tests).
    // Emitting directly under the `sync` domain keeps sync-file routing in
    // LoggingService working so the log line still lands in the sync file.
    _loggingService.captureEvent(
      message,
      domain: LogDomains.sync,
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

      // Await here so exceptions from prepare flow through the try/catch
      // below instead of escaping the block unhandled (Dart does not hook
      // `catch` onto a returned future without an explicit `await`).
      return await _prepareForMessage(
        event: event,
        syncMessage: syncMessage,
        loader: _journalEntityLoader,
      );
    } catch (error, stackTrace) {
      if (error is! FileSystemException) {
        _loggingService.captureException(
          error,
          domain: 'MATRIX_SERVICE',
          subDomain: 'SyncEventProcessor',
          stackTrace: stackTrace,
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
        _loggingService.captureException(
          error,
          domain: 'MATRIX_SERVICE',
          subDomain: 'SyncEventProcessor',
          stackTrace: stackTrace,
        );
      }
      rethrow;
    }
  }

  bool _isStaleDescriptorError(FileSystemException error) {
    final message = error.message;
    return message.contains('stale attachment json');
  }

  bool _isDuplicateJournalEntity(String entryId, VectorClock? vectorClock) {
    if (vectorClock == null) return false;
    final fingerprint = _vectorClockFingerprint(vectorClock);
    final cached = _recentJournalEntityFingerprints[entryId];
    if (cached == null || cached != fingerprint) {
      return false;
    }
    _recentJournalEntityFingerprints.remove(entryId);
    _recentJournalEntityFingerprints[entryId] = fingerprint;
    return true;
  }

  void _markJournalEntityProcessed(String entryId, VectorClock? vectorClock) {
    if (vectorClock == null) return;
    final fingerprint = _vectorClockFingerprint(vectorClock);
    _recentJournalEntityFingerprints.remove(entryId);
    _recentJournalEntityFingerprints[entryId] = fingerprint;
    if (_recentJournalEntityFingerprints.length > _recentJournalEntityLimit) {
      _recentJournalEntityFingerprints.remove(
        _recentJournalEntityFingerprints.keys.first,
      );
    }
  }

  String _vectorClockFingerprint(VectorClock vectorClock) {
    final entries = vectorClock.vclock.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((entry) => '${entry.key}:${entry.value}').join('|');
  }

  Future<int> _processEmbeddedEntryLinks({
    required List<EntryLink>? entryLinks,
    required JournalDb journalDb,
  }) async {
    var processedLinksCount = 0;
    if (entryLinks == null || entryLinks.isEmpty) {
      return processedLinksCount;
    }
    final affectedIds = <String>{};
    for (final link in entryLinks) {
      try {
        final linkRows = await journalDb.upsertEntryLink(link);
        if (linkRows > 0) {
          processedLinksCount++;
          _trace(
            'apply entryLink.embedded from=${link.fromId} to=${link.toId} rows=$linkRows',
            subDomain: 'processor.apply.entryLink.embedded',
          );
        }
        affectedIds.addAll({link.fromId, link.toId});
      } catch (e, st) {
        _loggingService.captureException(
          e,
          domain: 'MATRIX_SERVICE',
          subDomain: 'apply.entryLink.embedded',
          stackTrace: st,
        );
      }
    }
    if (affectedIds.isNotEmpty) {
      _updateNotifications.notify(affectedIds, fromSync: true);
    }
    return processedLinksCount;
  }

  Future<SyncApplyDiagnostics?> _maybeSkipSupersededStaleDescriptor({
    required Event event,
    required SyncJournalEntity syncMessage,
    required JournalDb journalDb,
    required List<EntryLink>? entryLinks,
  }) async {
    final incomingVc = syncMessage.vectorClock;
    if (incomingVc == null) {
      return null;
    }
    JournalEntity? existing;
    try {
      existing = await journalDb.journalEntityById(syncMessage.id);
    } catch (e, st) {
      _loggingService.captureException(
        e,
        domain: 'MATRIX_SERVICE',
        subDomain: 'apply.staleDescriptor.lookup',
        stackTrace: st,
      );
      return null;
    }
    final existingVc = existing?.meta.vectorClock;
    if (existingVc == null) {
      return null;
    }
    VclockStatus status;
    try {
      status = VectorClock.compare(existingVc, incomingVc);
    } catch (e, st) {
      _loggingService.captureException(
        e,
        domain: 'MATRIX_SERVICE',
        subDomain: 'apply.staleDescriptor.compare',
        stackTrace: st,
      );
      return null;
    }
    if (status != VclockStatus.a_gt_b && status != VclockStatus.equal) {
      return null;
    }

    final processedLinksCount = await _processEmbeddedEntryLinks(
      entryLinks: entryLinks,
      journalDb: journalDb,
    );

    final diag = SyncApplyDiagnostics(
      eventId: event.eventId,
      payloadType: 'journalEntity',
      vectorClock: incomingVc.toJson(),
      conflictStatus: status.toString(),
      applied: false,
      skipReason: JournalUpdateSkipReason.olderOrEqual,
    );
    _trace(
      'apply journalEntity skipped staleDescriptor eventId=${event.eventId} id=${syncMessage.id} status=${diag.conflictStatus} embeddedLinks=$processedLinksCount/${entryLinks?.length ?? 0}',
      subDomain: 'processor.apply',
    );

    if (_sequenceLogService != null && syncMessage.originatingHostId != null) {
      try {
        final gaps = await _sequenceLogService.recordReceivedEntry(
          entryId: syncMessage.id,
          vectorClock: incomingVc,
          originatingHostId: syncMessage.originatingHostId!,
          coveredVectorClocks: syncMessage.coveredVectorClocks,
          jsonPath: syncMessage.jsonPath,
        );
        if (gaps.isNotEmpty) {
          _trace(
            'apply.gapsDetected count=${gaps.length} for entity=${syncMessage.id}',
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

    _markJournalEntityProcessed(syncMessage.id, incomingVc);
    return diag;
  }

  // ---------------------------------------------------------------------------
  // Prepare-phase helpers (I/O only, no DB writes)
  // ---------------------------------------------------------------------------

  /// Dispatches the prepare phase per sync message family. Only
  /// [SyncJournalEntity], [SyncAgentEntity], and [SyncAgentLink] need I/O
  /// (attachment resolution); every other family is a passthrough.
  Future<PreparedSyncEvent> _prepareForMessage({
    required Event event,
    required SyncMessage syncMessage,
    required SyncJournalEntityLoader loader,
  }) async {
    switch (syncMessage) {
      case final SyncJournalEntity msg:
        return _prepareJournalEntity(
          event: event,
          syncMessage: msg,
          loader: loader,
        );
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
      default:
        // No file-backed payload to resolve. Apply reads everything it needs
        // from the envelope (SyncEntryLink, SyncEntityDefinition,
        // SyncAiConfig/Delete, SyncThemingSelection, SyncBackfillRequest,
        // SyncBackfillResponse).
        return PreparedSyncEvent._(event: event, syncMessage: syncMessage);
    }
  }

  /// Prepares a [SyncJournalEntity]: checks the duplicate fingerprint and
  /// otherwise invokes `loader.load` (network / gzip / disk).
  ///
  /// [FileSystemException]s thrown by the loader are caught when the error
  /// indicates a stale descriptor — the caller still needs to run the
  /// supersession check inside the apply transaction. Any other
  /// [FileSystemException] is rethrown for retry.
  Future<PreparedSyncEvent> _prepareJournalEntity({
    required Event event,
    required SyncJournalEntity syncMessage,
    required SyncJournalEntityLoader loader,
  }) async {
    if (_isDuplicateJournalEntity(syncMessage.id, syncMessage.vectorClock)) {
      return PreparedSyncEvent._(
        event: event,
        syncMessage: syncMessage,
        isDuplicateJournalEntity: true,
      );
    }

    try {
      final journalEntity = await loader.load(
        jsonPath: syncMessage.jsonPath,
        incomingVectorClock: syncMessage.vectorClock,
      );
      return PreparedSyncEvent._(
        event: event,
        syncMessage: syncMessage,
        journalEntity: journalEntity,
      );
    } on FileSystemException catch (error, stackTrace) {
      if (_isStaleDescriptorError(error)) {
        // Carry the error forward so apply can first check whether the local
        // version already dominates the incoming one (in which case the
        // event is skipped) or must be retried later (rethrown from apply).
        return PreparedSyncEvent._(
          event: event,
          syncMessage: syncMessage,
          deferredStaleDescriptorError: error,
        );
      }
      // Non-stale attachment failures log under the `missingAttachment`
      // subdomain and then rethrow for pipeline retry. Matches the pre-split
      // behaviour in `_handleMessage`.
      _loggingService.captureException(
        error,
        domain: 'MATRIX_SERVICE',
        subDomain: 'SyncEventProcessor.missingAttachment',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Apply-phase handlers (pure DB, no attachment I/O)
  // ---------------------------------------------------------------------------

  /// Applies an already-[PreparedSyncEvent] to local stores. Runs entirely in
  /// the writer transaction — it must not do attachment I/O.
  Future<SyncApplyDiagnostics?> _applyJournalEntity({
    required Event event,
    required SyncJournalEntity syncMessage,
    required JournalEntity? preloaded,
    required bool isDuplicate,
    required FileSystemException? deferredStaleError,
    required JournalDb journalDb,
  }) async {
    if (deferredStaleError != null) {
      final skipped = await _maybeSkipSupersededStaleDescriptor(
        event: event,
        syncMessage: syncMessage,
        journalDb: journalDb,
        entryLinks: syncMessage.entryLinks,
      );
      if (skipped != null) {
        return skipped;
      }
      // Not superseded — rethrow so the pipeline retries later. Logging
      // matches the pre-split behaviour where `process()` logged before
      // rethrow for any `FileSystemException` from loader.load.
      _loggingService.captureException(
        deferredStaleError,
        domain: 'MATRIX_SERVICE',
        subDomain: 'SyncEventProcessor.missingAttachment',
      );
      throw deferredStaleError;
    }

    if (isDuplicate) {
      return _recordDuplicateJournalEntity(
        event: event,
        syncMessage: syncMessage,
      );
    }

    // preloaded must be non-null when we reach this branch.
    return _persistJournalEntity(
      event: event,
      syncMessage: syncMessage,
      journalEntity: preloaded!,
      journalDb: journalDb,
    );
  }

  /// Duplicate-path handling extracted during the prepare/apply split. The
  /// duplicate detection itself now happens during prepare; apply only has to
  /// record the sequence-log entry so hint resolution still runs.
  Future<SyncApplyDiagnostics?> _recordDuplicateJournalEntity({
    required Event event,
    required SyncJournalEntity syncMessage,
  }) async {
    // Even for duplicates, record in the sequence log so that
    // resolvePendingHints runs. Without this, backfill hints (from
    // BackfillResponse messages) are never resolved because the entity
    // already exists locally with the same VC, but the pending
    // (hostId, counter) → payloadId mapping was never verified.
    if (_sequenceLogService != null &&
        syncMessage.vectorClock != null &&
        syncMessage.originatingHostId != null) {
      try {
        await _sequenceLogService.recordReceivedEntry(
          entryId: syncMessage.id,
          vectorClock: syncMessage.vectorClock!,
          originatingHostId: syncMessage.originatingHostId!,
          coveredVectorClocks: syncMessage.coveredVectorClocks,
          jsonPath: syncMessage.jsonPath,
        );
      } catch (e, st) {
        _loggingService.captureException(
          e,
          domain: 'SYNC_SEQUENCE',
          subDomain: 'duplicateRecord',
          stackTrace: st,
        );
      }
    }

    final diag = SyncApplyDiagnostics(
      eventId: event.eventId,
      payloadType: 'journalEntity',
      vectorClock: syncMessage.vectorClock?.toJson(),
      conflictStatus: VclockStatus.equal.toString(),
      applied: false,
      skipReason: JournalUpdateSkipReason.olderOrEqual,
    );
    _trace(
      'apply journalEntity skipped duplicate eventId=${event.eventId} '
      'id=${syncMessage.id}',
      subDomain: 'processor.apply',
    );
    return diag;
  }

  /// Persists a pre-resolved journal entity and its embedded links. The
  /// [journalEntity] argument was already loaded by the prepare phase, so
  /// this runs entirely in the writer transaction.
  Future<SyncApplyDiagnostics?> _persistJournalEntity({
    required Event event,
    required SyncJournalEntity syncMessage,
    required JournalEntity journalEntity,
    required JournalDb journalDb,
  }) async {
    final entryLinks = syncMessage.entryLinks;
    var predictedStatus = VclockStatus.b_gt_a;
    if (applyObserver != null) {
      try {
        final existing = await journalDb.journalEntityById(
          journalEntity.meta.id,
        );
        final vcA = existing?.meta.vectorClock;
        final vcB0 = journalEntity.meta.vectorClock;
        if (vcA != null && vcB0 != null) {
          predictedStatus = VectorClock.compare(vcA, vcB0);
        }
      } catch (e, st) {
        _loggingService.captureException(
          e,
          domain: 'MATRIX_SERVICE',
          subDomain: 'apply.predictVectorClock',
          stackTrace: st,
        );
        predictedStatus = VclockStatus.b_gt_a;
      }
    }

    final vcB = journalEntity.meta.vectorClock;
    final updateResult = await journalDb.updateJournalEntity(journalEntity);
    final rows = updateResult.rowsWritten ?? 0;

    // Process embedded entry links regardless of journal entity application
    // status. EntryLinks have their own vector clock for conflict resolution
    // via upsertEntryLink(). This ensures links are established even when the
    // entity itself is skipped (e.g., local version is newer), preventing
    // gray calendar entries that rely on links for category color lookup.
    final processedLinksCount = await _processEmbeddedEntryLinks(
      entryLinks: entryLinks,
      journalDb: journalDb,
    );

    final diag = SyncApplyDiagnostics(
      eventId: event.eventId,
      payloadType: 'journalEntity',
      vectorClock: vcB?.toJson(),
      conflictStatus: predictedStatus.toString(),
      applied: updateResult.applied,
      skipReason: updateResult.skipReason,
    );
    _trace(
      'apply journalEntity eventId=${event.eventId} id=${journalEntity.meta.id} '
      'rowsWritten=$rows applied=${updateResult.applied} '
      'skip=${updateResult.skipReason?.label ?? 'none'} '
      'status=${diag.conflictStatus} '
      'embeddedLinks=$processedLinksCount/${entryLinks?.length ?? 0}',
      subDomain: 'processor.apply',
    );
    _markJournalEntityProcessed(
      journalEntity.meta.id,
      vcB ?? syncMessage.vectorClock,
    );
    _updateNotifications.notify(
      {...journalEntity.affectedIds, labelUsageNotification},
      fromSync: true,
    );

    // Record in sequence log for gap detection (self-healing sync)
    if (_sequenceLogService != null &&
        syncMessage.vectorClock != null &&
        syncMessage.originatingHostId != null) {
      final entryExistsInJournal =
          updateResult.applied ||
          await journalDb.journalEntityById(journalEntity.meta.id) != null;
      if (entryExistsInJournal) {
        try {
          final gaps = await _sequenceLogService.recordReceivedEntry(
            entryId: journalEntity.meta.id,
            vectorClock: syncMessage.vectorClock!,
            originatingHostId: syncMessage.originatingHostId!,
            coveredVectorClocks: syncMessage.coveredVectorClocks,
            jsonPath: syncMessage.jsonPath,
          );
          if (gaps.isNotEmpty) {
            _trace(
              'apply.gapsDetected count=${gaps.length} '
              'for entity=${journalEntity.meta.id}',
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

    return diag;
  }

  /// Handles a SyncEntryLink message.
  Future<SyncApplyDiagnostics?> _handleEntryLink({
    required Event event,
    required SyncEntryLink syncMessage,
    required JournalDb journalDb,
  }) async {
    final entryLink = syncMessage.entryLink;
    final originatingHostId = syncMessage.originatingHostId;
    final coveredVectorClocks = syncMessage.coveredVectorClocks;

    final rows = await journalDb.upsertEntryLink(entryLink);
    try {
      if (rows > 0) {
        _trace(
          'apply entryLink from=${entryLink.fromId} to=${entryLink.toId} '
          'rows=$rows',
          subDomain: 'processor.apply.entryLink',
        );
      }
    } catch (_) {
      // best-effort logging only
    }

    // Surface DB-apply diagnostics to the pipeline when available
    if (applyObserver != null) {
      try {
        final diag = SyncApplyDiagnostics(
          eventId: event.eventId,
          payloadType: 'entryLink',
          vectorClock: null,
          conflictStatus: rows == 0 ? 'entryLink.noop' : 'applied',
          applied: rows > 0,
          skipReason: rows > 0 ? null : JournalUpdateSkipReason.olderOrEqual,
        );
        applyObserver!.call(diag);
      } catch (_) {
        // best-effort only
      }
    }
    _updateNotifications.notify(
      {entryLink.fromId, entryLink.toId},
      fromSync: true,
    );

    // Record in sequence log for gap detection (self-healing sync)
    if (_sequenceLogService != null &&
        entryLink.vectorClock != null &&
        originatingHostId != null) {
      final linkExists =
          rows > 0 || await journalDb.entryLinkById(entryLink.id) != null;
      if (linkExists) {
        try {
          final gaps = await _sequenceLogService.recordReceivedEntryLink(
            linkId: entryLink.id,
            vectorClock: entryLink.vectorClock!,
            originatingHostId: originatingHostId,
            coveredVectorClocks: coveredVectorClocks,
          );
          if (gaps.isNotEmpty) {
            _trace(
              'apply.entryLink.gapsDetected count=${gaps.length} '
              'for link=${entryLink.id}',
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
    return null;
  }

  /// Resolves an agent payload from a sync message: inline first, then
  /// fetches from [AttachmentIndex] descriptor (like [SmartJournalEntityLoader]
  /// does for journal entities), falling back to disk.
  ///
  /// Agent entity files can be updated in-place (e.g. ChangeSetEntity
  /// pending → resolved), so reading from disk alone risks stale data when
  /// the file download hasn't completed yet. Fetching from the descriptor
  /// ensures we always get the version that matches this text event.
  ///
  /// Path-validation errors from [resolveJsonCandidateFile] (e.g. path
  /// traversal) are permanent — logged and skipped. File-read
  /// [FileSystemException]s are rethrown so the pipeline retries (attachment
  /// may not have arrived yet). Other exceptions (corrupt JSON, parse errors)
  /// are logged and return null to skip permanently.
  Future<T?> _resolveAgentPayload<T>({
    required T? inline,
    required String? jsonPath,
    required T Function(Map<String, dynamic>) fromJson,
    required String typeName,
  }) async {
    if (inline != null) return inline;
    final jp = jsonPath;
    if (jp == null) {
      _trace(
        '$typeName.skipped no payload and no jsonPath',
        subDomain: 'processor.resolve',
      );
      return null;
    }
    // Validate path first — throws FileSystemException for path traversal.
    // This is a permanent error (malformed jsonPath), so catch and skip.
    final File file;
    try {
      file = resolveJsonCandidateFile(jp);
    } on FileSystemException catch (e, st) {
      _loggingService.captureException(
        e,
        domain: 'AGENT_SYNC',
        subDomain: 'resolve.$typeName.invalidPath',
        stackTrace: st,
      );
      return null;
    }

    // Fetch from the AttachmentIndex descriptor first to avoid reading
    // stale data from disk. Agent entity files can be updated in-place
    // (e.g. ChangeSetEntity pending → resolved), and the background
    // download may not have completed yet when this text event arrives.
    final fetched = await _fetchFromDescriptor(
      jsonPath: jp,
      targetFile: file,
      typeName: typeName,
    );
    if (fetched != null) {
      try {
        return fromJson(json.decode(fetched) as Map<String, dynamic>);
      } catch (e, st) {
        _loggingService.captureException(
          e,
          domain: 'AGENT_SYNC',
          subDomain: 'resolve.$typeName.parseFetched',
          stackTrace: st,
        );
        return null;
      }
    }

    // No descriptor available — fall back to disk.
    try {
      final jsonString = await file.readAsString();
      return fromJson(json.decode(jsonString) as Map<String, dynamic>);
    } on FileSystemException {
      // Attachment file not yet available — rethrow so the pipeline retries
      // and registers the pending descriptor path for catch-up.
      rethrow;
    } catch (e, st) {
      _loggingService.captureException(
        e,
        domain: 'AGENT_SYNC',
        subDomain: 'resolve.$typeName',
        stackTrace: st,
      );
      return null;
    }
  }

  /// Fetches fresh JSON from the [AttachmentIndex] descriptor and writes it
  /// to [targetFile]. Returns the JSON string on success, or null if no
  /// descriptor is available (index missing or not initialized).
  ///
  /// When a descriptor IS found but download/decode fails, throws
  /// [FileSystemException] to prevent falling back to potentially stale
  /// disk data.
  Future<String?> _fetchFromDescriptor({
    required String jsonPath,
    required File targetFile,
    required String typeName,
  }) async {
    final index = _attachmentIndex;
    if (index == null) return null;

    final indexKey = _buildAgentIndexKey(jsonPath);
    final descriptorEvent = index.find(indexKey);
    if (descriptorEvent == null) {
      _trace(
        '$typeName.descriptor.miss path=$jsonPath key=$indexKey',
        subDomain: 'processor.resolve',
      );
      return null;
    }

    final dedupeKey = '$indexKey@${descriptorEvent.eventId}';
    final existing = _inFlightDescriptorFetches[dedupeKey];
    if (existing != null) {
      return existing;
    }

    final future = _runDescriptorFetch(
      jsonPath: jsonPath,
      targetFile: targetFile,
      typeName: typeName,
      descriptorEvent: descriptorEvent,
    );
    _inFlightDescriptorFetches[dedupeKey] = future;
    return future.whenComplete(() {
      _inFlightDescriptorFetches.remove(dedupeKey);
    });
  }

  Future<String?> _runDescriptorFetch({
    required String jsonPath,
    required File targetFile,
    required String typeName,
    required Event descriptorEvent,
  }) async {
    try {
      final matrixFile = await descriptorEvent.downloadAndDecryptAttachment();
      final downloadedBytes = matrixFile.bytes;
      if (downloadedBytes.isEmpty) {
        throw const FileSystemException('empty attachment bytes');
      }
      final bytes = await decodeAttachmentBytes(
        event: descriptorEvent,
        downloadedBytes: downloadedBytes,
        relativePath: jsonPath,
        logging: _loggingService,
      );
      final jsonString = utf8.decode(bytes);
      await saveJson(targetFile.path, jsonString);
      _trace(
        '$typeName.descriptor.fetched path=$jsonPath bytes=${bytes.length}',
        subDomain: 'processor.resolve',
      );
      return jsonString;
    } catch (e, st) {
      _loggingService.captureException(
        e,
        domain: 'AGENT_SYNC',
        subDomain: 'resolve.$typeName.descriptorFetch',
        stackTrace: st,
      );
      // Descriptor was found but download/decode failed — throw to prevent
      // falling back to potentially stale disk data. The pipeline will retry.
      throw FileSystemException(
        '$typeName descriptor fetch failed',
        jsonPath,
      );
    }
  }

  static String _buildAgentIndexKey(String rawPath) =>
      normalizeAttachmentIndexKey(rawPath);

  Future<AgentDomainEntity?> _resolveAgentEntity(
    SyncAgentEntity msg,
  ) => _resolveAgentPayload(
    inline: msg.agentEntity,
    jsonPath: msg.jsonPath,
    fromJson: AgentDomainEntity.fromJson,
    typeName: 'agentEntity',
  );

  Future<AgentLink?> _resolveAgentLink(SyncAgentLink msg) =>
      _resolveAgentPayload(
        inline: msg.agentLink,
        jsonPath: msg.jsonPath,
        fromJson: AgentLink.fromJson,
        typeName: 'agentLink',
      );

  Future<SyncApplyDiagnostics?> _applyMessage({
    required PreparedSyncEvent prepared,
    required JournalDb journalDb,
  }) async {
    final event = prepared.event;
    final syncMessage = prepared.syncMessage;
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
            _loggingService.captureEvent(
              'themingSync.ignored.stale incoming=$updatedAt local=$localUpdatedAt',
              domain: 'THEMING_SYNC',
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
          _loggingService.captureEvent(
            'apply themingSelection light=$lightThemeName dark=$darkThemeName mode=$themeMode',
            domain: 'THEMING_SYNC',
            subDomain: 'apply',
          );
        } catch (e, st) {
          _loggingService.captureException(
            e,
            domain: 'THEMING_SYNC',
            subDomain: 'apply',
            stackTrace: st,
          );
        }
        return null;
      case SyncBackfillRequest():
        // Handle backfill request - another device is asking for a missing entry
        if (backfillResponseHandler != null) {
          await backfillResponseHandler!.handleBackfillRequest(syncMessage);
        } else {
          _trace(
            'backfillRequest.ignored no handler configured',
            subDomain: 'processor.apply',
          );
        }
        return null;
      case SyncBackfillResponse():
        // Handle backfill response - another device responded to our request
        if (backfillResponseHandler != null) {
          await backfillResponseHandler!.handleBackfillResponse(syncMessage);
        } else {
          _trace(
            'backfillResponse.ignored no handler configured',
            subDomain: 'processor.apply',
          );
        }
        return null;
      // Agent entities use last-writer-wins semantics (no vector clock
      // comparison). Agent state mutations are causally ordered — wakes
      // run serially and each update overwrites prior state — so
      // concurrent conflicting edits don't arise in practice.
      // Maintenance sync serves as catch-up for missed messages.
      case final SyncAgentEntity msg:
        final resolvedEntity = prepared.resolvedAgentEntity;
        if (resolvedEntity == null) {
          return null;
        }
        if (agentRepository != null) {
          await agentRepository!.upsertEntity(resolvedEntity);
          // Remove wake subscriptions when an agent is paused or destroyed
          // remotely — mirrors what AgentService.pauseAgent/destroyAgent do
          // locally.
          if (wakeOrchestrator != null &&
              resolvedEntity is AgentIdentityEntity &&
              resolvedEntity.lifecycle != AgentLifecycle.active) {
            wakeOrchestrator!.removeSubscriptions(resolvedEntity.agentId);
          }
          // Restore wake subscriptions when an agent is resumed remotely —
          // mirrors what TaskAgentService.restoreSubscriptionsForAgent does
          // locally after AgentService.resumeAgent.
          if (wakeOrchestrator != null &&
              resolvedEntity is AgentIdentityEntity &&
              resolvedEntity.lifecycle == AgentLifecycle.active &&
              resolvedEntity.kind == 'task_agent') {
            final links = await agentRepository!.getLinksFrom(
              resolvedEntity.agentId,
              type: 'agent_task',
            );
            for (final link in links) {
              wakeOrchestrator!.addSubscription(
                AgentSubscription(
                  id: '${resolvedEntity.agentId}_task_${link.toId}',
                  agentId: resolvedEntity.agentId,
                  matchEntityIds: {link.toId},
                ),
              );
            }
          }
          _updateNotifications.notify(
            {
              resolvedEntity.agentId,
              // Include templateId so template-level aggregate providers
              // refresh when token usage or reports arrive from other devices.
              if (resolvedEntity is WakeTokenUsageEntity &&
                  resolvedEntity.templateId != null)
                resolvedEntity.templateId!,
              agentNotification,
            },
            fromSync: true,
          );
          _trace(
            'apply agentEntity id=${resolvedEntity.id}',
            subDomain: 'processor.apply',
          );

          // Record in sequence log for gap detection (self-healing sync)
          if (_sequenceLogService != null &&
              resolvedEntity.vectorClock != null &&
              msg.originatingHostId != null) {
            try {
              final gaps = await _sequenceLogService.recordReceivedEntry(
                entryId: resolvedEntity.id,
                vectorClock: resolvedEntity.vectorClock!,
                originatingHostId: msg.originatingHostId!,
                coveredVectorClocks: msg.coveredVectorClocks,
                payloadType: SyncSequencePayloadType.agentEntity,
                jsonPath: msg.jsonPath,
              );
              if (gaps.isNotEmpty) {
                _trace(
                  'apply.agentEntity.gapsDetected count=${gaps.length} '
                  'for entity=${resolvedEntity.id}',
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
        } else {
          _trace(
            'agentEntity.ignored no repository',
            subDomain: 'processor.apply',
          );
        }
        return null;
      case final SyncAgentLink msg:
        final resolvedLink = prepared.resolvedAgentLink;
        if (resolvedLink == null) {
          return null;
        }
        if (agentRepository != null) {
          await agentRepository!.upsertLink(resolvedLink);
          // Restore wake subscription when an agent_task link arrives for an
          // active task_agent. This handles the case where the link arrives
          // after the identity — the SyncAgentEntity handler queries existing
          // links, which may be empty if the link hasn't been synced yet.
          // addSubscription is idempotent (replaces by ID), so both handlers
          // firing for the same agent is harmless.
          if (wakeOrchestrator != null &&
              resolvedLink is AgentTaskLink &&
              resolvedLink.deletedAt == null) {
            final agent = await agentRepository!.getEntity(resolvedLink.fromId);
            if (agent is AgentIdentityEntity &&
                agent.lifecycle == AgentLifecycle.active &&
                agent.kind == 'task_agent') {
              wakeOrchestrator!.addSubscription(
                AgentSubscription(
                  id: '${resolvedLink.fromId}_task_${resolvedLink.toId}',
                  agentId: resolvedLink.fromId,
                  matchEntityIds: {resolvedLink.toId},
                ),
              );
            }
          }
          _updateNotifications.notify(
            {resolvedLink.fromId, resolvedLink.toId, agentNotification},
            fromSync: true,
          );
          _trace(
            'apply agentLink id=${resolvedLink.id}',
            subDomain: 'processor.apply',
          );

          // Record in sequence log for gap detection (self-healing sync)
          if (_sequenceLogService != null &&
              resolvedLink.vectorClock != null &&
              msg.originatingHostId != null) {
            try {
              final gaps = await _sequenceLogService.recordReceivedEntry(
                entryId: resolvedLink.id,
                vectorClock: resolvedLink.vectorClock!,
                originatingHostId: msg.originatingHostId!,
                coveredVectorClocks: msg.coveredVectorClocks,
                payloadType: SyncSequencePayloadType.agentLink,
                jsonPath: msg.jsonPath,
              );
              if (gaps.isNotEmpty) {
                _trace(
                  'apply.agentLink.gapsDetected count=${gaps.length} '
                  'for link=${resolvedLink.id}',
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
        } else {
          _trace(
            'agentLink.ignored no repository',
            subDomain: 'processor.apply',
          );
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
    this.deferredStaleDescriptorError,
    this.resolvedAgentEntity,
    this.resolvedAgentLink,
  });

  PreparedSyncEvent._({
    required this.event,
    required this.syncMessage,
    this.journalEntity,
    this.isDuplicateJournalEntity = false,
    this.deferredStaleDescriptorError,
    this.resolvedAgentEntity,
    this.resolvedAgentLink,
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
}
