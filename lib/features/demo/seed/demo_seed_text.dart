import 'dart:io';
import 'dart:ui' show Locale;

import 'package:lotti/features/demo/seed/l10n/demo_seed_czech_text.dart';
import 'package:lotti/features/demo/seed/l10n/demo_seed_danish_text.dart';
import 'package:lotti/features/demo/seed/l10n/demo_seed_dutch_text.dart';
import 'package:lotti/features/demo/seed/l10n/demo_seed_french_text.dart';
import 'package:lotti/features/demo/seed/l10n/demo_seed_italian_text.dart';
import 'package:lotti/features/demo/seed/l10n/demo_seed_portuguese_text.dart';
import 'package:lotti/features/demo/seed/l10n/demo_seed_romanian_text.dart';
import 'package:lotti/features/demo/seed/l10n/demo_seed_spanish_text.dart';
import 'package:lotti/features/demo/seed/l10n/demo_seed_swedish_text.dart';

/// Resolves one demo-world string: authored in English and German, with the
/// remaining locales looked up from the per-language catalogs keyed by the
/// English string ([demoSeedTextForLocale]).
typedef DemoSeedText = String Function(String en, String de);

/// Language codes the demo seed (and the manual screenshot suites built on
/// the same fixture) can localize.
const Set<String> demoSeedLanguageCodes = {
  'en',
  'de',
  'fr',
  'it',
  'es',
  'cs',
  'nl',
  'ro',
  'pt',
  'da',
  'sv',
};

/// Locale requested via `LOTTI_MANUAL_LOCALE`, defaulting to English.
///
/// Manual screenshot suites run once per locale, so both production
/// localization and deterministic user-authored demo copy follow the same
/// environment contract without changing screenshot case IDs or filenames.
Locale demoSeedLocaleFromEnvironment(Map<String, String> environment) {
  final languageCode = environment['LOTTI_MANUAL_LOCALE'] ?? 'en';
  if (!demoSeedLanguageCodes.contains(languageCode)) {
    throw ArgumentError.value(
      languageCode,
      'LOTTI_MANUAL_LOCALE',
      'Supported manual screenshot locales are en, de, fr, it, es, cs, nl, '
          'ro, pt, da, and sv.',
    );
  }
  return Locale(languageCode);
}

/// Deterministic demo copy for [locale].
///
/// English and German come straight from the authored string pair; every
/// other supported locale resolves through its catalog and falls back to
/// English for strings without a catalog row.
DemoSeedText demoSeedTextForLocale(Locale locale) {
  return switch (locale.languageCode) {
    'de' => (en, de) => de,
    'fr' => (en, de) => manualScreenshotFrenchText(en) ?? en,
    'it' => (en, de) => manualScreenshotItalianText(en) ?? en,
    'es' => (en, de) => manualScreenshotSpanishText(en) ?? en,
    'cs' => (en, de) => manualScreenshotCzechText(en) ?? en,
    'nl' => (en, de) => manualScreenshotDutchText(en) ?? en,
    'ro' => (en, de) => manualScreenshotRomanianText(en) ?? en,
    'pt' => (en, de) => manualScreenshotPortugueseText(en) ?? en,
    'da' => (en, de) => manualScreenshotDanishText(en) ?? en,
    'sv' => (en, de) => manualScreenshotSwedishText(en) ?? en,
    _ => (en, de) => en,
  };
}

/// Demo copy for the locale requested through `LOTTI_MANUAL_LOCALE`.
///
/// Preserves the manual screenshot suites' environment contract: no variable
/// means English, an unsupported code throws. [environment] defaults to
/// [Platform.environment].
DemoSeedText demoSeedTextFromEnvironment([Map<String, String>? environment]) =>
    demoSeedTextForLocale(
      demoSeedLocaleFromEnvironment(environment ?? Platform.environment),
    );
