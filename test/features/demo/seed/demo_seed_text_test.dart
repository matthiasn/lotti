import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
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

void main() {
  const heroEn = 'Inspect orbital penguin habitat';
  const heroDe = 'Pinguin-Habitat im Orbit inspizieren';

  group('demoSeedTextForLocale', () {
    test('English returns the authored string, German the authored pair', () {
      expect(demoSeedTextForLocale(const Locale('en'))(heroEn, heroDe), heroEn);
      expect(demoSeedTextForLocale(const Locale('de'))(heroEn, heroDe), heroDe);
    });

    test('catalog locales resolve sampled keys through their catalogs', () {
      final catalogs = <String, String? Function(String)>{
        'fr': manualScreenshotFrenchText,
        'it': manualScreenshotItalianText,
        'es': manualScreenshotSpanishText,
        'cs': manualScreenshotCzechText,
        'nl': manualScreenshotDutchText,
        'ro': manualScreenshotRomanianText,
        'pt': manualScreenshotPortugueseText,
        'da': manualScreenshotDanishText,
        'sv': manualScreenshotSwedishText,
      };
      const sampledKeys = [
        heroEn,
        'Penguin Operations',
        'Your first mission',
        'Learn the ropes',
        'Record a voice note',
      ];
      for (final entry in catalogs.entries) {
        final t = demoSeedTextForLocale(Locale(entry.key));
        for (final key in sampledKeys) {
          final catalogValue = entry.value(key);
          expect(
            catalogValue,
            isNotNull,
            reason: '${entry.key} catalog is missing "$key"',
          );
          expect(
            t(key, 'unused-de'),
            catalogValue,
            reason: '${entry.key} must resolve "$key" through its catalog',
          );
        }
        // Catalog miss falls back to the English source string.
        expect(
          t('An unknown fixture string', 'unused-de'),
          'An unknown fixture string',
        );
      }
    });

    test('unsupported language codes fall back to English', () {
      expect(demoSeedTextForLocale(const Locale('fi'))(heroEn, heroDe), heroEn);
    });
  });

  group('demoSeedLocaleFromEnvironment / demoSeedTextFromEnvironment', () {
    test('defaults to English when the variable is unset', () {
      expect(demoSeedLocaleFromEnvironment(const {}), const Locale('en'));
      expect(demoSeedTextFromEnvironment(const {})(heroEn, heroDe), heroEn);
    });

    test('honors every supported LOTTI_MANUAL_LOCALE code', () {
      for (final code in demoSeedLanguageCodes) {
        expect(
          demoSeedLocaleFromEnvironment({'LOTTI_MANUAL_LOCALE': code}),
          Locale(code),
        );
      }
      expect(
        demoSeedTextFromEnvironment(
          const {'LOTTI_MANUAL_LOCALE': 'de'},
        )(heroEn, heroDe),
        heroDe,
      );
    });

    test('rejects unsupported locales', () {
      expect(
        () => demoSeedLocaleFromEnvironment(const {
          'LOTTI_MANUAL_LOCALE': 'fi',
        }),
        throwsArgumentError,
      );
    });
  });
}
