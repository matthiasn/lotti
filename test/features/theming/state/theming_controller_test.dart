// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:easy_debounce/easy_debounce.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/settings/constants/theming_settings_keys.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/theming/model/theme_definitions.dart';
import 'package:lotti/features/theming/state/theming_controller.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemingController', () {
    late MockOutboxService outboxService;
    late MockSettingsDb settingsDb;
    late MockJournalDb journalDb;
    late MockLoggingService loggingService;
    late MockUpdateNotifications mockUpdateNotifications;
    late StreamController<bool> tooltipController;
    late StreamController<Set<String>> notificationsController;
    late ProviderContainer container;

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
      GetIt.I.allowReassignment = true;

      outboxService = MockOutboxService();
      settingsDb = MockSettingsDb();
      journalDb = MockJournalDb();
      loggingService = MockLoggingService();
      mockUpdateNotifications = MockUpdateNotifications();

      tooltipController = StreamController<bool>.broadcast();
      notificationsController = StreamController<Set<String>>.broadcast();

      when(() => mockUpdateNotifications.updateStream)
          .thenAnswer((_) => notificationsController.stream);

      // Setup default mock behaviors
      when(() => settingsDb.itemByKey(darkSchemeNameKey))
          .thenAnswer((_) async => 'Grey Law');
      when(() => settingsDb.itemByKey(lightSchemeNameKey))
          .thenAnswer((_) async => 'Grey Law');
      when(() => settingsDb.itemByKey(themeModeKey))
          .thenAnswer((_) async => 'system');
      when(() => settingsDb.saveSettingsItem(any<String>(), any<String>()))
          .thenAnswer((_) async => 1);
      when(() => journalDb.watchConfigFlag(enableTooltipFlag))
          .thenAnswer((_) => tooltipController.stream);
      when(() => outboxService.enqueueMessage(any<SyncMessage>()))
          .thenAnswer((_) async {});
      when(
        () => loggingService.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).thenAnswer((_) {});

      GetIt.I
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<OutboxService>(outboxService)
        ..registerSingleton<SettingsDb>(settingsDb)
        ..registerSingleton<JournalDb>(journalDb)
        ..registerSingleton<LoggingService>(loggingService);

      container = ProviderContainer();
    });

    tearDown(() async {
      EasyDebounce.cancelAll();
      await tooltipController.close();
      await notificationsController.close();
      container.dispose();
      await GetIt.I.reset();
    });

    group('themingControllerProvider', () {
      test('initial state has default Grey Law theme', () {
        final state = container.read(themingControllerProvider);
        expect(state.darkThemeName, equals('Grey Law'));
        expect(state.lightThemeName, equals('Grey Law'));
        expect(state.themeMode, equals(ThemeMode.system));
        expect(state.darkTheme, isNotNull);
        expect(state.lightTheme, isNotNull);
      });

      test('loads saved theme preferences on init', () {
        fakeAsync((async) {
          when(() => settingsDb.itemByKey(lightSchemeNameKey))
              .thenAnswer((_) async => 'Indigo');
          when(() => settingsDb.itemByKey(darkSchemeNameKey))
              .thenAnswer((_) async => 'Shark');
          when(() => settingsDb.itemByKey(themeModeKey))
              .thenAnswer((_) async => 'dark');

          final states = <ThemingState>[];
          container.listen(
            themingControllerProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          expect(states.last.lightThemeName, equals('Indigo'));
          expect(states.last.darkThemeName, equals('Shark'));
          expect(states.last.themeMode, equals(ThemeMode.dark));
        });
      });

      test('setLightTheme updates light theme and enqueues sync', () {
        fakeAsync((async) {
          final controller = container.read(themingControllerProvider.notifier);

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();
          clearInteractions(outboxService);

          controller.setLightTheme('Indigo');

          // Wait for debounce
          async.elapse(const Duration(milliseconds: 400));
          async.flushMicrotasks();

          final state = container.read(themingControllerProvider);
          expect(state.lightThemeName, equals('Indigo'));

          verify(() =>
                  settingsDb.saveSettingsItem(lightSchemeNameKey, 'Indigo'))
              .called(1);

          final captured =
              verify(() => outboxService.enqueueMessage(captureAny())).captured;
          expect(captured.length, 1);

          final message = captured.first as SyncThemingSelection;
          expect(message.lightThemeName, 'Indigo');
          expect(message.status, SyncEntryStatus.update);
        });
      });

      test('setDarkTheme updates dark theme and enqueues sync', () {
        fakeAsync((async) {
          final controller = container.read(themingControllerProvider.notifier);

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();
          clearInteractions(outboxService);

          controller.setDarkTheme('Shark');

          // Wait for debounce
          async.elapse(const Duration(milliseconds: 400));
          async.flushMicrotasks();

          final state = container.read(themingControllerProvider);
          expect(state.darkThemeName, equals('Shark'));

          verify(() => settingsDb.saveSettingsItem(darkSchemeNameKey, 'Shark'))
              .called(1);

          final captured =
              verify(() => outboxService.enqueueMessage(captureAny())).captured;
          expect(captured.length, 1);

          final message = captured.first as SyncThemingSelection;
          expect(message.darkThemeName, 'Shark');
        });
      });

      test('onThemeSelectionChanged updates mode and enqueues sync', () {
        fakeAsync((async) {
          final controller = container.read(themingControllerProvider.notifier);

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();
          clearInteractions(outboxService);

          controller.onThemeSelectionChanged({ThemeMode.dark});

          // Wait for debounce
          async.elapse(const Duration(milliseconds: 400));
          async.flushMicrotasks();

          final state = container.read(themingControllerProvider);
          expect(state.themeMode, equals(ThemeMode.dark));

          verify(() => settingsDb.saveSettingsItem(themeModeKey, 'dark'))
              .called(1);

          final captured =
              verify(() => outboxService.enqueueMessage(captureAny())).captured;
          expect(captured.length, 1);

          final message = captured.first as SyncThemingSelection;
          expect(message.themeMode, 'dark');
        });
      });

      test('debouncing - rapid changes send only final state', () {
        fakeAsync((async) {
          final controller = container.read(themingControllerProvider.notifier);

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();
          clearInteractions(outboxService);

          controller
            ..setLightTheme('Indigo')
            ..setDarkTheme('Shark')
            ..onThemeSelectionChanged({ThemeMode.dark});

          // Wait for debounce
          async.elapse(const Duration(milliseconds: 300));
          async.flushMicrotasks();

          // Verify enqueueMessage called exactly once (debounced)
          final captured =
              verify(() => outboxService.enqueueMessage(captureAny())).captured;
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
          when(() => settingsDb.itemByKey(lightSchemeNameKey))
              .thenAnswer((_) async {
            callCount++;
            return callCount == 1 ? 'Grey Law' : 'Indigo';
          });

          final states = <ThemingState>[];
          container.listen(
            themingControllerProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          clearInteractions(settingsDb);
          clearInteractions(outboxService);

          // Trigger reload via settings notification
          notificationsController.add({settingsNotification});

          async.elapse(const Duration(milliseconds: 200));
          async.flushMicrotasks();

          // Verify theme settings were reloaded
          verify(() => settingsDb.itemByKey(lightSchemeNameKey)).called(1);

          // Verify NO sync message was enqueued (synced changes don't re-sync)
          verifyNever(() => outboxService.enqueueMessage(any<SyncMessage>()));
        });
      });

      test('invalid theme name is ignored', () {
        fakeAsync((async) {
          final controller = container.read(themingControllerProvider.notifier);

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

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

        await completer.future.timeout(const Duration(milliseconds: 100));

        final state = container.read(enableTooltipsProvider);
        expect(state.hasError, isTrue);
      });
    });

    group('error handling', () {
      test('handles error in _loadSelectedSchemes and logs it', () {
        fakeAsync((async) {
          when(() => settingsDb.itemByKey(lightSchemeNameKey))
              .thenThrow(Exception('Database error'));

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
            () => loggingService.captureException(
              any<Object>(),
              domain: 'THEMING_CONTROLLER',
              subDomain: 'init',
              stackTrace: any<StackTrace>(named: 'stackTrace'),
            ),
          ).called(1);
        });
      });

      test('gracefully handles OutboxService not registered', () {
        fakeAsync((async) {
          GetIt.I.unregister<OutboxService>();

          final controller = container.read(themingControllerProvider.notifier);

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          controller.setLightTheme('Indigo');

          async.elapse(const Duration(milliseconds: 400));
          async.flushMicrotasks();

          // Should not throw exception
          // Test passes if no exception is thrown
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

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          clearInteractions(settingsDb);

          // Emit unrelated notification
          notificationsController.add({'unrelated_notification'});

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          // Verify settings were NOT reloaded
          verifyNever(() => settingsDb.itemByKey(lightSchemeNameKey));
        });
      });

      test('handles error during theme reload from sync and logs it', () {
        fakeAsync((async) {
          var callCount = 0;
          when(() => settingsDb.itemByKey(lightSchemeNameKey))
              .thenAnswer((_) async {
            callCount++;
            if (callCount > 1) {
              throw Exception('Reload error');
            }
            return 'Grey Law';
          });

          final states = <ThemingState>[];
          container.listen(
            themingControllerProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          // Trigger reload via settings notification
          notificationsController.add({settingsNotification});

          async.elapse(const Duration(milliseconds: 200));
          async.flushMicrotasks();

          // Verify error was logged
          verify(
            () => loggingService.captureException(
              any<Object>(),
              domain: 'THEMING_CONTROLLER',
              subDomain: 'theme_prefs_reload',
              stackTrace: any<StackTrace>(named: 'stackTrace'),
            ),
          ).called(1);

          // Controller should still be in valid state
          final state = container.read(themingControllerProvider);
          expect(state, isNotNull);
        });
      });

      test('handles error in enqueueMessage and logs it', () {
        fakeAsync((async) {
          when(() => outboxService.enqueueMessage(any<SyncMessage>()))
              .thenThrow(Exception('Enqueue error'));

          final controller = container.read(themingControllerProvider.notifier);

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          controller.setLightTheme('Indigo');

          // Wait for debounce
          async.elapse(const Duration(milliseconds: 400));
          async.flushMicrotasks();

          // Verify error was logged
          verify(
            () => loggingService.captureException(
              any<Object>(),
              domain: 'THEMING_SYNC',
              subDomain: 'enqueue',
              stackTrace: any<StackTrace>(named: 'stackTrace'),
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

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

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
          when(() => settingsDb.itemByKey(themeModeKey))
              .thenAnswer((_) async => null);

          final states = <ThemingState>[];
          container.listen(
            themingControllerProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          // Should default to system theme mode
          expect(states.last.themeMode, equals(ThemeMode.system));
        });
      });

      test('handles invalid theme mode string gracefully', () {
        fakeAsync((async) {
          when(() => settingsDb.itemByKey(themeModeKey))
              .thenAnswer((_) async => 'invalid_mode');

          final states = <ThemingState>[];
          container.listen(
            themingControllerProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          // Should default to system theme mode
          expect(states.last.themeMode, equals(ThemeMode.system));
        });
      });

      test('handles null theme names gracefully', () {
        fakeAsync((async) {
          when(() => settingsDb.itemByKey(lightSchemeNameKey))
              .thenAnswer((_) async => null);
          when(() => settingsDb.itemByKey(darkSchemeNameKey))
              .thenAnswer((_) async => null);

          final states = <ThemingState>[];
          container.listen(
            themingControllerProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          // Should default to Grey Law
          expect(states.last.lightThemeName, equals('Grey Law'));
          expect(states.last.darkThemeName, equals('Grey Law'));
        });
      });

      test('invalid dark theme name is ignored', () {
        fakeAsync((async) {
          final controller = container.read(themingControllerProvider.notifier);

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          // Initial load completed
          verify(() => settingsDb.itemByKey(lightSchemeNameKey)).called(1);

          // Emit unrelated notification (should be ignored)
          notificationsController.add({'some_other_notification'});

          async.elapse(const Duration(milliseconds: 200));
          async.flushMicrotasks();

          // No additional load triggered
          verifyNever(() => settingsDb.itemByKey(lightSchemeNameKey));
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

      group('isUsingGameyTheme', () {
        test('returns true when light theme is gamey', () {
          final state = ThemingState(
            darkTheme: ThemeData.dark(),
            lightTheme: ThemeData.light(),
            darkThemeName: 'Grey Law',
            lightThemeName: gameyThemeName,
          );

          expect(state.isUsingGameyTheme, isTrue);
        });

        test('returns true when dark theme is gamey', () {
          final state = ThemingState(
            darkTheme: ThemeData.dark(),
            lightTheme: ThemeData.light(),
            darkThemeName: gameyThemeName,
            lightThemeName: 'Grey Law',
          );

          expect(state.isUsingGameyTheme, isTrue);
        });

        test('returns true when both themes are gamey', () {
          final state = ThemingState(
            darkTheme: ThemeData.dark(),
            lightTheme: ThemeData.light(),
            darkThemeName: gameyThemeName,
            lightThemeName: gameyThemeName,
          );

          expect(state.isUsingGameyTheme, isTrue);
        });

        test('returns false when neither theme is gamey', () {
          final state = ThemingState(
            darkTheme: ThemeData.dark(),
            lightTheme: ThemeData.light(),
            darkThemeName: 'Grey Law',
            lightThemeName: 'Indigo',
          );

          expect(state.isUsingGameyTheme, isFalse);
        });

        test('returns false when theme names are null', () {
          const state = ThemingState();

          expect(state.isUsingGameyTheme, isFalse);
        });
      });
    });

    group('Gamey theme integration', () {
      test('setLightTheme accepts gamey theme', () {
        fakeAsync((async) {
          when(() => settingsDb.itemByKey(lightSchemeNameKey))
              .thenAnswer((_) async => 'Grey Law');

          final controller = container.read(themingControllerProvider.notifier);

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          controller.setLightTheme(gameyThemeName);

          final state = container.read(themingControllerProvider);
          expect(state.lightThemeName, equals(gameyThemeName));
          expect(state.isUsingGameyTheme, isTrue);

          verify(
            () => settingsDb.saveSettingsItem(
              lightSchemeNameKey,
              gameyThemeName,
            ),
          ).called(1);
        });
      });

      test('setDarkTheme accepts gamey theme', () {
        fakeAsync((async) {
          when(() => settingsDb.itemByKey(darkSchemeNameKey))
              .thenAnswer((_) async => 'Grey Law');

          final controller = container.read(themingControllerProvider.notifier);

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          controller.setDarkTheme(gameyThemeName);

          final state = container.read(themingControllerProvider);
          expect(state.darkThemeName, equals(gameyThemeName));
          expect(state.isUsingGameyTheme, isTrue);

          verify(
            () => settingsDb.saveSettingsItem(
              darkSchemeNameKey,
              gameyThemeName,
            ),
          ).called(1);
        });
      });

      test('loads saved gamey theme from preferences', () {
        fakeAsync((async) {
          when(() => settingsDb.itemByKey(lightSchemeNameKey))
              .thenAnswer((_) async => gameyThemeName);
          when(() => settingsDb.itemByKey(darkSchemeNameKey))
              .thenAnswer((_) async => gameyThemeName);

          final states = <ThemingState>[];
          container.listen(
            themingControllerProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          expect(states.last.lightThemeName, equals(gameyThemeName));
          expect(states.last.darkThemeName, equals(gameyThemeName));
          expect(states.last.isUsingGameyTheme, isTrue);
        });
      });

      test('gamey theme builds valid ThemeData', () {
        fakeAsync((async) {
          when(() => settingsDb.itemByKey(lightSchemeNameKey))
              .thenAnswer((_) async => gameyThemeName);
          when(() => settingsDb.itemByKey(darkSchemeNameKey))
              .thenAnswer((_) async => gameyThemeName);

          final states = <ThemingState>[];
          container.listen(
            themingControllerProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          // Verify ThemeData is valid and not null
          expect(states.last.lightTheme, isNotNull);
          expect(states.last.darkTheme, isNotNull);
          expect(states.last.lightTheme, isA<ThemeData>());
          expect(states.last.darkTheme, isA<ThemeData>());
        });
      });
    });
  });
}
