import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:matrix/matrix.dart';

Future<void> saveAttachment(Event event) async {
  final attachmentMimetype = event.attachmentMimetype;

  if (attachmentMimetype.isNotEmpty) {
    final relativePath = event.content['relativePath'];

    try {
      if (relativePath != null) {
        getIt<LoggingService>().captureEvent(
          'downloading $relativePath',
          domain: 'MATRIX_SERVICE',
          subDomain: 'writeToFile',
        );

        final matrixFile = await event.downloadAndDecryptAttachment();
        final docDir = getDocumentsDirectory();
        await writeToFile(matrixFile.bytes, '${docDir.path}$relativePath');
        getIt<LoggingService>().captureEvent(
          'wrote file $relativePath',
          domain: 'MATRIX_SERVICE',
          subDomain: 'saveAttachment',
        );
      }
    } catch (exception, stackTrace) {
      getIt<LoggingService>().captureException(
        'failed to save attachment $attachmentMimetype $relativePath',
        domain: 'MATRIX_SERVICE',
        subDomain: 'saveAttachment',
        stackTrace: stackTrace,
      );
    }
  }
}

Future<void> writeToFile(Uint8List? data, String filePath) async {
  if (data != null) {
    final file = await File(filePath).create(recursive: true);
    await file.writeAsBytes(data);
  } else {
    debugPrint('No bytes for $filePath');
    getIt<LoggingService>().captureEvent(
      'No bytes for $filePath',
      domain: 'INBOX',
      subDomain: 'writeToFile',
    );
  }
}
