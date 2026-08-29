import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';
import 'package:path/path.dart' as p;

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final outputDir =
        Platform.environment['LOTTI_SCREENSHOT_DIR'] ??
        p.join('screenshots', 'manual');
    final safeName = name.replaceAll(RegExp('[^A-Za-z0-9_.-]'), '_');
    final file = File(p.join(outputDir, '$safeName.png'));
    // On an iOS simulator the host already took the whole screen — status
    // bar included — when the test announced this capture point (see
    // tool/store_screenshots/ios.sh). These bytes are the Flutter view alone
    // and arrive only after the run, so writing them here would overwrite
    // the better file with a worse one.
    if (Platform.environment['LOTTI_SIMULATOR_UDID']?.isNotEmpty ?? false) {
      // A marker the host missed (a delayed log line on a loaded runner)
      // must fail the run, not leave a silently partial set behind.
      if (!file.existsSync()) {
        throw StateError('host capture missing for $name: ${file.path}');
      }
      stdout.writeln('host captured screenshot: ${file.path}');
      return true;
    }
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    stdout.writeln('wrote screenshot: ${file.path}');
    return true;
  },
);
