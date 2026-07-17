import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'manual_screenshot_locale.dart';

void main() {
  group('manual screenshot locale', () {
    test('defaults to English and accepts German', () {
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
    });

    test('rejects locales without a complete manual media catalog', () {
      expect(
        () => manualScreenshotLocaleFromEnvironment(
          const {'LOTTI_MANUAL_LOCALE': 'fr'},
        ),
        throwsArgumentError,
      );
    });
  });
}
