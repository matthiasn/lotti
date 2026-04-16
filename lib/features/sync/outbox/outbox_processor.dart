// ignore_for_file: sort_constructors_first

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/matrix/attachment_enumerator.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_repository.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';

abstract class OutboxMessageSender {
  /// Sends [message]. When [skipAttachmentPaths] is non-empty, the sender must
  /// skip uploading any file whose relative path is in the set — typically
  /// because the file was already uploaded out-of-band via
  /// [sendAttachmentBundle].
  Future<bool> send(
    SyncMessage message, {
    Set<String> skipAttachmentPaths = const <String>{},
  });

  /// Packages the supplied relativePath→bytes [entries] into a single zip
  /// archive and uploads it as one Matrix file event. Returns the event id on
  /// success, null on failure (including no available sync room).
  Future<String?> sendAttachmentBundle({
    required Map<String, Uint8List> entries,
  });
}

class OutboxProcessingResult {
  const OutboxProcessingResult._({this.nextDelay});

  final Duration? nextDelay;

  static const OutboxProcessingResult none = OutboxProcessingResult._();

  factory OutboxProcessingResult.schedule(Duration delay) =>
      OutboxProcessingResult._(nextDelay: delay);

  bool get shouldSchedule => nextDelay != null;
}

class OutboxProcessor {
  OutboxProcessor({
    required OutboxRepository repository,
    required OutboxMessageSender messageSender,
    required LoggingService loggingService,
    int? batchSizeOverride,
    Duration? retryDelayOverride,
    Duration? errorDelayOverride,
    int? maxRetriesOverride,
    Duration? sendTimeoutOverride,
    DomainLogger? domainLogger,
    JournalDb? journalDb,
    Directory? documentsDirectory,
    int? bundleMaxBytesOverride,
  }) : _repository = repository,
       _messageSender = messageSender,
       _loggingService = loggingService,
       _domainLogger = domainLogger,
       _journalDb = journalDb,
       _documentsDirectory = documentsDirectory,
       batchSize = batchSizeOverride ?? 10,
       retryDelay = retryDelayOverride ?? SyncTuning.outboxRetryDelay,
       errorDelay = errorDelayOverride ?? SyncTuning.outboxErrorDelay,
       maxRetriesForDiagnostics =
           maxRetriesOverride ?? SyncTuning.outboxMaxRetriesDiagnostics,
       sendTimeout = sendTimeoutOverride ?? SyncTuning.outboxSendTimeout,
       bundleMaxBytes =
           bundleMaxBytesOverride ?? SyncTuning.outboxBundleMaxBytes;

  final OutboxRepository _repository;
  final OutboxMessageSender _messageSender;
  final LoggingService _loggingService;
  final DomainLogger? _domainLogger;
  final JournalDb? _journalDb;
  final Directory? _documentsDirectory;
  final int batchSize;
  final Duration retryDelay;
  final Duration errorDelay;
  final int maxRetriesForDiagnostics;
  final Duration sendTimeout;
  final int bundleMaxBytes;

  void _syncLog(String message, {String? subDomain}) {
    _domainLogger?.log(LogDomains.sync, message, subDomain: subDomain);
  }

  // Diagnostics for repeated failures on the same head-of-queue subject.
  String? _lastFailedSubject;
  int _lastFailedRepeats = 0;

  Future<OutboxProcessingResult> processQueue() async {
    final pendingItems = await _repository.fetchPending(limit: batchSize);
    if (pendingItems.isEmpty) {
      return OutboxProcessingResult.none;
    }

    // When the feature flag is on and enough items are pending to gain from
    // one Matrix round-trip, attempt an attachment-bundle send first. The
    // helper returns null when bundling is disabled or nothing was
    // bundleable (e.g. every pending item's attachments exceed the cap or
    // carry no files at all), so the existing head-only flow still runs as
    // the default path.
    final bundleOutcome = await _maybeProcessBundle(pendingItems);
    if (bundleOutcome != null) return bundleOutcome;

    final nextItem = pendingItems.first;
    try {
      _loggingService.captureEvent(
        'pending=${pendingItems.length} head=${nextItem.subject}',
        domain: 'OUTBOX',
        subDomain: 'queue',
      );
    } catch (_) {
      // best-effort logging only
    }
    _loggingService.captureEvent(
      'trying ${nextItem.subject} ',
      domain: 'OUTBOX',
      subDomain: 'sendNext()',
    );

    try {
      // Re-read item to get the latest message after any merges that may
      // have occurred since fetchPending(). This ensures coveredVectorClocks
      // accumulated during the processing delay are included.
      final refreshedItem = await _repository.refreshItem(nextItem);
      if (refreshedItem == null) {
        // Item was deleted or status changed during processing
        try {
          _loggingService.captureEvent(
            'skip ${nextItem.subject} - item no longer pending',
            domain: 'OUTBOX',
            subDomain: 'sendNext()',
          );
        } catch (_) {}
        // Continue to next item immediately
        final hasMore = pendingItems.length > 1;
        return hasMore
            ? OutboxProcessingResult.schedule(Duration.zero)
            : OutboxProcessingResult.none;
      }

      final syncMessage = _decodeMessage(refreshedItem);
      // Log the decoded message type to improve visibility, especially for links
      try {
        _loggingService.captureEvent(
          'sending type=${syncMessage.runtimeType} subject=${refreshedItem.subject}',
          domain: 'OUTBOX',
          subDomain: 'sendNext()',
        );
      } catch (_) {
        // best-effort logging only
      }
      _syncLog(
        'send type=${syncMessage.runtimeType} subject=${refreshedItem.subject}',
        subDomain: 'outbox.send',
      );
      var timedOut = false;
      final success = await _messageSender
          .send(syncMessage)
          .timeout(
            sendTimeout,
            onTimeout: () {
              timedOut = true;
              return false;
            },
          );

      if (!success) {
        final nextAttempts = refreshedItem.retries + 1;
        await _repository.markRetry(refreshedItem);
        _syncLog(
          'sendFail subject=${refreshedItem.subject} attempts=$nextAttempts timedOut=$timedOut',
          subDomain: 'outbox.retry',
        );
        // Track repeated failures for quick visibility on head-of-queue pins.
        if (_lastFailedSubject == refreshedItem.subject) {
          _lastFailedRepeats++;
        } else {
          _lastFailedSubject = refreshedItem.subject;
          _lastFailedRepeats = 1;
        }
        try {
          _loggingService.captureEvent(
            'sendFailed subject=${refreshedItem.subject} attempts=$nextAttempts repeats=$_lastFailedRepeats backoffMs=${retryDelay.inMilliseconds} timedOut=$timedOut',
            domain: 'OUTBOX',
            subDomain: 'retry',
          );
        } catch (_) {}
        if (nextAttempts >= maxRetriesForDiagnostics) {
          try {
            _loggingService.captureEvent(
              'retryCapReached subject=${refreshedItem.subject} attempts=$nextAttempts status=error → skip/head-advance',
              domain: 'OUTBOX',
              subDomain: 'retry.cap',
            );
          } catch (_) {}
          // The repository marks status=error at cap. Continue immediately to the next item.
          return OutboxProcessingResult.schedule(Duration.zero);
        }
        return OutboxProcessingResult.schedule(retryDelay);
      }

      await _repository.markSent(refreshedItem);
      _syncLog(
        'sent subject=${refreshedItem.subject}',
        subDomain: 'outbox.send',
      );
      _loggingService.captureEvent(
        '${refreshedItem.subject} done',
        domain: 'OUTBOX',
        subDomain: 'sendNext()',
      );
      // Reset repeat tracker on success for this subject.
      if (_lastFailedSubject == refreshedItem.subject) {
        _lastFailedSubject = null;
        _lastFailedRepeats = 0;
      }

      final hasMore = pendingItems.length > 1;
      if (hasMore) {
        try {
          _loggingService.captureEvent(
            'scheduleNext immediate (hasMore)',
            domain: 'OUTBOX',
            subDomain: 'queue',
          );
        } catch (_) {}
        return OutboxProcessingResult.schedule(Duration.zero);
      }
      return OutboxProcessingResult.none;
    } catch (error, stackTrace) {
      _loggingService.captureException(
        error,
        domain: 'OUTBOX',
        subDomain: 'sendNext',
        stackTrace: stackTrace,
      );
      final nextAttempts = nextItem.retries + 1;
      await _repository.markRetry(nextItem);
      if (_lastFailedSubject == nextItem.subject) {
        _lastFailedRepeats++;
      } else {
        _lastFailedSubject = nextItem.subject;
        _lastFailedRepeats = 1;
      }
      try {
        _loggingService.captureEvent(
          'sendException subject=${nextItem.subject} attempts=$nextAttempts repeats=$_lastFailedRepeats backoffMs=${errorDelay.inMilliseconds}',
          domain: 'OUTBOX',
          subDomain: 'retry',
        );
      } catch (_) {}
      if (nextAttempts >= maxRetriesForDiagnostics) {
        try {
          _loggingService.captureEvent(
            'retryCapReached subject=${nextItem.subject} attempts=$nextAttempts status=error → skip/head-advance',
            domain: 'OUTBOX',
            subDomain: 'retry.cap',
          );
        } catch (_) {}
        return OutboxProcessingResult.schedule(Duration.zero);
      }
      return OutboxProcessingResult.schedule(errorDelay);
    }
  }

  SyncMessage _decodeMessage(OutboxItem item) {
    final jsonMap = json.decode(item.message) as Map<String, dynamic>;
    return SyncMessage.fromJson(jsonMap);
  }

  /// Attempts to coalesce as many of [pending] items' attachment files as
  /// fit into a single zip (capped at [bundleMaxBytes]) and uploads them as
  /// one Matrix file event before sending each included item's text event
  /// with the bundled paths marked for skip. Returns null when bundling is
  /// disabled or nothing was bundleable, so the caller can fall through to
  /// the existing head-only flow.
  Future<OutboxProcessingResult?> _maybeProcessBundle(
    List<OutboxItem> pending,
  ) async {
    final docDir = _documentsDirectory;
    final db = _journalDb;
    if (docDir == null || db == null) return null;

    final bundlingOn = await db.getConfigFlag(useBundledAttachmentsFlag);
    if (!bundlingOn) return null;

    // Enumerate attachments per item. Items that fail to decode or have no
    // attachments are kept for the solo path.
    final enumerated = <({OutboxItem item, List<AttachmentDescriptor> atts})>[];
    for (final item in pending) {
      try {
        final msg = _decodeMessage(item);
        final atts = await enumerateAttachments(
          message: msg,
          documentsDirectory: docDir,
        );
        enumerated.add((item: item, atts: atts));
      } catch (_) {
        enumerated.add((item: item, atts: const <AttachmentDescriptor>[]));
      }
    }

    // Partition greedily: an item is included in the bundle if its own
    // attachments fit within the remaining bundle budget. Items whose total
    // attachment size exceeds the cap on their own go to the solo path via
    // the existing head-only flow on the next tick.
    final bundled = <({OutboxItem item, List<AttachmentDescriptor> atts})>[];
    var bundleSize = 0;
    for (final e in enumerated) {
      if (e.atts.isEmpty) continue;
      final total = e.atts.fold<int>(0, (s, a) => s + a.size);
      if (total > bundleMaxBytes) continue;
      if (bundleSize + total > bundleMaxBytes) continue;
      bundled.add(e);
      bundleSize += total;
    }

    if (bundled.isEmpty) return null;

    // Read file contents and pack into the payload map. Any read failure
    // falls through to the existing solo path, where the usual error handling
    // applies per item.
    final entries = <String, Uint8List>{};
    try {
      for (final e in bundled) {
        for (final a in e.atts) {
          entries[a.relativePath] = await File(a.fullPath).readAsBytes();
        }
      }
    } catch (err, stackTrace) {
      _loggingService.captureException(
        err,
        domain: 'OUTBOX',
        subDomain: 'bundle.readFiles',
        stackTrace: stackTrace,
      );
      return null;
    }

    _loggingService.captureEvent(
      'bundle packing items=${bundled.length} files=${entries.length} '
      'bytes=$bundleSize',
      domain: 'OUTBOX',
      subDomain: 'bundle.pack',
    );
    _syncLog(
      'bundle pack items=${bundled.length} files=${entries.length} '
      'bytes=$bundleSize',
      subDomain: 'outbox.bundle.pack',
    );

    final bundleEventId = await _messageSender.sendAttachmentBundle(
      entries: entries,
    );
    if (bundleEventId == null) {
      for (final e in bundled) {
        await _repository.markRetry(e.item);
      }
      _loggingService.captureEvent(
        'bundle upload failed items=${bundled.length}',
        domain: 'OUTBOX',
        subDomain: 'bundle.fail',
      );
      return OutboxProcessingResult.schedule(errorDelay);
    }
    _loggingService.captureEvent(
      'bundle uploaded eventId=$bundleEventId items=${bundled.length} '
      'bytes=$bundleSize',
      domain: 'OUTBOX',
      subDomain: 'bundle.ok',
    );

    // Send each bundled item's text event. Per-item failures mark that item
    // for retry without affecting the others.
    final skipSet = entries.keys.toSet();
    var anyFailure = false;
    for (final e in bundled) {
      final refreshed = await _repository.refreshItem(e.item);
      if (refreshed == null) continue;
      final SyncMessage msg;
      try {
        msg = _decodeMessage(refreshed);
      } catch (error, stackTrace) {
        _loggingService.captureException(
          error,
          domain: 'OUTBOX',
          subDomain: 'bundle.decode',
          stackTrace: stackTrace,
        );
        await _repository.markRetry(refreshed);
        anyFailure = true;
        continue;
      }
      var timedOut = false;
      final ok = await _messageSender
          .send(msg, skipAttachmentPaths: skipSet)
          .timeout(
            sendTimeout,
            onTimeout: () {
              timedOut = true;
              return false;
            },
          );
      if (ok) {
        await _repository.markSent(refreshed);
      } else {
        await _repository.markRetry(refreshed);
        anyFailure = true;
        _syncLog(
          'bundle text-event sendFail subject=${refreshed.subject} '
          'timedOut=$timedOut',
          subDomain: 'outbox.bundle.retry',
        );
      }
    }

    final remaining = pending.length - bundled.length;
    if (remaining > 0 || anyFailure) {
      return OutboxProcessingResult.schedule(
        anyFailure ? retryDelay : Duration.zero,
      );
    }
    return OutboxProcessingResult.none;
  }
}
