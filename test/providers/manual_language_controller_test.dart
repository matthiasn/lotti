import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/providers/manual_language_controller.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/package_info.dart';
import '../helpers/service_overrides.dart';
import '../widget_test_utils.dart';

const _appVersion = '1.1.93+4483';
const _manualBase = '${lottiManualRootUrl}1.1.93/';

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
        manualLanguageForSystemLocale(const Locale('fi', 'FI')),
        ManualLanguage.english,
      );
    });
  });

  group('manualVersionFor', () {
    test('a release links the manual of its own marketing version', () {
      expect(manualVersionFor('1.1.93'), '1.1.93');
      // Windows reports the build number inline; the manual is per version.
      expect(manualVersionFor('1.1.93+4483'), '1.1.93');
      expect(manualVersionFor(' 2.0.10 '), '2.0.10');
    });

    test('anything that is not a plain release links development', () {
      // No tag ever publishes these paths, so linking them would only ever
      // reach the 404 page.
      expect(manualVersionFor(''), 'development');
      expect(manualVersionFor('1.1.93-beta.1'), 'development');
      expect(manualVersionFor('1.1'), 'development');
      expect(manualVersionFor('development'), 'development');
    });
  });

  group('runningAppVersion', () {
    test('reports the platform version of the running build', () async {
      mockPackageInfo(version: '1.2.3');
      expect(await runningAppVersion(), '1.2.3');
    });
  });

  group('manualUriFor', () {
    test('opens the manual of the running version', () {
      expect(
        manualUriFor(
          appVersion: '1.1.90',
          systemLocale: const Locale('en'),
        ).toString(),
        '${lottiManualRootUrl}1.1.90/',
      );
      expect(
        manualUriFor(
          appVersion: '',
          systemLocale: const Locale('de'),
          path: 'sync-and-data/first-device',
        ).toString(),
        '${lottiManualRootUrl}development/de/sync-and-data/first-device',
      );
    });

    test('follows the matching system language', () {
      expect(
        manualUriFor(
          appVersion: _appVersion,
          systemLocale: const Locale('de'),
        ).toString(),
        '${_manualBase}de/',
      );
      expect(
        manualUriFor(
          appVersion: _appVersion,
          systemLocale: const Locale('cs'),
        ).toString(),
        '${_manualBase}cs/',
      );
      expect(
        manualUriFor(
          appVersion: _appVersion,
          systemLocale: const Locale('fr'),
        ).toString(),
        '${_manualBase}fr/',
      );
      expect(
        manualUriFor(
          appVersion: _appVersion,
          systemLocale: const Locale('it'),
        ).toString(),
        '${_manualBase}it/',
      );
      expect(
        manualUriFor(
          appVersion: _appVersion,
          systemLocale: const Locale('es'),
        ).toString(),
        '${_manualBase}es/',
      );
      expect(
        manualUriFor(
          appVersion: _appVersion,
          systemLocale: const Locale('ro'),
        ).toString(),
        '${_manualBase}ro/',
      );
      expect(
        manualUriFor(
          appVersion: _appVersion,
          systemLocale: const Locale('nl'),
        ).toString(),
        '${_manualBase}nl/',
      );
      expect(
        manualUriFor(
          appVersion: _appVersion,
          systemLocale: const Locale('pt'),
        ).toString(),
        '${_manualBase}pt/',
      );
      expect(
        manualUriFor(
          appVersion: _appVersion,
          systemLocale: const Locale('da'),
        ).toString(),
        '${_manualBase}da/',
      );
      expect(
        manualUriFor(
          appVersion: _appVersion,
          systemLocale: const Locale('sv'),
        ).toString(),
        '${_manualBase}sv/',
      );
    });

    test('uses English for unsupported system languages', () {
      expect(
        manualUriFor(
          appVersion: _appVersion,
          systemLocale: const Locale('fi'),
        ).toString(),
        _manualBase,
      );
    });

    test('honors an override over the system language', () {
      expect(
        manualUriFor(
          appVersion: _appVersion,
          systemLocale: const Locale('de'),
          override: ManualLanguage.czech,
        ).toString(),
        '${_manualBase}cs/',
      );
    });

    test('a page path lands after the locale segment', () {
      // Deep links stay locale-aware: the localized route serves English
      // content for pages not yet translated, so the path never needs to
      // choose between "right language" and "right page".
      expect(
        manualUriFor(
          appVersion: _appVersion,
          systemLocale: const Locale('de'),
          path: 'sync-and-data/first-device',
        ).toString(),
        '${_manualBase}de/sync-and-data/first-device',
      );
      expect(
        manualUriFor(
          appVersion: _appVersion,
          systemLocale: const Locale('en'),
          path: 'sync-and-data/first-device',
        ).toString(),
        '${_manualBase}sync-and-data/first-device',
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
      container = ProviderContainer(overrides: getItServiceOverrides());
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

    test('a failed settings read settles on Follow system instead of '
        'loading forever', () async {
      when(
        () => mocks.settingsDb.itemByKey(manualLanguageSettingsKey),
      ).thenAnswer((_) async => throw StateError('settings db closed'));

      final settled = await container.read(
        manualLanguageControllerProvider.future,
      );

      expect(settled, isNull);
      expect(
        container.read(manualLanguageControllerProvider),
        isA<AsyncData<ManualLanguage?>>(),
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
