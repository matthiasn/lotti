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

/// Loads the real app fonts (Inter, Inconsolata), color emoji, Material icons,
/// and the Material Design Icons webfont so captures render production glyphs
/// instead of Ahem boxes/tofu. [captureScreenshot] loads the runtime fragment
/// programs inside each active test render context. Call this from `setUpAll`.
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
  // Flutter's headless test engine does not resolve the platform-generic
  // `monospace` family. Register the same bundled face under that alias so
  // production widgets that intentionally request a generic mono font render
  // actual text instead of Ahem bars in manual captures.
  final genericMonospace = FontLoader('monospace')
    ..addFont(fontBytes('assets/fonts/Inconsolata/Inconsolata-Regular.ttf'))
    ..addFont(fontBytes('assets/fonts/Inconsolata/Inconsolata-Medium.ttf'));
  await inter.load();
  await inconsolata.load();
  await genericMonospace.load();

  // Device builds resolve emoji through the platform font fallback. The
  // headless Linux test engine does not discover that font by itself, so SAS
  // verification rows otherwise publish literal "NO GLYPH" boxes. Register
  // the installed Noto face under the same family used by the design-system
  // fallback list.
  final emojiFont = findEmojiFont();
  if (emojiFont != null) {
    final emoji = FontLoader('Noto Color Emoji')
      ..addFont(fontBytes(emojiFont.path));
    await emoji.load();
  }

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

/// Finds the standard Noto Color Emoji installation used by Linux capture
/// runners. Other platforms already provide their native emoji fallback.
@visibleForTesting
File? findEmojiFont() {
  const candidates = [
    '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf',
    '/usr/share/fonts/noto-color-emoji/NotoColorEmoji.ttf',
  ];
  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) return file;
  }
  return null;
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
  // Runtime-effect loading is tied to the active widget-test render context.
  // Await both programs here (inside the test body), then pump the
  // FutureBuilders once more before inspecting or rasterizing the tree.
  await Future.wait([
    AiStateShaderProgramCache.loadVoiceInput(),
    AiStateShaderProgramCache.loadThinkingLine(),
  ]);
  await tester.pump();
  _expectProductionShaderPainters(tester, screenshotName: name);
  final boundary =
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
  // Manual suites run several testWidgets cases in one process, each with a
  // fresh context, so carrying the memoized program across cases can hang the
  // next rasterization. Reload it lazily after every context reset.
  AiStateShaderProgramCache.reset();
  tester.view
    ..physicalSize = device.size * device.devicePixelRatio
    ..devicePixelRatio = device.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
