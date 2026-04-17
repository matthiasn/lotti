import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/settings/constants/theming_settings_keys.dart';
import 'package:lotti/features/theming/state/theming_controller.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemingController', () {
    late MockSettingsDb settingsDb;
    late MockJournalDb journalDb;
    late MockLoggingService loggingService;
    late StreamController<bool> tooltipController;
    late ProviderContainer container;
    late Map<String, String?> storedSettings;

    setUpAll(() {
      registerFallbackValue(StackTrace.empty);
    });

    setUp(() {
      GetIt.I.allowReassignment = true;

      settingsDb = MockSettingsDb();
      journalDb = MockJournalDb();
      loggingService = MockLoggingService();
      tooltipController = StreamController<bool>.broadcast();
      storedSettings = <String, String?>{};

      when(() => settingsDb.itemByKey(any())).thenAnswer(
        (invocation) async =>
            storedSettings[invocation.positionalArguments.first as String],
      );
      when(
        () => settingsDb.saveSettingsItem(any<String>(), any<String>()),
      ).thenAnswer((invocation) async {
        storedSettings[invocation.positionalArguments[0] as String] =
            invocation.positionalArguments[1] as String;
        return 1;
      });
      when(
        () => journalDb.watchConfigFlag(enableTooltipFlag),
      ).thenAnswer((_) => tooltipController.stream);
      when(
        () => loggingService.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).thenAnswer((_) async {});

      GetIt.I
        ..registerSingleton<SettingsDb>(settingsDb)
        ..registerSingleton<JournalDb>(journalDb)
        ..registerSingleton<LoggingService>(loggingService);

      container = ProviderContainer();
    });

    tearDown(() async {
      await tooltipController.close();
      container.dispose();
      await GetIt.I.reset();
    });

    group('initial state', () {
      test('exposes light/dark themes built from design system tokens', () {
        final state = container.read(themingControllerProvider);
        expect(state.lightTheme, same(lottiLightTheme));
        expect(state.darkTheme, same(lottiDarkTheme));
        expect(state.lightTheme.brightness, Brightness.light);
        expect(state.darkTheme.brightness, Brightness.dark);
      });

      test('defaults themeMode to system before settings load', () {
        final state = container.read(themingControllerProvider);
        expect(state.themeMode, ThemeMode.system);
      });
    });

    group('themeMode loading', () {
      test('loads persisted ThemeMode.dark on init', () {
        fakeAsync((async) {
          storedSettings[themeModeKey] = 'dark';

          container.read(themingControllerProvider);
          async.flushMicrotasks();

          expect(
            container.read(themingControllerProvider).themeMode,
            ThemeMode.dark,
          );
        });
      });

      test('loads persisted ThemeMode.light on init', () {
        fakeAsync((async) {
          storedSettings[themeModeKey] = 'light';

          container.read(themingControllerProvider);
          async.flushMicrotasks();

          expect(
            container.read(themingControllerProvider).themeMode,
            ThemeMode.light,
          );
        });
      });

      test('falls back to system when stored value is null', () {
        fakeAsync((async) {
          storedSettings[themeModeKey] = null;

          container.read(themingControllerProvider);
          async.flushMicrotasks();

          expect(
            container.read(themingControllerProvider).themeMode,
            ThemeMode.system,
          );
        });
      });

      test('falls back to system when stored value is unrecognized', () {
        fakeAsync((async) {
          storedSettings[themeModeKey] = 'not_a_real_mode';

          container.read(themingControllerProvider);
          async.flushMicrotasks();

          expect(
            container.read(themingControllerProvider).themeMode,
            ThemeMode.system,
          );
        });
      });

      test('logs and recovers when settings DB throws on load', () {
        fakeAsync((async) {
          when(() => settingsDb.itemByKey(any())).thenAnswer(
            (_) => Future<String?>.error(Exception('boom')),
          );

          container.read(themingControllerProvider);
          async.flushMicrotasks();

          verify(
            () => loggingService.captureException(
              any<Object>(),
              domain: 'THEMING_CONTROLLER',
              subDomain: 'loadThemeMode',
              stackTrace: any<StackTrace>(named: 'stackTrace'),
            ),
          ).called(1);
          expect(
            container.read(themingControllerProvider).themeMode,
            ThemeMode.system,
          );
        });
      });
    });

    group('onThemeSelectionChanged', () {
      test('updates themeMode and persists the new value', () {
        fakeAsync((async) {
          final controller = container.read(themingControllerProvider.notifier);
          async.flushMicrotasks();

          controller.onThemeSelectionChanged({ThemeMode.dark});

          expect(
            container.read(themingControllerProvider).themeMode,
            ThemeMode.dark,
          );
          verify(
            () => settingsDb.saveSettingsItem(themeModeKey, 'dark'),
          ).called(1);
        });
      });

      test('persists each of light, dark, and system selections', () {
        fakeAsync((async) {
          final controller = container.read(themingControllerProvider.notifier);
          async.flushMicrotasks();

          for (final mode in ThemeMode.values) {
            controller.onThemeSelectionChanged({mode});
            expect(
              container.read(themingControllerProvider).themeMode,
              mode,
            );
          }

          verify(
            () => settingsDb.saveSettingsItem(themeModeKey, 'system'),
          ).called(1);
          verify(
            () => settingsDb.saveSettingsItem(themeModeKey, 'light'),
          ).called(1);
          verify(
            () => settingsDb.saveSettingsItem(themeModeKey, 'dark'),
          ).called(1);
        });
      });

      test('ignores empty selection set', () {
        fakeAsync((async) {
          final controller = container.read(themingControllerProvider.notifier);
          async.flushMicrotasks();

          final before = container.read(themingControllerProvider).themeMode;
          controller.onThemeSelectionChanged({});

          expect(
            container.read(themingControllerProvider).themeMode,
            before,
          );
          verifyNever(
            () => settingsDb.saveSettingsItem(themeModeKey, any<String>()),
          );
        });
      });
    });

    group('cached top-level themes', () {
      test('lottiLightTheme is light brightness Material 3', () {
        expect(lottiLightTheme.brightness, Brightness.light);
        expect(lottiLightTheme.useMaterial3, isTrue);
      });

      test('lottiDarkTheme is dark brightness Material 3', () {
        expect(lottiDarkTheme.brightness, Brightness.dark);
        expect(lottiDarkTheme.useMaterial3, isTrue);
      });
    });

    group('ThemingState.copyWith', () {
      test('returns identical state when no field is provided', () {
        final original = ThemingState(
          lightTheme: ThemeData(brightness: Brightness.light),
          darkTheme: ThemeData(brightness: Brightness.dark),
          themeMode: ThemeMode.dark,
        );

        final copy = original.copyWith();

        expect(copy.themeMode, ThemeMode.dark);
        expect(copy.lightTheme, same(original.lightTheme));
        expect(copy.darkTheme, same(original.darkTheme));
      });

      test('updates only themeMode and preserves cached themes', () {
        final original = ThemingState(
          lightTheme: ThemeData(brightness: Brightness.light),
          darkTheme: ThemeData(brightness: Brightness.dark),
        );

        final copy = original.copyWith(themeMode: ThemeMode.light);

        expect(copy.themeMode, ThemeMode.light);
        expect(copy.lightTheme, same(original.lightTheme));
        expect(copy.darkTheme, same(original.darkTheme));
      });
    });

    group('enableTooltipsProvider', () {
      test('initial value is loading', () {
        final state = container.read(enableTooltipsProvider);
        expect(state, const AsyncValue<bool>.loading());
      });

      test('emits values from the underlying config flag stream', () {
        fakeAsync((async) {
          final emitted = <AsyncValue<bool>>[];
          container.listen(
            enableTooltipsProvider,
            (_, next) => emitted.add(next),
            fireImmediately: true,
          );

          tooltipController.add(true);
          async.flushMicrotasks();
          tooltipController.add(false);
          async.flushMicrotasks();

          expect(emitted.last.value, isFalse);
        });
      });

      test('surfaces stream errors as AsyncError', () async {
        final errorReceived = Completer<void>();
        container.listen(enableTooltipsProvider, (_, next) {
          if (next.hasError && !errorReceived.isCompleted) {
            errorReceived.complete();
          }
        });

        tooltipController.addError(Exception('flag stream blew up'));

        await errorReceived.future.timeout(
          const Duration(milliseconds: 100),
        );

        expect(container.read(enableTooltipsProvider).hasError, isTrue);
      });
    });
  });
}
