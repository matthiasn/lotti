// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:easy_debounce/easy_debounce.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/features/settings/constants/theming_settings_keys.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/theming/state/theming_controller.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

/// Elapses past the controller's initial `_loadSelectedSchemes` load and
/// settles microtasks — the shared init-wait for every fakeAsync test here.
void waitForInit(FakeAsync async) {
  async
    ..elapse(const Duration(milliseconds: 100))
    ..flushMicrotasks();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemingController', () {
    late MockOutboxService outboxService;
    late MockSettingsDb settingsDb;
    late MockJournalDb journalDb;
    late MockDomainLogger mockDomainLogger;
    late MockUpdateNotifications mockUpdateNotifications;
    late StreamController<bool> tooltipController;
    late StreamController<Set<String>> notificationsController;
    late ProviderContainer container;
    late Map<String, String?> storedThemeSettings;
    late Future<Map<String, String?>> Function(Iterable<String> keys)
    settingsBatchLoader;

    setUpAll(() {
      registerFallbackValue(
        const SyncMessage.themingSelection(
          lightThemeName: '',
          darkThemeName: '',
          themeMode: '',
          updatedAt: 0,
          status: SyncEntryStatus.update,
        ),
      );
      registerFallbackValue(StackTrace.empty);
    });

    setUp(() async {
      outboxService = MockOutboxService();
      mockDomainLogger = MockDomainLogger();

      tooltipController = StreamController<bool>.broadcast();
      notificationsController = StreamController<Set<String>>.broadcast();
      storedThemeSettings = <String, String?>{
        darkSchemeNameKey: 'Grey Law',
        lightSchemeNameKey: 'Grey Law',
        themeModeKey: 'system',
      };
      settingsBatchLoader = (keys) async => <String, String?>{
        for (final key in keys) key: storedThemeSettings[key],
      };

      final mocks = await setUpTestGetIt(
        additionalSetup: () {
          GetIt.I.allowReassignment = true;
          GetIt.I
            ..registerSingleton<OutboxService>(outboxService)
            // The helper registers a real DomainLogger; these tests verify
            // error() calls, so reassign it with a mock.
            ..registerSingleton<DomainLogger>(mockDomainLogger);
        },
      );
      settingsDb = mocks.settingsDb;
      journalDb = mocks.journalDb;
      mockUpdateNotifications = mocks.updateNotifications;

      // Override the helper's defaults with this file's behaviors.
      when(
        () => mockUpdateNotifications.updateStream,
      ).thenAnswer((_) => notificationsController.stream);
      when(
        () => settingsDb.itemsByKeys(any()),
      ).thenAnswer((invocation) async {
        final keys = invocation.positionalArguments.first as Iterable<String>;
        return settingsBatchLoader(keys);
      });
      when(
        () => journalDb.watchConfigFlag(enableTooltipFlag),
      ).thenAnswer((_) => tooltipController.stream);
      when(
        () => outboxService.enqueueMessage(any<SyncMessage>()),
      ).thenAnswer((_) async {});
      when(
        () => mockDomainLogger.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});

      container = ProviderContainer();
    });

    tearDown(() async {
      EasyDebounce.cancelAll();
      await tooltipController.close();
      await notificationsController.close();
      container.dispose();
      await tearDownTestGetIt();
    });

    group('themingControllerProvider', () {
      test('initial state has default Grey Law theme', () {
        final state = container.read(themingControllerProvider);
        expect(state.darkThemeName, equals('Grey Law'));
        expect(state.lightThemeName, equals('Grey Law'));
        expect(state.themeMode, equals(ThemeMode.system));
        expect(state.darkTheme!.brightness, Brightness.dark);
        expect(state.lightTheme!.brightness, Brightness.light);
      });

      test(
        'setLightTheme and setDarkTheme rebuild each slot with the right '
        'brightness',
        () {
          fakeAsync((async) {
            final controller = container.read(
              themingControllerProvider.notifier,
            );
            waitForInit(async);

            controller
              ..setLightTheme('Indigo')
              ..setDarkTheme('Shark');
            async.elapse(const Duration(milliseconds: 400));
            async.flushMicrotasks();

            final state = container.read(themingControllerProvider);
            expect(state.lightThemeName, 'Indigo');
            expect(state.darkThemeName, 'Shark');
            // _buildTheme must route the light slot through
            // FlexThemeData.light and the dark slot through
            // FlexThemeData.dark.
            expect(state.lightTheme!.brightness, Brightness.light);
            expect(state.darkTheme!.brightness, Brightness.dark);
            // The selected schemes actually drive the palettes.
            expect(
              state.lightTheme!.colorScheme.primary,
              isNot(state.darkTheme!.colorScheme.primary),
            );
          });
        },
      );

      test('loads saved theme preferences on init', () {
        fakeAsync((async) {
          storedThemeSettings[lightSchemeNameKey] = 'Indigo';
          storedThemeSettings[darkSchemeNameKey] = 'Shark';
          storedThemeSettings[themeModeKey] = 'dark';

          final states = <ThemingState>[];
          container.listen(
            themingControllerProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          waitForInit(async);

          expect(states.last.lightThemeName, equals('Indigo'));
          expect(states.last.darkThemeName, equals('Shark'));
          expect(states.last.themeMode, equals(ThemeMode.dark));
        });
      });

      test('setLightTheme updates light theme and enqueues sync', () {
        fakeAsync((async) {
          final controller = container.read(themingControllerProvider.notifier);

          waitForInit(async);
          clearInteractions(outboxService);

          controller.setLightTheme('Indigo');

          // Wait for debounce
          async.elapse(const Duration(milliseconds: 400));
          async.flushMicrotasks();

          final state = container.read(themingControllerProvider);
          expect(state.lightThemeName, equals('Indigo'));

          verify(
            () => settingsDb.saveSettingsItem(lightSchemeNameKey, 'Indigo'),
          ).called(1);

          final captured = verify(
            () => outboxService.enqueueMessage(captureAny()),
          ).captured;
          expect(captured.length, 1);

          final message = captured.first as SyncThemingSelection;
          expect(message.lightThemeName, 'Indigo');
          expect(message.status, SyncEntryStatus.update);
        });
      });

      test('setDarkTheme updates dark theme and enqueues sync', () {
        fakeAsync((async) {
          final controller = container.read(themingControllerProvider.notifier);

          waitForInit(async);
          clearInteractions(outboxService);

          controller.setDarkTheme('Shark');

          // Wait for debounce
          async.elapse(const Duration(milliseconds: 400));
          async.flushMicrotasks();

          final state = container.read(themingControllerProvider);
          expect(state.darkThemeName, equals('Shark'));

          verify(
            () => settingsDb.saveSettingsItem(darkSchemeNameKey, 'Shark'),
          ).called(1);

          final captured = verify(
            () => outboxService.enqueueMessage(captureAny()),
          ).captured;
          expect(captured.length, 1);

          final message = captured.first as SyncThemingSelection;
          expect(message.darkThemeName, 'Shark');
        });
      });

      test('onThemeSelectionChanged updates mode and enqueues sync', () {
        fakeAsync((async) {
          final controller = container.read(themingControllerProvider.notifier);

          waitForInit(async);
          clearInteractions(outboxService);

          controller.onThemeSelectionChanged({ThemeMode.dark});

          // Wait for debounce
          async.elapse(const Duration(milliseconds: 400));
          async.flushMicrotasks();

          final state = container.read(themingControllerProvider);
          expect(state.themeMode, equals(ThemeMode.dark));

          verify(
            () => settingsDb.saveSettingsItem(themeModeKey, 'dark'),
          ).called(1);

          final captured = verify(
            () => outboxService.enqueueMessage(captureAny()),
          ).captured;
          expect(captured.length, 1);

          final message = captured.first as SyncThemingSelection;
          expect(message.themeMode, 'dark');
        });
      });

      test('debouncing - rapid changes send only final state', () {
        fakeAsync((async) {
          final controller = container.read(themingControllerProvider.notifier);

          waitForInit(async);
          clearInteractions(outboxService);

          controller
            ..setLightTheme('Indigo')
            ..setDarkTheme('Shark')
            ..onThemeSelectionChanged({ThemeMode.dark});

          // Wait for debounce
          async.elapse(const Duration(milliseconds: 300));
          async.flushMicrotasks();

          // Verify enqueueMessage called exactly once (debounced)
          final captured = verify(
            () => outboxService.enqueueMessage(captureAny()),
          ).captured;
          expect(captured.length, 1);

          // Verify message contains all three changes
          final message = captured.first as SyncThemingSelection;
          expect(message.lightThemeName, 'Indigo');
          expect(message.darkThemeName, 'Shark');
          expect(message.themeMode, 'dark');
        });
      });

      test('reloads themes when sync updates arrive', () {
        fakeAsync((async) {
          var callCount = 0;
          settingsBatchLoader = (keys) async {
            callCount++;
            final lightThemeName = callCount == 1 ? 'Grey Law' : 'Indigo';
            return <String, String?>{
              for (final key in keys)
                key: switch (key) {
                  lightSchemeNameKey => lightThemeName,
                  darkSchemeNameKey => 'Grey Law',
                  themeModeKey => 'system',
                  _ => null,
                },
            };
          };

          final states = <ThemingState>[];
          container.listen(
            themingControllerProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          waitForInit(async);

          clearInteractions(settingsDb);
          clearInteractions(outboxService);

          // Trigger reload via settings notification
          notificationsController.add({settingsNotification});

          async.elapse(const Duration(milliseconds: 200));
          async.flushMicrotasks();

          // Verify theme settings were reloaded
          verify(() => settingsDb.itemsByKeys(any())).called(1);

          // Verify NO sync message was enqueued (synced changes don't re-sync)
          verifyNever(() => outboxService.enqueueMessage(any<SyncMessage>()));
        });
      });

      test('invalid theme name is ignored', () {
        fakeAsync((async) {
          final controller = container.read(themingControllerProvider.notifier);

          waitForInit(async);

          final originalState = container.read(themingControllerProvider);

          controller.setLightTheme('NonExistentTheme');

          final newState = container.read(themingControllerProvider);
          expect(newState.lightThemeName, equals(originalState.lightThemeName));
        });
      });
    });

    group('enableTooltipsProvider', () {
      test('initial state is loading', () {
        final state = container.read(enableTooltipsProvider);
        expect(state, const AsyncValue<bool>.loading());
      });

      test('emits true when flag is enabled', () {
        fakeAsync((async) {
          final states = <AsyncValue<bool>>[];
          container.listen(
            enableTooltipsProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.flushMicrotasks();

          tooltipController.add(true);
          async.flushMicrotasks();

          expect(states.last.hasValue, isTrue);
          expect(states.last.value, isTrue);
        });
      });

      test('emits false when flag is disabled', () {
        fakeAsync((async) {
          final states = <AsyncValue<bool>>[];
          container.listen(
            enableTooltipsProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.flushMicrotasks();

          tooltipController.add(false);
          async.flushMicrotasks();

          expect(states.last.hasValue, isTrue);
          expect(states.last.value, isFalse);
        });
      });

      test('handles stream errors', () async {
        final error = Exception('Database error');
        final completer = Completer<void>();

        container.listen(
          enableTooltipsProvider,
          (_, next) {
            if (next.hasError && !completer.isCompleted) {
              completer.complete();
            }
          },
        );

        tooltipController.addError(error);

        // Error propagation is deterministic (addError -> provider error ->
        // listener completes the completer on a microtask), so await directly
        // rather than racing a real wall-clock timeout (fake-time policy).
        await completer.future;

        final state = container.read(enableTooltipsProvider);
        expect(state.hasError, isTrue);
      });
    });

    group('error handling', () {
      test('handles error in _loadSelectedSchemes and logs it', () {
        fakeAsync((async) {
          settingsBatchLoader = (_) => Future<Map<String, String?>>.error(
            Exception('Database error'),
          );

          final states = <ThemingState>[];
          container.listen(
            themingControllerProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.elapse(const Duration(milliseconds: 200));
          async.flushMicrotasks();

          // Controller should still be in valid state (with default values)
          final state = container.read(themingControllerProvider);
          expect(state, isNotNull);
          expect(state.darkThemeName, equals('Grey Law'));

          // Verify error was captured
          verify(
            () => mockDomainLogger.error(
              LogDomain.theming,
              any<Object>(),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: 'init',
            ),
          ).called(1);
        });
      });

      test('gracefully handles OutboxService not registered', () {
        fakeAsync((async) {
          GetIt.I.unregister<OutboxService>();

          final controller = container.read(themingControllerProvider.notifier);

          waitForInit(async);

          controller.setLightTheme('Indigo');

          async.elapse(const Duration(milliseconds: 400));
          async.flushMicrotasks();

          // The missing OutboxService only skips sync enqueueing — the
          // local state change and persistence still happen.
          final state = container.read(themingControllerProvider);
          expect(state.lightThemeName, 'Indigo');
          verify(
            () => settingsDb.saveSettingsItem(lightSchemeNameKey, 'Indigo'),
          ).called(1);
        });
      });

      test('ignores notifications without settingsNotification key', () {
        fakeAsync((async) {
          final states = <ThemingState>[];
          container.listen(
            themingControllerProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          waitForInit(async);

          clearInteractions(settingsDb);

          // Emit unrelated notification
          notificationsController.add({'unrelated_notification'});

          waitForInit(async);

          // Verify settings were NOT reloaded
          verifyNever(() => settingsDb.itemsByKeys(any()));
        });
      });

      test('handles error during theme reload from sync and logs it', () {
        fakeAsync((async) {
          var callCount = 0;
          settingsBatchLoader = (keys) {
            callCount++;
            if (callCount > 1) {
              return Future<Map<String, String?>>.error(
                Exception('Reload error'),
              );
            }
            return Future<Map<String, String?>>.value(<String, String?>{
              for (final key in keys)
                key: switch (key) {
                  darkSchemeNameKey => 'Grey Law',
                  lightSchemeNameKey => 'Grey Law',
                  themeModeKey => 'system',
                  _ => null,
                },
            });
          };

          final states = <ThemingState>[];
          container.listen(
            themingControllerProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          waitForInit(async);

          // Trigger reload via settings notification
          notificationsController.add({settingsNotification});

          async.elapse(const Duration(milliseconds: 200));
          async.flushMicrotasks();

          // Verify error was logged
          verify(
            () => mockDomainLogger.error(
              LogDomain.theming,
              any<Object>(),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: 'theme_prefs_reload',
            ),
          ).called(1);

          // Controller should still be in valid state
          final state = container.read(themingControllerProvider);
          expect(state, isNotNull);
        });
      });

      test('handles error in enqueueMessage and logs it', () {
        fakeAsync((async) {
          when(
            () => outboxService.enqueueMessage(any<SyncMessage>()),
          ).thenThrow(Exception('Enqueue error'));

          final controller = container.read(themingControllerProvider.notifier);

          waitForInit(async);

          controller.setLightTheme('Indigo');

          // Wait for debounce
          async.elapse(const Duration(milliseconds: 400));
          async.flushMicrotasks();

          // Verify error was logged
          verify(
            () => mockDomainLogger.error(
              LogDomain.theming,
              any<Object>(),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: 'enqueue',
            ),
          ).called(1);
        });
      });

      test('does not enqueue sync message when applying synced changes', () {
        fakeAsync((async) {
          final states = <ThemingState>[];
          container.listen(
            themingControllerProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          waitForInit(async);

          clearInteractions(outboxService);

          // Trigger reload via settings notification (simulates sync update)
          notificationsController.add({settingsNotification});

          async.elapse(const Duration(milliseconds: 400));
          async.flushMicrotasks();

          // Verify NO sync message was enqueued during sync application
          verifyNever(() => outboxService.enqueueMessage(any<SyncMessage>()));
        });
      });

      test('handles null theme mode string gracefully', () {
        fakeAsync((async) {
          storedThemeSettings[themeModeKey] = null;

          final states = <ThemingState>[];
          container.listen(
            themingControllerProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          waitForInit(async);

          // Should default to system theme mode
          expect(states.last.themeMode, equals(ThemeMode.system));
        });
      });

      test('handles invalid theme mode string gracefully', () {
        fakeAsync((async) {
          storedThemeSettings[themeModeKey] = 'invalid_mode';

          final states = <ThemingState>[];
          container.listen(
            themingControllerProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          waitForInit(async);

          // Should default to system theme mode
          expect(states.last.themeMode, equals(ThemeMode.system));
        });
      });

      test('handles null theme names gracefully', () {
        fakeAsync((async) {
          storedThemeSettings[lightSchemeNameKey] = null;
          storedThemeSettings[darkSchemeNameKey] = null;

          final states = <ThemingState>[];
          container.listen(
            themingControllerProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          waitForInit(async);

          // Should default to Grey Law
          expect(states.last.lightThemeName, equals('Grey Law'));
          expect(states.last.darkThemeName, equals('Grey Law'));
        });
      });

      test('invalid dark theme name is ignored', () {
        fakeAsync((async) {
          final controller = container.read(themingControllerProvider.notifier);

          waitForInit(async);

          final originalState = container.read(themingControllerProvider);

          controller.setDarkTheme('NonExistentTheme');

          final newState = container.read(themingControllerProvider);
          expect(newState.darkThemeName, equals(originalState.darkThemeName));
        });
      });

      test('unrelated notification does not trigger theme reload', () {
        fakeAsync((async) {
          final states = <ThemingState>[];
          container.listen(
            themingControllerProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          waitForInit(async);

          // Initial load completed
          verify(() => settingsDb.itemsByKeys(any())).called(1);

          // Emit unrelated notification (should be ignored)
          notificationsController.add({'some_other_notification'});

          async.elapse(const Duration(milliseconds: 200));
          async.flushMicrotasks();

          // No additional load triggered
          verifyNever(() => settingsDb.itemsByKeys(any()));
        });
      });
    });

    group('ThemingState', () {
      test('copyWith preserves all values when no arguments provided', () {
        final original = ThemingState(
          darkTheme: ThemeData.dark(),
          lightTheme: ThemeData.light(),
          darkThemeName: 'Shark',
          lightThemeName: 'Indigo',
          themeMode: ThemeMode.dark,
        );

        final copy = original.copyWith();

        expect(copy.darkThemeName, equals('Shark'));
        expect(copy.lightThemeName, equals('Indigo'));
        expect(copy.themeMode, equals(ThemeMode.dark));
      });

      test('copyWith can update individual theme fields', () {
        final original = ThemingState(
          darkTheme: ThemeData.dark(),
          lightTheme: ThemeData.light(),
          darkThemeName: 'Grey Law',
          lightThemeName: 'Grey Law',
        );

        final newDarkTheme = ThemeData.dark();
        final newLightTheme = ThemeData.light();

        final copy = original.copyWith(
          darkTheme: newDarkTheme,
          lightTheme: newLightTheme,
        );

        expect(copy.darkTheme, equals(newDarkTheme));
        expect(copy.lightTheme, equals(newLightTheme));
        expect(copy.darkThemeName, equals('Grey Law'));
        expect(copy.lightThemeName, equals('Grey Law'));
      });
    });
  });
}
