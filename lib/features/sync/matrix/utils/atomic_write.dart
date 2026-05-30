import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lotti/services/domain_logging.dart';

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
  DomainLogger? logging,
  String subDomain = 'atomicWrite',
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
      // ignore: avoid_slow_async_io
      if (await File(filePath).exists()) {
        bakPath = '$filePath.bak.${DateTime.now().microsecondsSinceEpoch}';
        try {
          await File(filePath).rename(bakPath);
          movedAside = true;
        } catch (e) {
          logging?.log(
            LogDomain.sync,
            'moveAside.failed path=$filePath err=$e',
            subDomain: subDomain,
          );
        }
      }
      await tmpFile.rename(filePath);
      if (movedAside && bakPath != null) {
        try {
          await File(bakPath).delete();
        } catch (e) {
          logging?.log(
            LogDomain.sync,
            'cleanup.bakDelete.failed path=$bakPath err=$e',
            subDomain: subDomain,
          );
        }
      }
    } catch (e, st) {
      try {
        await tmpFile.delete();
      } catch (e2) {
        logging?.log(
          LogDomain.sync,
          'cleanup.tmpDelete.failed path=$tmpPath err=$e2',
          subDomain: subDomain,
        );
      }
      try {
        if (movedAside && bakPath != null) {
          await File(bakPath).rename(filePath);
        }
      } catch (e3) {
        logging?.log(
          LogDomain.sync,
          'restore.failed path=$filePath bak=$bakPath err=$e3',
          subDomain: subDomain,
        );
      }
      logging?.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: subDomain,
      );
      rethrow;
    }
  }
}

/// Atomically writes [text] to [filePath] by delegating to [atomicWriteBytes].
Future<void> atomicWriteString({
  required String text,
  required String filePath,
  DomainLogger? logging,
  String subDomain = 'atomicWrite',
}) async {
  await atomicWriteBytes(
    bytes: utf8.encode(text),
    filePath: filePath,
    logging: logging,
    subDomain: subDomain,
  );
}
