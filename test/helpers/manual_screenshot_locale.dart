import 'dart:io';

import 'package:lotti/features/demo/seed/demo_seed_text.dart';
import 'package:lotti/features/demo/seed/l10n/demo_seed_czech_text.dart';
import 'package:lotti/features/demo/seed/l10n/demo_seed_danish_text.dart';
import 'package:lotti/features/demo/seed/l10n/demo_seed_dutch_text.dart';
import 'package:lotti/features/demo/seed/l10n/demo_seed_french_text.dart';
import 'package:lotti/features/demo/seed/l10n/demo_seed_italian_text.dart';
import 'package:lotti/features/demo/seed/l10n/demo_seed_portuguese_text.dart';
import 'package:lotti/features/demo/seed/l10n/demo_seed_romanian_text.dart';
import 'package:lotti/features/demo/seed/l10n/demo_seed_spanish_text.dart';
import 'package:lotti/features/demo/seed/l10n/demo_seed_swedish_text.dart';
import 'package:material_ui/material_ui.dart';

/// Locale requested for the current manual capture process.
///
/// Manual suites run once per locale, so both production localization and
/// deterministic user-authored demo copy can follow the same environment
/// contract without changing screenshot case IDs or filenames. Delegates to
/// the promoted demo-seed resolver so the manual screenshots and the in-app
/// demo world can never disagree about locale support.
Locale manualScreenshotLocaleFromEnvironment(Map<String, String> environment) =>
    demoSeedLocaleFromEnvironment(environment);

Locale get manualScreenshotLocale =>
    manualScreenshotLocaleFromEnvironment(Platform.environment);

/// Select deterministic fixture copy for the active manual locale.
///
/// Unlike the production `DemoSeedText` path, screenshot fixtures may pin an
/// individual string per locale via the optional named parameters; catalog
/// lookup (now served from `lib/features/demo/seed/l10n/`) remains the
/// fallback.
String manualScreenshotText({
  required String en,
  required String de,
  String? fr,
  String? it,
  String? es,
  String? cs,
  String? nl,
  String? ro,
  String? pt,
  String? da,
  String? sv,
}) => switch (manualScreenshotLocale.languageCode) {
  'de' => de,
  'fr' => fr ?? manualScreenshotFrenchText(en) ?? en,
  'it' => it ?? manualScreenshotItalianText(en) ?? en,
  'es' => es ?? manualScreenshotSpanishText(en) ?? en,
  'cs' => cs ?? manualScreenshotCzechText(en) ?? en,
  'nl' => nl ?? manualScreenshotDutchText(en) ?? en,
  'ro' => ro ?? manualScreenshotRomanianText(en) ?? en,
  'pt' => pt ?? manualScreenshotPortugueseText(en) ?? en,
  'da' => da ?? manualScreenshotDanishText(en) ?? en,
  'sv' => sv ?? manualScreenshotSwedishText(en) ?? en,
  _ => en,
};
