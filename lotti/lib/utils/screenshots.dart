import 'dart:io';

import 'package:intl/intl.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/location.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:window_manager/window_manager.dart';

Future<ImageData> takeScreenshotMac() async {
  String id = uuid.v1();
  String filename = '$id.screenshot.png';
  DateTime created = DateTime.now();
  String day = DateFormat('yyyy-MM-dd').format(created);
  String relativePath = '/images/$day/';
  String directory = await createAssetDirectory(relativePath);

  await windowManager.minimize();

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

  await windowManager.show();
  return imageData;
}
