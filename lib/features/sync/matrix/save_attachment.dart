import 'dart:io';

import 'package:lotti/features/sync/matrix/utils/atomic_write.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:path/path.dart' as p;

/// Downloads and saves an attachment if it isn't already present on disk.
///
/// Returns true if a new file was written, false if it was skipped or failed.
Future<bool> saveAttachment(
  Event event, {
  required LoggingService loggingService,
  required Directory documentsDirectory,
}) async {
  final attachmentMimetype = event.attachmentMimetype;

  if (attachmentMimetype.isNotEmpty) {
    final relativePath = event.content['relativePath'];

    try {
      if (relativePath != null) {
        // Build a safe, normalized path under documentsDirectory.
        var rel =
            relativePath is String ? relativePath : relativePath.toString();
        if (p.isAbsolute(rel)) {
          final prefix = p.rootPrefix(rel);
          rel = rel.substring(prefix.length);
        }
        final resolved = p.normalize(p.join(documentsDirectory.path, rel));
        if (!p.isWithin(documentsDirectory.path, resolved)) {
          throw const FileSystemException('Path traversal detected');
        }
        // We control the documents directory; skip symlink parent resolution.
        // The containment check on the resolved file path is sufficient.
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

        loggingService.captureEvent(
          'downloading $relativePath',
          domain: 'MATRIX_SERVICE',
          subDomain: 'saveAttachment.download',
        );

        final matrixFile = await event.downloadAndDecryptAttachment();
        await atomicWriteBytes(
          bytes: matrixFile.bytes,
          filePath: resolved,
          logging: loggingService,
          subDomain: 'saveAttachment.write',
        );
        loggingService.captureEvent(
          'wrote file $relativePath',
          domain: 'MATRIX_SERVICE',
          subDomain: 'saveAttachment',
        );
        return true;
      }
    } catch (exception, stackTrace) {
      loggingService.captureException(
        'failed to save attachment $attachmentMimetype $relativePath',
        domain: 'MATRIX_SERVICE',
        subDomain: 'saveAttachment',
        stackTrace: stackTrace,
      );
    }
  }
  return false;
}
