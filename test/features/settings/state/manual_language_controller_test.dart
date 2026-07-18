import 'dart:async';

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
      expect(ManualLanguage.fromStoredValue('fr'), ManualLanguage.french);
      expect(ManualLanguage.fromStoredValue('it'), ManualLanguage.italian);
      expect(ManualLanguage.fromStoredValue('es'), ManualLanguage.spanish);
      expect(ManualLanguage.fromStoredValue('cs'), ManualLanguage.czech);
      expect(ManualLanguage.fromStoredValue('nl'), ManualLanguage.dutch);
      expect(ManualLanguage.fromStoredValue('ro'), ManualLanguage.romanian);
      expect(
        ManualLanguage.fromStoredValue('pt'),
        ManualLanguage.portuguese,
      );
      expect(ManualLanguage.fromStoredValue('da'), ManualLanguage.danish);
      expect(ManualLanguage.fromStoredValue('sv'), ManualLanguage.swedish);
      expect(ManualLanguage.fromStoredValue(null), isNull);
    });

    test('exposes the locale used by the app', () {
      expect(ManualLanguage.german.locale, const Locale('de'));
      expect(ManualLanguage.portuguese.locale, const Locale('pt'));
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
      expect(
        manualLanguageForSystemLocale(const Locale('fr', 'FR')),
        ManualLanguage.french,
      );
      expect(
        manualLanguageForSystemLocale(const Locale('it', 'IT')),
        ManualLanguage.italian,
      );
      expect(
        manualLanguageForSystemLocale(const Locale('es', 'ES')),
        ManualLanguage.spanish,
      );
      expect(
        manualLanguageForSystemLocale(const Locale('ro', 'RO')),
        ManualLanguage.romanian,
      );
      expect(
        manualLanguageForSystemLocale(const Locale('nl', 'NL')),
        ManualLanguage.dutch,
      );
      expect(
        manualLanguageForSystemLocale(const Locale('pt', 'BR')),
        ManualLanguage.portuguese,
      );
      expect(
        manualLanguageForSystemLocale(const Locale('da', 'DK')),
        ManualLanguage.danish,
      );
      expect(
        manualLanguageForSystemLocale(const Locale('sv', 'SE')),
        ManualLanguage.swedish,
      );
    });

    test('falls back to English for an unsupported system language', () {
      expect(
        manualLanguageForSystemLocale(const Locale('sv', 'SE')),
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
      expect(
        manualUriFor(systemLocale: const Locale('fr')).toString(),
        '${lottiManualBaseUrl}fr/',
      );
      expect(
        manualUriFor(systemLocale: const Locale('it')).toString(),
        '${lottiManualBaseUrl}it/',
      );
      expect(
        manualUriFor(systemLocale: const Locale('es')).toString(),
        '${lottiManualBaseUrl}es/',
      );
      expect(
        manualUriFor(systemLocale: const Locale('ro')).toString(),
        '${lottiManualBaseUrl}ro/',
      );
      expect(
        manualUriFor(systemLocale: const Locale('nl')).toString(),
        '${lottiManualBaseUrl}nl/',
      );
      expect(
        manualUriFor(systemLocale: const Locale('pt')).toString(),
        '${lottiManualBaseUrl}pt/',
      );
      expect(
        manualUriFor(systemLocale: const Locale('da')).toString(),
        '${lottiManualBaseUrl}da/',
      );
      expect(
        manualUriFor(systemLocale: const Locale('sv')).toString(),
        '${lottiManualBaseUrl}sv/',
      );
    });

    test('uses English for unsupported system languages', () {
      expect(
        manualUriFor(systemLocale: const Locale('sv')).toString(),
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

      expect(
        container.read(manualLanguageControllerProvider),
        isA<AsyncLoading<ManualLanguage?>>(),
      );
      await Future<void>.microtask(() {});

      expect(
        container.read(manualLanguageControllerProvider).value,
        ManualLanguage.german,
      );
    });

    test(
      'keeps loading separate from the Follow system preference',
      () async {
        final storedLanguage = Completer<String?>();
        when(
          () => mocks.settingsDb.itemByKey(manualLanguageSettingsKey),
        ).thenAnswer((_) => storedLanguage.future);

        expect(
          container.read(manualLanguageControllerProvider),
          isA<AsyncLoading<ManualLanguage?>>(),
        );
        await Future<void>.microtask(() {});

        expect(
          container.read(manualLanguageControllerProvider),
          isA<AsyncLoading<ManualLanguage?>>(),
        );

        storedLanguage.complete('de');
        await Future<void>.microtask(() {});

        expect(
          container.read(manualLanguageControllerProvider).value,
          ManualLanguage.german,
        );
      },
    );

    test('persists an override and clears it back to Follow system', () async {
      final controller = container.read(
        manualLanguageControllerProvider.notifier,
      );

      await controller.setOverride(ManualLanguage.portuguese);

      expect(
        container.read(manualLanguageControllerProvider).value,
        ManualLanguage.portuguese,
      );
      verify(
        () =>
            mocks.settingsDb.saveSettingsItem(manualLanguageSettingsKey, 'pt'),
      ).called(1);

      await controller.setOverride(null);

      final preference = container.read(manualLanguageControllerProvider);
      expect(preference.hasValue, isTrue);
      expect(preference.value, isNull);
      verify(
        () => mocks.settingsDb.removeSettingsItem(manualLanguageSettingsKey),
      ).called(1);
    });
  });
}
