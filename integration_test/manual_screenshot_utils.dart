import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

const ValueKey<String> manualScreenshotBoundaryKey = ValueKey<String>(
  'manual_screenshot_boundary',
);
const _screenshotDirFromDartDefine = String.fromEnvironment(
  'LOTTI_SCREENSHOT_DIR',
);

Widget manualScreenshotBoundary({required Widget child}) {
  return RepaintBoundary(
    key: manualScreenshotBoundaryKey,
    child: child,
  );
}

Future<void> captureManualScreenshot({
  required IntegrationTestWidgetsFlutterBinding binding,
  required WidgetTester tester,
  required String name,
}) async {
  if (Platform.isIOS || Platform.isAndroid) {
    await binding.takeScreenshot(name);
    return;
  }

  final boundary =
      tester
              .element(find.byKey(manualScreenshotBoundaryKey))
              .findRenderObject()!
          as RenderRepaintBoundary;
  final image = await boundary.toImage(
    pixelRatio: tester.view.devicePixelRatio,
  );
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

  if (byteData == null) {
    throw StateError('Could not encode screenshot "$name" as PNG');
  }

  final outputDir = _screenshotDirFromDartDefine.isNotEmpty
      ? _screenshotDirFromDartDefine
      : Platform.environment['LOTTI_SCREENSHOT_DIR'] ??
            p.join('screenshots', 'manual');
  final safeName = name.replaceAll(RegExp('[^A-Za-z0-9_.-]'), '_');
  final file = File(p.join(outputDir, '$safeName.png'));
  await file.parent.create(recursive: true);
  await file.writeAsBytes(
    byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    ),
    flush: true,
  );
}
