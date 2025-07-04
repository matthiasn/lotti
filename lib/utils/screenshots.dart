import 'dart:async';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/lotti_logger.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:window_manager/window_manager.dart';

Future<ImageData> takeScreenshotMac() async {
  try {
    final id = uuid.v1();
    final filename = '$id.screenshot.jpg';
    final created = DateTime.now();
    final day = DateFormat('yyyy-MM-dd').format(created);
    final relativePath = '/images/$day/';
    final directory = await createAssetDirectory(relativePath);

    await windowManager.minimize();

    await Future<void>.delayed(const Duration(seconds: 1));

    final process = await Process.start(
      'screencapture',
      ['-tjpg', filename],
      runInShell: true,
      workingDirectory: directory,
    );

    await stdout.addStream(process.stdout);
    await stderr.addStream(process.stderr);

    await process.exitCode;

    final imageData = ImageData(
      imageId: id,
      imageFile: filename,
      imageDirectory: relativePath,
      capturedAt: created,
    );

    await windowManager.show();

    return imageData;
  } catch (exception, stackTrace) {
    getIt<LottiLogger>().exception(
      exception,
      domain: 'SCREENSHOT',
      stackTrace: stackTrace,
    );
    rethrow;
  }
}
