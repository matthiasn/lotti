// Records attachment descriptors and queues attachment downloads to disk.

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/pipeline/descriptor_catch_up_manager.dart';
import 'package:lotti/features/sync/matrix/utils/atomic_write.dart';
import 'package:lotti/services/logging_service.dart';
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
  }) : _maxConcurrentDownloads =
            maxConcurrentDownloads < 0 ? 0 : maxConcurrentDownloads;

  static const int _defaultMaxConcurrentDownloads = 2;

  /// The documents directory for saving attachments. If null, downloads are
  /// skipped (descriptor-only mode for testing or when fs access is not
  /// available).
  final Directory? documentsDirectory;
  final int _maxConcurrentDownloads;

  final Queue<String> _downloadQueue = Queue<String>();
  final Map<String, _DownloadRequest> _pendingDownloads =
      <String, _DownloadRequest>{};
  final Set<String> _queuedKeys = <String>{};
  final Set<String> _inFlightKeys = <String>{};
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

    // Record descriptors when present and emit a compact observability line.
    final rpAny = event.content['relativePath'];
    if (rpAny is String && rpAny.isNotEmpty) {
      attachmentIndex?.record(event);
      // Observability log for attachment-like events.
      try {
        final mime = event.attachmentMimetype;
        final content = event.content;
        final hasUrl = content.containsKey('url') ||
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
          fileWritten = await _saveAttachment(
            event: event,
            relativePath: rpAny,
            logging: logging,
          );
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
    _queuedKeys.clear();
    _idleCompleter?.complete();
    _idleCompleter = null;
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
    while (
        _inFlightCount < _maxConcurrentDownloads && _downloadQueue.isNotEmpty) {
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

  String _normalizeKey(String relativePath) {
    final trimmed = relativePath.replaceFirst(RegExp(r'^[\\/]+'), '');
    return '/${trimmed.replaceAll(r'\\', '/')}';
  }

  /// Downloads and saves an attachment if it isn't already present on disk.
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
      // Build a safe, normalized path under documentsDirectory.
      var rel = relativePath;
      if (p.isAbsolute(rel)) {
        final prefix = p.rootPrefix(rel);
        rel = rel.substring(prefix.length);
      }
      final resolved = p.normalize(p.join(docDir.path, rel));
      if (!p.isWithin(docDir.path, resolved)) {
        logging.captureEvent(
          'pathTraversal.blocked path=$relativePath resolved=$resolved',
          domain: syncLoggingDomain,
          subDomain: 'attachment.save',
        );
        return false;
      }

      final file = File(resolved);
      // Fast-path dedupe: if the file already exists and is non-empty,
      // skip re-downloading to avoid repeated writes and log spam.
      // Note: We don't validate the file's vector clock here because
      // SmartJournalEntityLoader.load() will do that validation and
      // re-download via DescriptorDownloader if the local file is stale.
      if (file.existsSync()) {
        try {
          final len = file.lengthSync();
          if (len > 0) {
            return false; // already present
          }
        } catch (_) {
          // If querying length fails, fall through to re-download.
        }
      }

      logging.captureEvent(
        'downloading $relativePath',
        domain: syncLoggingDomain,
        subDomain: 'attachment.download',
      );

      final matrixFile = await event.downloadAndDecryptAttachment();
      final bytes = matrixFile.bytes;
      if (bytes.isEmpty) {
        logging.captureEvent(
          'emptyBytes path=$relativePath',
          domain: syncLoggingDomain,
          subDomain: 'attachment.download',
        );
        return false;
      }

      await atomicWriteBytes(
        bytes: bytes,
        filePath: resolved,
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
      logging.captureException(
        e,
        domain: syncLoggingDomain,
        subDomain: 'attachment.save',
        stackTrace: st,
      );
      return false;
    }
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
  final LoggingService logging;
}
