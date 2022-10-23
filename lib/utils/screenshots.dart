import 'dart:io';

import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:window_manager/window_manager.dart';

Future<ImageData> takeScreenshotMac() async {
  try {
    final hide = await getIt<JournalDb>().getConfigFlag(hideForScreenshotFlag);
    final id = uuid.v1();
    final filename = '$id.screenshot.jpg';
    final created = DateTime.now();
    final day = DateFormat('yyyy-MM-dd').format(created);
    final relativePath = '/images/$day/';
    final directory = await createAssetDirectory(relativePath);

    if (hide) {
      await windowManager.minimize();
    }

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

    if (hide) {
      await windowManager.show();
    }

    return imageData;
  } catch (exception, stackTrace) {
    getIt<LoggingDb>().captureException(
      exception,
      domain: 'SCREENSHOT',
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

Future<void> takeScreenshotWithLinked() async {
  final linkedId = await getIdFromSavedRoute();
  await createScreenshot(linkedId: linkedId);
}

Future<void> registerScreenshotHotkey() async {
  if (Platform.isMacOS) {
    final screenshotKey = HotKey(
      KeyCode.digit3,
      modifiers: [
        KeyModifier.shift,
        KeyModifier.meta,
      ],
    );
    await hotKeyManager.register(
      screenshotKey,
      keyDownHandler: (hotKey) async {
        final enabled = await getIt<JournalDb>()
            .getConfigFlag(listenToScreenshotHotkeyFlag);

        if (enabled) {
          await takeScreenshotWithLinked();
        }
      },
    );
  }
}
