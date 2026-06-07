// Records attachment descriptors and queues attachment downloads to disk.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/utils/atomic_write.dart';
import 'package:lotti/features/sync/matrix/utils/attachment_decoding.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/fd_limits.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:matrix/matrix.dart';
import 'package:path/path.dart' as p;

part 'attachment_saver.dart';

/// Causality check: does the caller already have a local copy of the
/// entity at [relativePath] whose vector clock is equal to or newer
/// than [incomingVectorClock]? Returns true to suppress the download
/// (local copy is at least as current), false to proceed with it.
///
/// When [incomingVectorClock] is null, the event carries no VC and
/// callers should return false — we have no way to prove the local
/// copy is current.
typedef LocalVectorClockDominanceCheck =
    Future<bool> Function(
      String relativePath,
      VectorClock? incomingVectorClock,
    );

/// AttachmentIngestor
///
/// Purpose
/// - Encapsulates first-pass attachment handling for the sync pipeline:
///   - Record descriptors into AttachmentIndex and emit observability logs
///   - Download and save attachments (immediate or queued)
///
/// This helper operates on provided arguments and the documents directory.
class AttachmentIngestor {
  AttachmentIngestor({
    this.documentsDirectory,
    int maxConcurrentDownloads = _defaultMaxConcurrentDownloads,
    int? handledEventCapacity,
    this.verboseLogging = true,
    this.localVcDominates,
  }) : _maxConcurrentDownloads = maxConcurrentDownloads < 0
           ? 0
           : maxConcurrentDownloads,
       _handledAttachmentEventCapacity =
           handledEventCapacity ?? _defaultHandledAttachmentEventCapacity;

  /// Injected causality check. Wired by the coordinator so we can
  /// consult `AgentRepository` / `JournalDb` for the local entity's
  /// current vector clock without coupling this helper to those
  /// repositories directly. When null, every attachment is
  /// downloaded — the check is an optimization, not a correctness
  /// primitive.
  final LocalVectorClockDominanceCheck? localVcDominates;

  static const int _defaultMaxConcurrentDownloads = 2;
  static const int _defaultHandledAttachmentEventCapacity =
      SyncTuning.catchupMaxLookback;

  /// The documents directory for saving attachments. If null, downloads are
  /// skipped (descriptor-only mode for testing or when fs access is not
  /// available).
  final Directory? documentsDirectory;
  final int _maxConcurrentDownloads;
  final int _handledAttachmentEventCapacity;

  /// When true, emits per-event `attachment.observe` lines. Production
  /// disables this to keep the steady-state log volume down; the wrapping
  /// `batch.summary` already carries total observed/indexed counts. Tests
  /// default to verbose so existing assertions on per-event emission stay
  /// meaningful.
  final bool verboseLogging;

  final Queue<String> _downloadQueue = Queue<String>();
  final Map<String, _DownloadRequest> _pendingDownloads =
      <String, _DownloadRequest>{};
  // Bounded insertion-ordered LRU of recently handled attachment event ids.
  // Dart's default `Set` is a `LinkedHashSet`, so a single structure can
  // back both the presence check and the oldest-first eviction order.
  final Set<String> _handledAttachmentEventIds = <String>{};
  final Set<String> _queuedKeys = <String>{};
  final Set<String> _inFlightKeys = <String>{};

  // Matrix Event ids whose cached file entry was evicted from the SDK's
  // local store. The desktop stack traces show `Event._getCachedFile`
  // raising a bare `Exception("Can not try to send again. File is no
  // longer cached.")` during our `downloadAndDecryptAttachment()` call
  // chain; subsequent attempts for the same event id will throw the same
  // exception immediately, so by recording the id here we skip the SDK
  // round-trip, stack-trace generation, and error-log emission entirely.
  // Bounded by the same LRU window as `_handledAttachmentEventIds`.
  final Set<String> _cacheEvictedEventIds = <String>{};

  /// Tracks paths with an in-flight immediate (non-queued) save to prevent
  /// concurrent `_saveAttachment()` calls for the same file from `process()`.
  final Set<String> _inFlightSavePaths = <String>{};
  int _inFlightCount = 0;
  bool _disposed = false;
  Completer<void>? _idleCompleter;

  /// Processes attachment-related behavior for an event.
  ///
  /// Returns `true` if a new file was written to disk immediately, `false`
  /// otherwise.
  Future<bool> process({
    required Event event,
    required DomainLogger logging,
    required AttachmentIndex? attachmentIndex,
    bool scheduleDownload = false,
  }) async {
    var fileWritten = false;

    // Record descriptors when present and avoid re-processing the exact same
    // attachment event on repeated catch-up/live-scan passes unless the local
    // file is missing and needs repair.
    final rpAny = event.content['relativePath'];
    if (rpAny is String && rpAny.isNotEmpty) {
      // Always keep AttachmentIndex up-to-date so SmartJournalEntityLoader
      // can find descriptors for VC validation and re-fetch, even when the
      // download itself is skipped by the dedup guards below.
      attachmentIndex?.record(event);

      // Synchronously check-and-record to prevent concurrent process() calls
      // for the same eventId from both passing the guard.
      final alreadyHandled = _wasAttachmentEventHandled(event.eventId);
      if (!alreadyHandled) {
        _recordHandledAttachmentEvent(event.eventId);
      }
      // Only check the local file for repair when the event was already
      // handled once — new events always proceed.
      // Suppress repair if a save is already in flight for this path to avoid
      // concurrent writes to the same file.
      final shouldRepairLocal =
          alreadyHandled &&
          documentsDirectory != null &&
          !_inFlightSavePaths.contains(_normalizeKey(rpAny)) &&
          _isLocalFileMissingOrEmpty(rpAny);
      final shouldProcessAttachment = !alreadyHandled || shouldRepairLocal;

      if (shouldProcessAttachment) {
        if (verboseLogging) {
          try {
            final mime = event.attachmentMimetype;
            final content = event.content;
            final hasUrl =
                content.containsKey('url') ||
                content.containsKey('mxc') ||
                content.containsKey('mxcUrl') ||
                content.containsKey('uri');
            final hasEnc = content.containsKey('file');
            final msgType = content['msgtype'];
            logging.log(
              LogDomain.sync,
              'attachmentEvent id=${event.eventId} path=$rpAny mime=$mime msgtype=$msgType hasUrl=$hasUrl hasFile=$hasEnc',
              subDomain: 'attachment.observe',
            );
          } catch (_) {
            // best-effort logging only
          }
        }

        // Download attachments either immediately or via the async queue.
        if (documentsDirectory != null) {
          if (scheduleDownload) {
            _scheduleDownload(
              event: event,
              relativePath: rpAny,
              logging: logging,
            );
          } else {
            // Guard against concurrent immediate saves for the same path.
            // The queued download path already has its own dedup via
            // _queuedKeys/_inFlightKeys.
            final saveKey = _normalizeKey(rpAny);
            if (_inFlightSavePaths.contains(saveKey)) {
              // Another process() call is already saving this file.
              return false;
            }
            _inFlightSavePaths.add(saveKey);
            try {
              fileWritten = await _saveAttachment(
                event: event,
                relativePath: rpAny,
                logging: logging,
              );
            } finally {
              _inFlightSavePaths.remove(saveKey);
            }
          }
        }
      }
    }

    return fileWritten;
  }

  /// Waits for any queued downloads to finish (best-effort for tests).
  Future<void> whenIdle() {
    if (_downloadQueue.isEmpty && _inFlightCount == 0) {
      return Future.value();
    }
    _idleCompleter ??= Completer<void>();
    return _idleCompleter!.future;
  }

  void dispose() {
    _disposed = true;
    _downloadQueue.clear();
    _pendingDownloads.clear();
    _handledAttachmentEventIds.clear();
    _cacheEvictedEventIds.clear();
    _queuedKeys.clear();
    _inFlightSavePaths.clear();
    _idleCompleter?.complete();
    _idleCompleter = null;
    _inFlightKeys.clear();
    _inFlightCount = 0;
  }

  void _scheduleDownload({
    required Event event,
    required String relativePath,
    required DomainLogger logging,
  }) {
    if (_disposed ||
        documentsDirectory == null ||
        _maxConcurrentDownloads == 0) {
      return;
    }
    final key = _normalizeKey(relativePath);
    _pendingDownloads[key] = _DownloadRequest(
      event: event,
      relativePath: relativePath,
      logging: logging,
    );
    if (_queuedKeys.contains(key) || _inFlightKeys.contains(key)) {
      return;
    }
    _queuedKeys.add(key);
    _downloadQueue.add(key);
    _drainQueue();
  }

  void _drainQueue() {
    if (_disposed) return;
    while (_inFlightCount < _maxConcurrentDownloads &&
        _downloadQueue.isNotEmpty) {
      final key = _downloadQueue.removeFirst();
      _queuedKeys.remove(key);
      final request = _pendingDownloads[key];
      if (request == null) {
        continue;
      }
      _inFlightCount++;
      _inFlightKeys.add(key);
      unawaited(_runDownload(key, request));
    }
    _maybeCompleteIdle();
  }

  Future<void> _runDownload(String key, _DownloadRequest request) async {
    try {
      await _saveAttachment(
        event: request.event,
        relativePath: request.relativePath,
        logging: request.logging,
      );
    } finally {
      _inFlightCount--;
      _inFlightKeys.remove(key);
      final latest = _pendingDownloads[key];
      if (latest == null || latest.event.eventId == request.event.eventId) {
        _pendingDownloads.remove(key);
      } else if (!_queuedKeys.contains(key)) {
        _queuedKeys.add(key);
        _downloadQueue.add(key);
      }
      _drainQueue();
    }
  }

  void _maybeCompleteIdle() {
    if (_downloadQueue.isEmpty && _inFlightCount == 0) {
      _idleCompleter?.complete();
      _idleCompleter = null;
    }
  }

  bool _wasAttachmentEventHandled(String eventId) =>
      _handledAttachmentEventIds.contains(eventId);

  void _recordHandledAttachmentEvent(String eventId) {
    if (_handledAttachmentEventIds.add(eventId)) {
      while (_handledAttachmentEventIds.length >
          _handledAttachmentEventCapacity) {
        _handledAttachmentEventIds.remove(_handledAttachmentEventIds.first);
      }
    }
  }

  String _normalizeKey(String relativePath) =>
      normalizeAttachmentIndexKey(relativePath);

  bool _isLocalFileMissingOrEmpty(String relativePath) {
    final file = _targetFile(relativePath);
    if (file == null) {
      return false;
    }
    try {
      if (!file.existsSync()) {
        return true;
      }
      return file.lengthSync() <= 0;
    } on FileSystemException {
      return true;
    }
  }

  File? _targetFile(String relativePath) {
    final docDir = documentsDirectory;
    if (docDir == null) {
      return null;
    }

    var rel = relativePath;
    if (p.isAbsolute(rel)) {
      final prefix = p.rootPrefix(rel);
      rel = rel.substring(prefix.length);
    }
    final resolved = p.normalize(p.join(docDir.path, rel));
    if (!p.isWithin(docDir.path, resolved)) {
      return null;
    }
    return File(resolved);
  }
}

class _DownloadRequest {
  const _DownloadRequest({
    required this.event,
    required this.relativePath,
    required this.logging,
  });

  final Event event;
  final String relativePath;
  final DomainLogger logging;
}
