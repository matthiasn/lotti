import 'dart:io';

import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/location.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/main.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:window_manager/window_manager.dart';

final JournalDb db = getIt<JournalDb>();

Future<ImageData> takeScreenshotMac() async {
  bool hide = await db.getConfigFlag('hide_for_screenshot');

  String id = uuid.v1();
  String filename = '$id.screenshot.png';
  DateTime created = DateTime.now();
  String day = DateFormat('yyyy-MM-dd').format(created);
  String relativePath = '/images/$day/';
  String directory = await createAssetDirectory(relativePath);

  if (hide) {
    await windowManager.minimize();
  }

  Process process = await Process.start(
    'screencapture',
    [filename],
    runInShell: true,
    workingDirectory: directory,
  );

  stdout.addStream(process.stdout);
  stderr.addStream(process.stderr);

  await process.exitCode;

  DeviceLocation location = DeviceLocation();
  Geolocation? geolocation = await location.getCurrentGeoLocation().timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );

  ImageData imageData = ImageData(
    imageId: id,
    imageFile: filename,
    imageDirectory: relativePath,
    capturedAt: created,
    geolocation: geolocation,
  );

  if (hide) {
    await windowManager.show();
  }

  return imageData;
}

Future<void> registerScreenshotHotkey() async {
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();

  if (Platform.isMacOS) {
    HotKey screenshotKey = HotKey(
      KeyCode.digit3,
      modifiers: [
        KeyModifier.shift,
        KeyModifier.meta,
      ],
    );
    hotKeyManager.register(
      screenshotKey,
      keyDownHandler: (hotKey) async {
        bool enabled =
            await db.getConfigFlag('listen_to_global_screenshot_hotkey');

        if (enabled) {
          ImageData imageData = await takeScreenshotMac();
          await persistenceLogic.createImageEntry(
            imageData,
          );
        }
      },
    );
  }
}
