import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

Future<void> saveAttachment(
  Event event, {
  required LoggingService loggingService,
  required Directory documentsDirectory,
}) async {
  final attachmentMimetype = event.attachmentMimetype;

  if (attachmentMimetype.isNotEmpty) {
    final relativePath = event.content['relativePath'];

    try {
      if (relativePath != null) {
        loggingService.captureEvent(
          'downloading $relativePath',
          domain: 'MATRIX_SERVICE',
          subDomain: 'writeToFile',
        );

        final matrixFile = await event.downloadAndDecryptAttachment();
        await _writeToFile(
          matrixFile.bytes,
          '${documentsDirectory.path}$relativePath',
          loggingService,
        );
        loggingService.captureEvent(
          'wrote file $relativePath',
          domain: 'MATRIX_SERVICE',
          subDomain: 'saveAttachment',
        );
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
