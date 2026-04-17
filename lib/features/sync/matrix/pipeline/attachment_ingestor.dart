// Records attachment descriptors and queues attachment downloads to disk.

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/pipeline/descriptor_catch_up_manager.dart';
import 'package:lotti/features/sync/matrix/utils/atomic_write.dart';
import 'package:lotti/features/sync/matrix/utils/attachment_decoding.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/fd_limits.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:matrix/matrix.dart';
import 'package:path/path.dart' as p;

/// AttachmentIngestor
///
/// Purpose
/// - Encapsulates first-pass attachment handling for the sync pipeline:
///   - Record descriptors into AttachmentIndex and emit observability logs
///   - Download and save attachments (immediate or queued)
///   - Clear pending jsonPaths via [DescriptorCatchUpManager] and nudge scans
///
/// This helper operates on provided arguments and the documents directory.
class AttachmentIngestor {
  AttachmentIngestor({
    this.documentsDirectory,
    int maxConcurrentDownloads = _defaultMaxConcurrentDownloads,
    int? handledEventCapacity,
  }) : _maxConcurrentDownloads = maxConcurrentDownloads < 0
           ? 0
           : maxConcurrentDownloads,
       _handledAttachmentEventCapacity =
           handledEventCapacity ?? _defaultHandledAttachmentEventCapacity;

  static const int _defaultMaxConcurrentDownloads = 2;
  static const int _defaultHandledAttachmentEventCapacity =
      SyncTuning.catchupMaxLookback;

  /// The documents directory for saving attachments. If null, downloads are
  /// skipped (descriptor-only mode for testing or when fs access is not
  /// available).
  final Directory? documentsDirectory;
  final int _maxConcurrentDownloads;
  final int _handledAttachmentEventCapacity;

  final Queue<String> _downloadQueue = Queue<String>();
  final Map<String, _DownloadRequest> _pendingDownloads =
      <String, _DownloadRequest>{};
  final Set<String> _handledAttachmentEventIds = <String>{};
  final Queue<String> _handledAttachmentEventOrder = Queue<String>();
  final Set<String> _queuedKeys = <String>{};
  final Set<String> _inFlightKeys = <String>{};

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
    required LoggingService logging,
    required AttachmentIndex? attachmentIndex,
    required DescriptorCatchUpManager? descriptorCatchUp,
    required void Function() scheduleLiveScan,
    required Future<void> Function() retryNow,
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
      //
      // Bundle events are special-cased: their outer `.bundles/<id>.zip`
      // path is never written locally (we only persist the unpacked entries),
      // so [_isLocalFileMissingOrEmpty] would always report true and trigger
      // an endless re-download of the bundle on every catch-up pass. Once
      // the bundle event id is recorded as handled, skip re-processing — the
      // inner files will be repaired through their own per-entry descriptor
      // events if they go missing.
      final isBundleEvent = event.content[attachmentBundleKey] == true;
      final shouldRepairLocal =
          alreadyHandled &&
          documentsDirectory != null &&
          !isBundleEvent &&
          !_inFlightSavePaths.contains(_normalizeKey(rpAny)) &&
          _isLocalFileMissingOrEmpty(rpAny);
      final shouldProcessAttachment = !alreadyHandled || shouldRepairLocal;

      if (shouldProcessAttachment) {
        // Observability log for attachment-like events.
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
          logging.captureEvent(
            'attachmentEvent id=${event.eventId} path=$rpAny mime=$mime msgtype=$msgType hasUrl=$hasUrl hasFile=$hasEnc',
            domain: syncLoggingDomain,
            subDomain: 'attachment.observe',
          );
        } catch (_) {
          // best-effort logging only
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

      if (descriptorCatchUp?.removeIfPresent(rpAny) ?? false) {
        scheduleLiveScan();
        await retryNow();
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
    _handledAttachmentEventOrder.clear();
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
    required LoggingService logging,
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
      _handledAttachmentEventOrder.addLast(eventId);
      while (_handledAttachmentEventOrder.length >
          _handledAttachmentEventCapacity) {
        final oldest = _handledAttachmentEventOrder.removeFirst();
        _handledAttachmentEventIds.remove(oldest);
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

  /// Downloads and saves an attachment.
  ///
  /// For non-agent payloads, an existing non-empty local file is treated as
  /// up-to-date and download is skipped.
  /// For `agent_entities`/`agent_links`, downloads are always re-attempted to
  /// avoid stale reads (these files can be legitimately updated in-place).
  ///
  /// Returns `true` if a new file was written, `false` if skipped or failed.
  Future<bool> _saveAttachment({
    required Event event,
    required String relativePath,
    required LoggingService logging,
  }) async {
    final docDir = documentsDirectory;
    if (docDir == null) {
      return false;
    }

    final attachmentMimetype = event.attachmentMimetype;
    if (attachmentMimetype.isEmpty) {
      return false;
    }

    try {
      final file = _targetFile(relativePath);
      if (file == null) {
        logging.captureEvent(
          'pathTraversal.blocked path=$relativePath',
          domain: syncLoggingDomain,
          subDomain: 'attachment.save',
        );
        return false;
      }

      // Agent entities/links can be legitimately updated in-place (e.g.
      // ChangeSetEntity pending → resolved), so [_shouldSkipExistingFile]
      // never skips those. For non-agent payloads the vector clock is not
      // validated here; SmartJournalEntityLoader.load() revalidates and
      // re-downloads via DescriptorDownloader if the local file is stale.
      if (_shouldSkipExistingFile(file, relativePath)) {
        return false;
      }

      logging.captureEvent(
        'downloading $relativePath',
        domain: syncLoggingDomain,
        subDomain: 'attachment.download',
      );

      final matrixFile = await event.downloadAndDecryptAttachment();
      final downloadedBytes = matrixFile.bytes;
      if (downloadedBytes.isEmpty) {
        logging.captureEvent(
          'emptyBytes path=$relativePath',
          domain: syncLoggingDomain,
          subDomain: 'attachment.download',
        );
        return false;
      }

      // Bundle attachments ship a zip whose entries are addressed by their
      // real relative paths. Unpack each entry via the same target-file +
      // agent-dedup logic used for individual attachments and skip writing
      // the outer zip itself to disk.
      if (event.content[attachmentBundleKey] == true) {
        return _unpackBundle(
          bundleRelativePath: relativePath,
          downloadedBytes: downloadedBytes,
          logging: logging,
        );
      }

      final bytes = decodeAttachmentBytes(
        event: event,
        downloadedBytes: downloadedBytes,
        relativePath: relativePath,
        logging: logging,
      );

      await atomicWriteBytes(
        bytes: bytes,
        filePath: file.path,
        logging: logging,
        subDomain: 'attachment.write',
      );

      logging.captureEvent(
        'wrote file $relativePath bytes=${bytes.length}',
        domain: syncLoggingDomain,
        subDomain: 'attachment.save',
      );
      return true;
    } catch (e, st) {
      // Log but don't throw - SmartJournalEntityLoader can retry later
      if (e is FileSystemException && e.osError?.errorCode == 24) {
        final limits = readFileDescriptorLimits();
        logging.captureEvent(
          'emfile path=$relativePath '
          'fd.soft=${limits?.soft ?? '?'} fd.hard=${limits?.hard ?? '?'}',
          domain: syncLoggingDomain,
          subDomain: 'attachment.save.emfile',
          level: InsightLevel.warn,
        );
      }
      logging.captureException(
        e,
        domain: syncLoggingDomain,
        subDomain: 'attachment.save',
        stackTrace: st,
      );
      return false;
    }
  }

  /// Returns true when [target] should NOT be downloaded/written again —
  /// the non-agent dedup rule used by both the single-file save path and
  /// the bundle-entry write path. Agent payloads always return false so
  /// in-place updates (e.g. ChangeSetEntity pending → resolved) are never
  /// suppressed.
  bool _shouldSkipExistingFile(File target, String relativePath) {
    if (isAgentPayloadPath(relativePath)) return false;
    if (!target.existsSync()) return false;
    try {
      return target.lengthSync() > 0;
    } on FileSystemException {
      return false;
    }
  }

  /// Unpacks a zip bundle. Each entry's name is its target relative path
  /// inside the documents directory. Entries are routed through
  /// [_targetFile] for path-traversal guarding and through
  /// [_shouldSkipExistingFile] for the same non-agent dedup rule used by
  /// single-file saves. Zip decoding runs on a worker isolate to keep the
  /// sync isolate free for frame work while large bundles are parsed.
  Future<bool> _unpackBundle({
    required String bundleRelativePath,
    required Uint8List downloadedBytes,
    required LoggingService logging,
  }) async {
    final docDir = documentsDirectory;
    if (docDir == null) return false;
    final Map<String, Uint8List> decoded;
    try {
      decoded = await Isolate.run(
        () => _decodeBundleEntries(downloadedBytes),
      );
    } catch (error, stackTrace) {
      logging.captureException(
        error,
        domain: syncLoggingDomain,
        subDomain: 'attachment.bundle.decode',
        stackTrace: stackTrace,
      );
      return false;
    }
    var writtenCount = 0;
    var totalBytes = 0;
    var skippedCount = 0;
    for (final entryPath in decoded.keys) {
      final target = _targetFile(entryPath);
      if (target == null) {
        logging.captureEvent(
          'pathTraversal.blocked bundleEntry=$entryPath '
          'outer=$bundleRelativePath',
          domain: syncLoggingDomain,
          subDomain: 'attachment.bundle.entry',
        );
        continue;
      }
      if (_shouldSkipExistingFile(target, entryPath)) {
        skippedCount++;
        continue;
      }
      final bytes = decoded[entryPath]!;
      await atomicWriteBytes(
        bytes: bytes,
        filePath: target.path,
        logging: logging,
        subDomain: 'attachment.bundle.write',
      );
      writtenCount++;
      totalBytes += bytes.length;
    }
    logging.captureEvent(
      'bundleUnpacked outer=$bundleRelativePath '
      'entries=${decoded.length} written=$writtenCount '
      'skipped=$skippedCount bytes=$totalBytes',
      domain: syncLoggingDomain,
      subDomain: 'attachment.bundle.unpack',
    );
    return writtenCount > 0;
  }
}

/// Worker-isolate entry point for [ZipDecoder]. Returns a plain
/// `relativePath -> bytes` map of file entries so the decoded archive does
/// not have to cross the isolate boundary.
Map<String, Uint8List> _decodeBundleEntries(Uint8List downloadedBytes) {
  final archive = ZipDecoder().decodeBytes(downloadedBytes);
  return {
    for (final entry in archive)
      if (entry.isFile) entry.name: entry.content,
  };
}

class _DownloadRequest {
  const _DownloadRequest({
    required this.event,
    required this.relativePath,
    required this.logging,
  });

  final Event event;
  final String relativePath;
  final LoggingService logging;
}
