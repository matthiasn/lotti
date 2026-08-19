import '../../../test_utils/screenshot_harness.dart';

/// Loads every font a design-review screenshot needs so captures render real
/// type and real glyphs instead of the blocky FlutterTest fallback.
///
/// Delegates to [loadAppFonts], which reads `FontManifest.json` — the same list
/// `flutter test` ships — so the app's own families, Material icons and every
/// icon-font package are picked up automatically.
///
/// This previously hand-registered Inter, Inconsolata and MaterialIcons by
/// path. That shape silently omits anything added later: when the Lucide icon
/// package arrived, captures published tofu boxes while the running app drew
/// the glyphs correctly, which makes a screenshot review worse than useless
/// because it looks like a real defect.
///
/// OPT-IN ONLY: `FontLoader` registers fonts process-wide with no way to
/// unload, which changes text metrics for unrelated tests under the shared
/// CI isolate — so this is only called from the opt-in screenshot harnesses.
Future<void> loadScreenshotFonts() => loadAppFonts();
