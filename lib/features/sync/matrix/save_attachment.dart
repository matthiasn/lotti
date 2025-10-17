import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

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
        final filePath = '${documentsDirectory.path}$relativePath';
        final file = File(filePath);
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
          filePath,
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

Future<void> _writeToFile(
  Uint8List? data,
  String filePath,
  LoggingService loggingService,
) async {
  if (data != null) {
    final file = await File(filePath).create(recursive: true);
    await file.writeAsBytes(data);
  } else {
    debugPrint('No bytes for $filePath');
    loggingService.captureEvent(
      'No bytes for $filePath',
      domain: 'INBOX',
      subDomain: 'writeToFile',
    );
  }
}
