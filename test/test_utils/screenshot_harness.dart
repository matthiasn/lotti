import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/themes/theme.dart';

import '../widget_test_utils.dart';

/// Reusable harness for capturing in-app screenshots of a widget or flow at
/// real device sizes, fully offline and deterministically.
///
/// It renders a surface inside the production app shell ([makeTestableWidgetNoScroll]
/// + the real `withOverrides` theme), loads every bundled font so glyphs and
/// icons render for real, and writes a PNG through Flutter's golden mechanism.
///
/// This is NOT a golden *test* — there are no committed reference images to
/// diff against. It is an on-demand visualization tool: write a throwaway
/// capture test that calls [captureInApp], run it with `--update-goldens` to
/// emit the PNGs, view/share them, then delete the throwaway test. See the
/// `app-screenshots` skill for the full workflow.
///
/// The default [captureInApp] output directory is `screenshots`, which is
/// gitignored repo-wide — so emitted PNGs can never be committed by accident.
///
/// Example:
/// ```dart
/// void main() {
///   setUpAll(loadAppFonts);
///   // ... setUpTestGetIt + service registrations ...
///
///   testWidgets('create modal — phone', (tester) async {
///     await captureInApp(
///       tester,
///       child: const ProjectsTabPage(),
///       name: 'create_modal_phone',
///       size: ScreenshotViewport.phone,
///       overrides: [/* providers the surface reads */],
///       interaction: (tester) async {
///         await tester.tap(find.bySemanticsLabel('New Project'));
///       },
///     );
///   });
/// }
/// ```

/// Common capture viewports (logical pixels).
abstract final class ScreenshotViewport {
  /// Narrow phone — drives the modal system's bottom-sheet branch and the
  /// single-pane (mobile) layouts.
  static const Size phone = Size(390, 844);

  /// Wide desktop — drives split-view layouts and the centered-dialog branch.
  static const Size desktop = Size(1280, 800);
}

/// Loads every bundled font — the app's own families plus the framework's
/// Material/Cupertino icon fonts and any icon-font packages — so captured
/// frames render real glyphs instead of the test runner's fallback boxes.
///
/// Reads `FontManifest.json` from the test asset bundle (the same source
/// `flutter test` ships), so it stays correct as fonts are added or removed
/// without hardcoding asset paths. Call once in `setUpAll`.
Future<void> loadAppFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font
        in (entry['fonts'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

/// The app theme as rendered for screenshots: the production [withOverrides]
/// theme with the bundled `Inter` family applied to the Material text themes.
///
/// The bare test [ThemeData] otherwise falls back to an unbundled default font
/// for any text that reads `Theme.of(context).textTheme` (modal titles, input
/// decoration labels, …), which renders as boxes. Design-system token text
/// already pins `Inter`, so only the Material text themes need the nudge.
ThemeData screenshotTheme({bool dark = true}) {
  final base = withOverrides(
    dark ? ThemeData.dark(useMaterial3: true) : ThemeData(useMaterial3: true),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'Inter'),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Inter'),
  );
}

/// Renders [child] inside the app shell at [size] and writes a PNG via the
/// golden mechanism (run the capture test with `--update-goldens`).
///
/// [interaction] runs after the initial settle — use it to open a modal, tap a
/// FAB, focus a field, etc. before the frame is captured. [overrides] are the
/// Riverpod overrides for the providers the surface reads.
///
/// The PNG is written to `<outputDir>/<name>.png`, resolved relative to the
/// *calling test file's* directory (standard `matchesGoldenFile` behavior), so
/// where you place the throwaway capture test determines where images land.
Future<void> captureInApp(
  WidgetTester tester, {
  required Widget child,
  required String name,
  Size size = ScreenshotViewport.phone,
  bool dark = true,
  double devicePixelRatio = 2.0,
  List<Override> overrides = const [],
  Future<void> Function(WidgetTester tester)? interaction,
  String outputDir = 'screenshots',
}) async {
  tester.view
    ..physicalSize = size * devicePixelRatio
    ..devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      child,
      theme: screenshotTheme(dark: dark),
      mediaQueryData: MediaQueryData(size: size),
      overrides: overrides,
    ),
  );
  await tester.pumpAndSettle();

  if (interaction != null) {
    await interaction(tester);
    await tester.pumpAndSettle();
  }

  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('$outputDir/$name.png'),
  );
}
