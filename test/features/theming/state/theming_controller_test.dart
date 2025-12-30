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
import 'package:lotti/features/theming/state/theming_controller.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

class MockOutboxService extends Mock implements OutboxService {}

class MockSettingsDb extends Mock implements SettingsDb {}

class MockJournalDb extends Mock implements JournalDb {}

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemingController', () {
    late MockOutboxService outboxService;
    late MockSettingsDb settingsDb;
    late MockJournalDb journalDb;
    late MockLoggingService loggingService;
    late StreamController<bool> tooltipController;
    late StreamController<List<SettingsItem>> themePrefsController;
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

      tooltipController = StreamController<bool>.broadcast();
      themePrefsController = StreamController<List<SettingsItem>>.broadcast();

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
      when(() => settingsDb.watchSettingsItemByKey(themePrefsUpdatedAtKey))
          .thenAnswer((_) => themePrefsController.stream);
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
        ..registerSingleton<OutboxService>(outboxService)
        ..registerSingleton<SettingsDb>(settingsDb)
        ..registerSingleton<JournalDb>(journalDb)
        ..registerSingleton<LoggingService>(loggingService);

      container = ProviderContainer();
    });

    tearDown(() async {
      EasyDebounce.cancelAll();
      await tooltipController.close();
      await themePrefsController.close();
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

          // Emit change through stream
          final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
          themePrefsController.add([
            SettingsItem(
              configKey: themePrefsUpdatedAtKey,
              value: timestamp,
              updatedAt: DateTime.now(),
            ),
          ]);

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
    });
  });
}
