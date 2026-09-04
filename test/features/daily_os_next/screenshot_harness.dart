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
import 'package:lotti/features/ai/ui/animation/ai_state_shader_animation.dart';
import 'package:path/path.dart' as p;

import '../../test_utils/screenshot_harness.dart';

export '../../helpers/manual_screenshot_locale.dart';

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

/// Loads every font a capture needs so glyphs render as production draws them
/// instead of Ahem boxes and tofu.
///
/// Delegates the bulk to [loadAppFonts], which reads `FontManifest.json` — the
/// same list `flutter test` ships — and therefore picks up the app's own
/// families, Material icons, and *every* icon-font package automatically.
///
/// This used to hand-register each family, hunting the pub cache for the
/// Material Design Icons webfont by name. That shape breaks silently every
/// time an icon-font package is added: the glyphs resolve to codepoints the
/// loaded fonts do not carry, so captures publish tofu boxes while the running
/// app is perfectly fine — which is exactly what happened when Lucide arrived.
/// Reading the manifest cannot fall behind in that way.
///
/// [captureScreenshot] loads the runtime fragment programs inside each active
/// test render context. Call this from `setUpAll`.
Future<void> loadScreenshotFonts() async {
  await loadAppFonts();

  // Not in the manifest, and cannot be: Flutter's headless test engine does
  // not resolve the platform-generic `monospace` family, so production widgets
  // that deliberately ask for a generic mono font render Ahem bars. Registering
  // a bundled face under that alias is the only way to close it.
  final bytes = await File(
    'assets/fonts/Inconsolata/Inconsolata-Regular.ttf',
  ).readAsBytes();
  final medium = await File(
    'assets/fonts/Inconsolata/Inconsolata-Medium.ttf',
  ).readAsBytes();
  await (FontLoader('monospace')
        ..addFont(Future.value(ByteData.view(bytes.buffer)))
        ..addFont(Future.value(ByteData.view(medium.buffer))))
      .load();
}

/// Renders the boundary keyed [screenshotBoundaryKey] to
/// `$LOTTI_SCREENSHOT_DIR/<name>.png` (default: `screenshots/<subdir>/`).
Future<void> captureScreenshot(
  WidgetTester tester,
  String name, {
  String subdir = 'daily_os_next',
}) async {
  // Runtime-effect loading is tied to the active widget-test render context.
  // Await both programs here (inside the test body), then pump the
  // FutureBuilders once more before inspecting or rasterizing the tree.
  await Future.wait([
    AiStateShaderProgramCache.loadVoiceInput(),
    AiStateShaderProgramCache.loadThinkingLine(),
  ]);
  await tester.pump();
  _expectProductionShaderPainters(tester, screenshotName: name);
  var boundary =
      tester.element(find.byKey(screenshotBoundaryKey)).findRenderObject()!
          as RenderRepaintBoundary;
  // The headless renderer can populate a new theme's glyph atlas during the
  // first off-screen raster. Publishing that first image occasionally drops
  // most characters from otherwise correctly laid-out dark-theme labels.
  // Warm the exact production boundary once, then pump the completed raster
  // work before encoding the review image. This is deterministic and remains
  // isolated to opt-in manual capture suites.
  await tester.runAsync(() async {
    final warmup = await boundary.toImage(pixelRatio: 2);
    warmup.dispose();
  });
  await tester.pump();
  boundary =
      tester.element(find.byKey(screenshotBoundaryKey)).findRenderObject()!
          as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
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
    } finally {
      image.dispose();
    }
  });
}

/// Fails a manual capture instead of quietly publishing simplified shader
/// fallbacks. The fallbacks remain useful for unsupported runtime platforms,
/// but documentation imagery must show the same fragment programs as the app.
void _expectProductionShaderPainters(
  WidgetTester tester, {
  required String screenshotName,
}) {
  final fallbackPainters = find
      .byType(CustomPaint)
      .evaluate()
      .map((element) => (element.widget as CustomPaint).painter)
      .where(
        (painter) =>
            painter is AiVoiceInputFallbackPainter ||
            painter is AiThinkingLineFallbackPainter,
      )
      .map((painter) => painter.runtimeType)
      .toList(growable: false);

  expect(
    fallbackPainters,
    isEmpty,
    reason:
        'Manual screenshot "$screenshotName" contains simplified shader '
        'fallbacks ($fallbackPainters). Preload and render the bundled '
        'fragment programs before capture.',
  );
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
  // A FragmentProgram belongs to the active flutter_tester render context.
  // The production cache is scoped to the current testWidgets zone, so manual
  // suites can run several cases in one process without carrying a program
  // into the next render context.
  tester.view
    ..physicalSize = device.size * device.devicePixelRatio
    ..devicePixelRatio = device.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
