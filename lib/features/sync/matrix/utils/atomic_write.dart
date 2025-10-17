import 'dart:io';

import 'package:lotti/services/logging_service.dart';

/// Atomically writes [bytes] to [filePath] using a temporary file + rename.
///
/// Strategy:
/// - Write to a unique `*.tmp` alongside the destination and flush.
/// - Try a direct rename to the destination.
/// - On rename failure, best-effort move an existing destination aside to a
///   timestamped `*.bak`, retry the rename, then delete the backup.
/// - On error, delete the temp file and restore the original from the backup
///   if it was moved.
///
/// Exceptions are rethrown to the caller. Non-critical cleanup failures are
/// recorded as events to aid debugging.
Future<void> atomicWriteBytes({
  required List<int> bytes,
  required String filePath,
  LoggingService? logging,
  String subDomain = 'atomicWrite',
  String domain = 'MATRIX_SERVICE',
}) async {
  final tmpPath =
      '$filePath.tmp.${DateTime.now().microsecondsSinceEpoch}.$pid.media';
  final tmpFile = File(tmpPath);
  await tmpFile.parent.create(recursive: true);
  await tmpFile.writeAsBytes(bytes, flush: true);

  try {
    await tmpFile.rename(filePath);
  } on FileSystemException catch (_) {
    String? bakPath;
    var movedAside = false;
    try {
      if (File(filePath).existsSync()) {
        bakPath = '$filePath.bak.${DateTime.now().microsecondsSinceEpoch}';
        try {
          await File(filePath).rename(bakPath);
          movedAside = true;
        } catch (e) {
          logging?.captureEvent(
            'moveAside.failed path=$filePath err=$e',
            domain: domain,
            subDomain: subDomain,
          );
        }
      }
      await tmpFile.rename(filePath);
      if (movedAside && bakPath != null) {
        try {
          await File(bakPath).delete();
        } catch (e) {
          logging?.captureEvent(
            'cleanup.bakDelete.failed path=$bakPath err=$e',
            domain: domain,
            subDomain: subDomain,
          );
        }
      }
    } catch (e, st) {
      try {
        await tmpFile.delete();
      } catch (e2) {
        logging?.captureEvent(
          'cleanup.tmpDelete.failed path=$tmpPath err=$e2',
          domain: domain,
          subDomain: subDomain,
        );
      }
      try {
        if (movedAside && bakPath != null) {
          await File(bakPath).rename(filePath);
        }
      } catch (e3) {
        logging?.captureEvent(
          'restore.failed path=$filePath bak=$bakPath err=$e3',
          domain: domain,
          subDomain: subDomain,
        );
      }
      logging?.captureException(
        e,
        domain: domain,
        subDomain: subDomain,
        stackTrace: st,
      );
      rethrow;
    }
  }
}

/// Atomically writes [text] to [filePath] by delegating to [atomicWriteBytes].
Future<void> atomicWriteString({
  required String text,
  required String filePath,
  LoggingService? logging,
  String subDomain = 'atomicWrite',
  String domain = 'MATRIX_SERVICE',
}) async {
  await atomicWriteBytes(
    bytes: text.codeUnits,
    filePath: filePath,
    logging: logging,
    subDomain: subDomain,
    domain: domain,
  );
}
