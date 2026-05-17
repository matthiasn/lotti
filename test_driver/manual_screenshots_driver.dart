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
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    stdout.writeln('wrote screenshot: ${file.path}');
    return true;
  },
);
