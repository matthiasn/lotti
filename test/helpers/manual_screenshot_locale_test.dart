import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'manual_screenshot_czech_text.dart';
import 'manual_screenshot_locale.dart';

void main() {
  group('manual screenshot locale', () {
    test('defaults to English and accepts translated manual locales', () {
      expect(
        manualScreenshotLocaleFromEnvironment(const {}),
        const Locale('en'),
      );
      expect(
        manualScreenshotLocaleFromEnvironment(
          const {'LOTTI_MANUAL_LOCALE': 'de'},
        ),
        const Locale('de'),
      );
      expect(
        manualScreenshotLocaleFromEnvironment(
          const {'LOTTI_MANUAL_LOCALE': 'cs'},
        ),
        const Locale('cs'),
      );
    });

    test('rejects locales without a complete manual media catalog', () {
      expect(
        () => manualScreenshotLocaleFromEnvironment(
          const {'LOTTI_MANUAL_LOCALE': 'fr'},
        ),
        throwsArgumentError,
      );
    });

    test('Czech fixture catalog localizes representative demo copy', () {
      expect(
        manualScreenshotCzechText('Inspect orbital penguin habitat'),
        'Zkontrolovat orbitální obydlí tučňáků',
      );
      expect(manualScreenshotCzechText('Unknown fixture'), isNull);
    });
  });
}
