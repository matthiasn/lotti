import 'dart:io';

import 'package:flutter/foundation.dart';
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
          subDomain: 'writeToFile',
        );

        final matrixFile = await event.downloadAndDecryptAttachment();
        await _writeToFile(
          matrixFile.bytes,
          resolved,
          loggingService,
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

/// Writes bytes to [filePath] atomically using a temporary file + rename.
///
/// Rationale: On some platforms (notably Windows), `File.rename` will fail if
/// the destination already exists or is open by another process. To remain
/// robust and avoid partial writes, we:
/// - write to a uniquely named temp file and flush it;
/// - attempt a direct rename to the target;
/// - if that fails, we best-effort move any existing target aside (to a
///   timestamped .bak), retry the rename, then clean up the backup;
/// - on error, we delete the temp file and restore the original when possible.
///
/// This keeps the operation effectively atomic for readers while handling the
/// cross‑platform rename semantics and in‑use destination edge cases.
Future<void> _writeToFile(
  Uint8List? data,
  String filePath,
  LoggingService loggingService,
) async {
  if (data == null) {
    debugPrint('No bytes for $filePath');
    loggingService.captureEvent(
      'No bytes for $filePath',
      domain: 'INBOX',
      subDomain: 'writeToFile',
    );
    return;
  }

  // Ensure parent directory exists
  final target = File(filePath);
  await target.parent.create(recursive: true);

  // Atomic write: temp file + rename
  final tmpPath = '$filePath.tmp.${DateTime.now().microsecondsSinceEpoch}.$pid';
  final tmpFile = File(tmpPath);
  await tmpFile.writeAsBytes(data, flush: true);

  try {
    await tmpFile.rename(filePath);
  } on FileSystemException catch (_) {
    String? bakPath;
    var movedAside = false;
    try {
      bakPath = '$filePath.bak.${DateTime.now().microsecondsSinceEpoch}.$pid';
      try {
        await target.rename(bakPath);
        movedAside = true;
      } catch (_) {}
      await tmpFile.rename(filePath);
      if (movedAside) {
        try {
          await File(bakPath).delete();
        } catch (_) {}
      }
    } catch (e) {
      try {
        await tmpFile.delete();
      } catch (_) {}
      try {
        if (movedAside && bakPath != null) {
          await File(bakPath).rename(filePath);
        }
      } catch (_) {}
      rethrow;
    }
  }
}
