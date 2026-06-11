/// Shared plumbing for the Daily OS design-review screenshot harnesses.
///
/// Used by the opt-in `*_screenshots_test.dart` suites (day-planning modal,
/// day page). Not a golden framework — these helpers render real widgets at
/// real device sizes and dump PNGs for human/agent design review.
///
/// IMPORTANT: anything importing this must stay opt-in (see
/// [screenshotCaptureEnabled]) because [loadScreenshotFonts] registers real
/// fonts process-wide with no way to unload, which changes text metrics for
/// unrelated tests under very_good's single-isolate optimizer.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Stable key expected on the [RepaintBoundary] that frames the app under
/// test.
const ValueKey<String> screenshotBoundaryKey = ValueKey<String>(
  'daily-os-screenshot-boundary',
);

/// Review-design device matrix. Logical sizes of real hardware so layout
/// verdicts transfer to devices; capture stays at pixelRatio 2 for sane
/// file sizes.
class ScreenshotDevice {
  const ScreenshotDevice(this.name, this.size, this.devicePixelRatio);

  final String name;
  final Size size;
  final double devicePixelRatio;

  bool get isPhone => size.width < 560;
}

const miniDevice = ScreenshotDevice('mini', Size(375, 812), 3);
const proDevice = ScreenshotDevice('pro', Size(402, 874), 3);
const proMaxDevice = ScreenshotDevice('promax', Size(440, 956), 3);
const desktopDevice = ScreenshotDevice('desktop', Size(1440, 900), 2);

const List<ScreenshotDevice> allScreenshotDevices = [
  miniDevice,
  proDevice,
  proMaxDevice,
  desktopDevice,
];

/// Whether the current run asked for screenshots (`LOTTI_SCREENSHOT_DIR`
/// or `LOTTI_CAPTURE_SCREENSHOTS=true`).
bool get screenshotCaptureEnabled =>
    Platform.environment['LOTTI_CAPTURE_SCREENSHOTS'] == 'true' ||
    Platform.environment.containsKey('LOTTI_SCREENSHOT_DIR');

/// Loads the real app fonts (Inter, Inconsolata), Material icons, and the
/// Material Design Icons webfont so captures render production glyphs
/// instead of Ahem boxes/tofu. Call from `setUpAll`.
Future<void> loadScreenshotFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<ByteData> fontBytes(String path) async {
    final bytes = await File(path).readAsBytes();
    return ByteData.view(bytes.buffer);
  }

  final inter = FontLoader('Inter')
    ..addFont(
      fontBytes('assets/fonts/Inter/Inter-VariableFont_opsz,wght.ttf'),
    );
  final inconsolata = FontLoader('Inconsolata')
    ..addFont(fontBytes('assets/fonts/Inconsolata/Inconsolata-Regular.ttf'))
    ..addFont(fontBytes('assets/fonts/Inconsolata/Inconsolata-Medium.ttf'));
  await inter.load();
  await inconsolata.load();

  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ?? '.fvm/flutter_sdk';
  final iconFont = File(
    p.join(
      flutterRoot,
      'bin',
      'cache',
      'artifacts',
      'material_fonts',
      'MaterialIcons-Regular.otf',
    ),
  );
  if (iconFont.existsSync()) {
    final icons = FontLoader('MaterialIcons')
      ..addFont(fontBytes(iconFont.path));
    await icons.load();
  }

  // The voice orb's mic glyph comes from the MDI webfont (package font →
  // prefixed family). Without it the orb renders a tofu box.
  final mdiFont = findMdiFont(
    Directory(
      p.join(
        Platform.environment['HOME'] ?? '',
        '.pub-cache',
        'hosted',
        'pub.dev',
      ),
    ),
  );
  if (mdiFont != null) {
    final mdi = FontLoader(
      'packages/flutter_material_design_icons/Material Design Icons',
    )..addFont(fontBytes(mdiFont.path));
    await mdi.load();
  }
}

/// Locates the Material Design Icons webfont inside the pub cache without
/// hard-coding the package version.
@visibleForTesting
File? findMdiFont(Directory pubHosted) {
  if (!pubHosted.existsSync()) return null;
  final dirs =
      pubHosted
          .listSync()
          .whereType<Directory>()
          .where(
            (d) =>
                p.basename(d.path).startsWith('flutter_material_design_icons-'),
          )
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
  for (final dir in dirs) {
    final font = File(
      p.join(dir.path, 'assets', 'materialdesignicons-webfont.ttf'),
    );
    if (font.existsSync()) return font;
  }
  return null;
}

/// Renders the boundary keyed [screenshotBoundaryKey] to
/// `$LOTTI_SCREENSHOT_DIR/<name>.png` (default: `screenshots/<subdir>/`).
Future<void> captureScreenshot(
  WidgetTester tester,
  String name, {
  String subdir = 'daily_os_next',
}) async {
  final boundary =
      tester.element(find.byKey(screenshotBoundaryKey)).findRenderObject()!
          as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir =
        Platform.environment['LOTTI_SCREENSHOT_DIR'] ??
        p.join('screenshots', subdir);
    final file = File(p.join(dir, '$name.png'));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(
      byteData!.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      ),
      flush: true,
    );
    stdout.writeln('wrote screenshot: ${file.path}');
  });
}

/// Pumps a fixed number of short frames — enough for entrance animations
/// without depending on `pumpAndSettle` (infinite animations never settle).
Future<void> settleFrames(WidgetTester tester, [int frames = 14]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

/// Applies [device] to the test view; remember to pair with
/// `addTearDown(tester.view.reset*)` (done here for convenience).
void applyScreenshotDevice(WidgetTester tester, ScreenshotDevice device) {
  tester.view
    ..physicalSize = device.size * device.devicePixelRatio
    ..devicePixelRatio = device.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
