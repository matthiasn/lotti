import 'dart:io';

import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:window_manager/window_manager.dart';

final JournalDb db = getIt<JournalDb>();
final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();

Future<ImageData> takeScreenshotMac() async {
  final hide = await db.getConfigFlag('hide_for_screenshot');
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
}

Future<void> takeScreenshotWithLinked() async {
  final linkedId = await getIdFromSavedRoute();
  final imageData = await takeScreenshotMac();
  final journalEntity = await persistenceLogic.createImageEntry(
    imageData,
    linkedId: linkedId,
  );
  if (journalEntity != null) {
    persistenceLogic.addGeolocation(journalEntity.meta.id);
  }
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
        final enabled =
            await db.getConfigFlag('listen_to_global_screenshot_hotkey');

        if (enabled) {
          await takeScreenshotWithLinked();
        }
      },
    );
  }
}
