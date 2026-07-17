import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'manual_screenshot_czech_text.dart';
import 'manual_screenshot_french_text.dart';
import 'manual_screenshot_locale.dart';
import 'manual_screenshot_romanian_text.dart';
import 'manual_screenshot_spanish_text.dart';

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
      expect(
        manualScreenshotLocaleFromEnvironment(
          const {'LOTTI_MANUAL_LOCALE': 'fr'},
        ),
        const Locale('fr'),
      );
      expect(
        manualScreenshotLocaleFromEnvironment(
          const {'LOTTI_MANUAL_LOCALE': 'ro'},
        ),
        const Locale('ro'),
      );
      expect(
        manualScreenshotLocaleFromEnvironment(
          const {'LOTTI_MANUAL_LOCALE': 'es'},
        ),
        const Locale('es'),
      );
    });

    test('rejects unsupported screenshot locales', () {
      expect(
        () => manualScreenshotLocaleFromEnvironment(
          const {'LOTTI_MANUAL_LOCALE': 'it'},
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

    test('French fixture catalog localizes representative demo copy', () {
      expect(
        manualScreenshotFrenchText('Inspect orbital penguin habitat'),
        'Inspecter l’habitat orbital des manchots',
      );
      expect(manualScreenshotFrenchText('Unknown fixture'), isNull);
    });

    test('Romanian fixture catalog localizes representative demo copy', () {
      expect(
        manualScreenshotRomanianText('Inspect orbital penguin habitat'),
        'Inspectați habitatul orbital al pinguinilor',
      );
      expect(manualScreenshotRomanianText('Unknown fixture'), isNull);
    });

    test('Spanish fixture catalog localizes representative demo copy', () {
      expect(
        manualScreenshotSpanishText('Inspect orbital penguin habitat'),
        'Inspeccionar hábitat orbital de pingüinos',
      );
      expect(manualScreenshotSpanishText('Unknown fixture'), isNull);
    });

    test(
      'French fixture catalog localizes multiline agent reports',
      () {
        const report = '''
## Latest assessment

- Pressure seals A–F stayed stable across the night shift.
- 840 sardines are loaded; feeder calibration still blocks sign-off.
- Mission Control clearance is due before the 06:30 roll call.

## Recommended next step

Run the feeder test, attach the telemetry image, then request launch approval.''';

        expect(
          manualScreenshotFrenchText(report),
          startsWith('## Dernière évaluation'),
        );
      },
    );
  });
}
