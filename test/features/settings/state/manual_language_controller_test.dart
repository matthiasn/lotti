import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings/state/manual_language_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('ManualLanguage', () {
    test('decodes only published manual languages', () {
      expect(ManualLanguage.fromStoredValue('en'), ManualLanguage.english);
      expect(ManualLanguage.fromStoredValue('de'), ManualLanguage.german);
      expect(ManualLanguage.fromStoredValue('cs'), ManualLanguage.czech);
      expect(ManualLanguage.fromStoredValue('fr'), isNull);
      expect(ManualLanguage.fromStoredValue(null), isNull);
    });
  });

  group('manualLanguageForSystemLocale', () {
    test('matches published locales by language code', () {
      expect(
        manualLanguageForSystemLocale(const Locale('de', 'AT')),
        ManualLanguage.german,
      );
      expect(
        manualLanguageForSystemLocale(const Locale('cs', 'CZ')),
        ManualLanguage.czech,
      );
    });

    test('falls back to English for an unsupported system language', () {
      expect(
        manualLanguageForSystemLocale(const Locale('fr', 'FR')),
        ManualLanguage.english,
      );
    });
  });

  group('manualUriFor', () {
    test('follows the matching system language', () {
      expect(
        manualUriFor(systemLocale: const Locale('de')).toString(),
        '${lottiManualBaseUrl}de/',
      );
      expect(
        manualUriFor(systemLocale: const Locale('cs')).toString(),
        '${lottiManualBaseUrl}cs/',
      );
    });

    test('uses English for unsupported system languages', () {
      expect(
        manualUriFor(systemLocale: const Locale('fr')).toString(),
        lottiManualBaseUrl,
      );
    });

    test('honors an override over the system language', () {
      expect(
        manualUriFor(
          systemLocale: const Locale('de'),
          override: ManualLanguage.czech,
        ).toString(),
        '${lottiManualBaseUrl}cs/',
      );
    });
  });

  group('ManualLanguageController', () {
    late TestGetItMocks mocks;
    late ProviderContainer container;

    setUp(() async {
      mocks = await setUpTestGetIt();
      when(
        () => mocks.settingsDb.removeSettingsItem(any()),
      ).thenAnswer((_) async {});
      container = ProviderContainer();
    });

    tearDown(() async {
      container.dispose();
      await tearDownTestGetIt();
    });

    test('hydrates a valid persisted override', () async {
      when(
        () => mocks.settingsDb.itemByKey(manualLanguageSettingsKey),
      ).thenAnswer((_) async => 'de');

      expect(container.read(manualLanguageControllerProvider), isNull);
      await Future<void>.microtask(() {});

      expect(
        container.read(manualLanguageControllerProvider),
        ManualLanguage.german,
      );
    });

    test('persists an override and clears it back to Follow system', () async {
      final controller = container.read(
        manualLanguageControllerProvider.notifier,
      );

      await controller.setOverride(ManualLanguage.czech);

      expect(
        container.read(manualLanguageControllerProvider),
        ManualLanguage.czech,
      );
      verify(
        () => mocks.settingsDb.saveSettingsItem(
          manualLanguageSettingsKey,
          'cs',
        ),
      ).called(1);

      await controller.setOverride(null);

      expect(container.read(manualLanguageControllerProvider), isNull);
      verify(
        () => mocks.settingsDb.removeSettingsItem(manualLanguageSettingsKey),
      ).called(1);
    });
  });
}
