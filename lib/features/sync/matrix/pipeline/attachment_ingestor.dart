// Records attachment descriptors and eagerly downloads attachments to disk.

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
///   - Eagerly download and save attachments to disk
///   - Clear pending jsonPaths via [DescriptorCatchUpManager] and nudge scans
///
/// This helper operates on provided arguments and the documents directory.
class AttachmentIngestor {
  const AttachmentIngestor({
    this.documentsDirectory,
  });

  /// The documents directory for saving attachments. If null, eager download
  /// is skipped (descriptor-only mode for testing or when fs access is not
  /// available).
  final Directory? documentsDirectory;

  /// Processes attachment-related behavior for an event.
  ///
  /// Returns `true` if a new file was written to disk, `false` otherwise.
  Future<bool> process({
    required Event event,
    required LoggingService logging,
    required AttachmentIndex? attachmentIndex,
    required DescriptorCatchUpManager? descriptorCatchUp,
    required void Function() scheduleLiveScan,
    required Future<void> Function() retryNow,
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

      // Eagerly download and save the attachment to disk.
      if (documentsDirectory != null) {
        fileWritten = await _saveAttachment(
          event: event,
          relativePath: rpAny,
          logging: logging,
        );
      }

      if (descriptorCatchUp?.removeIfPresent(rpAny) ?? false) {
        scheduleLiveScan();
        await retryNow();
      }
    }

    return fileWritten;
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
