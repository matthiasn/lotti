import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:matrix/matrix.dart';

Future<void> saveAttachment(Event event) async {
  final loggingDb = getIt<LoggingDb>();
  final attachmentMimetype = event.attachmentMimetype;

  if (attachmentMimetype.isNotEmpty) {
    final relativePath = event.content['relativePath'];

    try {
      if (relativePath != null) {
        loggingDb.captureEvent(
          'downloading $relativePath',
          domain: 'MATRIX_SERVICE',
          subDomain: 'writeToFile',
        );

        final matrixFile = await event.downloadAndDecryptAttachment();
        final docDir = getDocumentsDirectory();
        await writeToFile(matrixFile.bytes, '${docDir.path}$relativePath');
        loggingDb.captureEvent(
          'wrote file $relativePath',
          domain: 'MATRIX_SERVICE',
          subDomain: 'saveAttachment',
        );
      }
    } catch (exception, stackTrace) {
      loggingDb.captureException(
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
    await File(filePath).writeAsBytes(data);
  } else {
    debugPrint('No bytes for $filePath');
    getIt<LoggingDb>().captureEvent(
      'No bytes for $filePath',
      domain: 'INBOX',
      subDomain: 'writeToFile',
    );
  }
}
