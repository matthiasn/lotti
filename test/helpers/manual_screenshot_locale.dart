import 'dart:io';

import 'package:flutter/material.dart';

import 'manual_screenshot_czech_text.dart';
import 'manual_screenshot_french_text.dart';
import 'manual_screenshot_romanian_text.dart';

/// Locale requested for the current manual capture process.
///
/// Manual suites run once per locale, so both production localization and
/// deterministic user-authored demo copy can follow the same environment
/// contract without changing screenshot case IDs or filenames.
Locale manualScreenshotLocaleFromEnvironment(Map<String, String> environment) {
  final languageCode = environment['LOTTI_MANUAL_LOCALE'] ?? 'en';
  if (languageCode != 'en' &&
      languageCode != 'de' &&
      languageCode != 'fr' &&
      languageCode != 'cs' &&
      languageCode != 'ro') {
    throw ArgumentError.value(
      languageCode,
      'LOTTI_MANUAL_LOCALE',
      'Supported manual screenshot locales are en, de, fr, cs, and ro.',
    );
  }
  return Locale(languageCode);
}

Locale get manualScreenshotLocale =>
    manualScreenshotLocaleFromEnvironment(Platform.environment);

/// Select deterministic fixture copy for the active manual locale.
String manualScreenshotText({
  required String en,
  required String de,
  String? fr,
  String? cs,
  String? ro,
}) => switch (manualScreenshotLocale.languageCode) {
  'de' => de,
  'fr' => fr ?? manualScreenshotFrenchText(en) ?? en,
  'cs' => cs ?? manualScreenshotCzechText(en) ?? en,
  'ro' => ro ?? manualScreenshotRomanianText(en) ?? en,
  _ => en,
};
