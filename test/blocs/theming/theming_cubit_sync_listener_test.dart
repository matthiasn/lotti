// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/blocs/theming/theming_cubit.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/settings/constants/theming_settings_keys.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockOutboxService extends Mock implements OutboxService {}

class MockSettingsDb extends Mock implements SettingsDb {}

class MockJournalDb extends Mock implements JournalDb {}

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockOutboxService outboxService;
  late MockSettingsDb settingsDb;
  late MockJournalDb journalDb;
  late MockLoggingService loggingService;
  late StreamController<List<SettingsItem>> themePrefsController;

  setUpAll(() {
    // Register fallback values for mocktail
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
    // Allow reassignment for testing
    GetIt.I.allowReassignment = true;

    // Create mocks
    outboxService = MockOutboxService();
    settingsDb = MockSettingsDb();
    journalDb = MockJournalDb();
    loggingService = MockLoggingService();

    // Create stream controller for theme prefs updates
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
    when(() => journalDb.watchConfigFlag(any<String>()))
        .thenAnswer((_) => Stream.value(false));
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

    // Register in GetIt
    GetIt.I.registerSingleton<OutboxService>(outboxService);
    GetIt.I.registerSingleton<SettingsDb>(settingsDb);
    GetIt.I.registerSingleton<JournalDb>(journalDb);
    GetIt.I.registerSingleton<LoggingService>(loggingService);
  });

  tearDown(() async {
    await themePrefsController.close();
    await GetIt.I.reset();
  });

  group('Theme Sync Listener', () {
    test('cubit subscribes to themePrefsUpdatedAtKey stream on init', () {
      fakeAsync((async) {
        // Create cubit
        final cubit = ThemingCubit();
        async.flushMicrotasks(); // Yield to initialization microtasks

        // Verify subscription was created
        verify(() => settingsDb.watchSettingsItemByKey(themePrefsUpdatedAtKey))
            .called(1);

        unawaited(cubit.close());
      });
    });

    test('stream emission triggers theme reload when items not empty', () {
      fakeAsync((async) {
        // Setup mock to return different theme on second call
        var callCount = 0;
        when(() => settingsDb.itemByKey(lightSchemeNameKey))
            .thenAnswer((_) async {
          callCount++;
          return callCount == 1 ? 'Grey Law' : 'Indigo';
        });

        // Create cubit
        final cubit = ThemingCubit();
        async.flushMicrotasks();

        // Clear initial load calls
        clearInteractions(settingsDb);

        // Emit change through stream
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        themePrefsController.add([
          SettingsItem(
            configKey: themePrefsUpdatedAtKey,
            value: timestamp,
            updatedAt: DateTime.now(),
          ),
        ]);

        // Wait for async processing
        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        // Verify theme settings were reloaded
        verify(() => settingsDb.itemByKey(lightSchemeNameKey)).called(1);
        verify(() => settingsDb.itemByKey(darkSchemeNameKey)).called(1);
        verify(() => settingsDb.itemByKey(themeModeKey)).called(1);

        // Verify state was emitted (check final state has new theme)
        expect(cubit.state.lightThemeName, 'Indigo');

        unawaited(cubit.close());
      });
    });

    test('stream emission with empty items does not trigger reload', () {
      fakeAsync((async) {
        // Create cubit
        final cubit = ThemingCubit();
        async.flushMicrotasks();

        // Clear initial load calls
        clearInteractions(settingsDb);

        // Emit empty list
        themePrefsController.add([]);

        // Wait for potential async processing
        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        // Verify no reload happened
        verifyNever(() => settingsDb.itemByKey(lightSchemeNameKey));
        verifyNever(() => settingsDb.itemByKey(darkSchemeNameKey));
        verifyNever(() => settingsDb.itemByKey(themeModeKey));

        unawaited(cubit.close());
      });
    });

    test('sync message not enqueued when applying synced changes', () {
      fakeAsync((async) {
        // Setup mock to return different theme
        when(() => settingsDb.itemByKey(lightSchemeNameKey))
            .thenAnswer((_) async => 'Indigo');

        // Create cubit
        final cubit = ThemingCubit();
        async.flushMicrotasks();

        // Clear initial interactions
        clearInteractions(outboxService);

        // Emit change through stream (simulating incoming sync)
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        themePrefsController.add([
          SettingsItem(
            configKey: themePrefsUpdatedAtKey,
            value: timestamp,
            updatedAt: DateTime.now(),
          ),
        ]);

        // Wait for async processing and debounce
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        // Verify NO sync message was enqueued
        verifyNever(() => outboxService.enqueueMessage(any<SyncMessage>()));

        unawaited(cubit.close());
      });
    });

    test('local theme change enqueues sync message after synced change', () {
      fakeAsync((async) {
        // Create cubit
        final cubit = ThemingCubit();
        async.flushMicrotasks();

        // Emit synced change
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        themePrefsController.add([
          SettingsItem(
            configKey: themePrefsUpdatedAtKey,
            value: timestamp,
            updatedAt: DateTime.now(),
          ),
        ]);

        // Wait for sync to be applied
        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        // Clear interactions
        clearInteractions(outboxService);

        // Now make local change
        cubit.setLightTheme('Shark');

        // Wait for debounce
        async.elapse(const Duration(milliseconds: 400));
        async.flushMicrotasks();

        // Verify sync message WAS enqueued for local change
        verify(() => outboxService.enqueueMessage(any<SyncMessage>()))
            .called(1);

        unawaited(cubit.close());
      });
    });

    test('multiple rapid stream emissions are handled correctly', () {
      fakeAsync((async) {
        // Track reload calls
        when(() => settingsDb.itemByKey(lightSchemeNameKey))
            .thenAnswer((_) async => 'Grey Law');

        // Create cubit
        final cubit = ThemingCubit();
        async.flushMicrotasks();

        // Clear initial load
        clearInteractions(settingsDb);

        // Emit multiple changes rapidly
        for (var i = 0; i < 5; i++) {
          final timestamp =
              (DateTime.now().millisecondsSinceEpoch + i).toString();
          themePrefsController.add([
            SettingsItem(
              configKey: themePrefsUpdatedAtKey,
              value: timestamp,
              updatedAt: DateTime.now(),
            ),
          ]);
          async.elapse(const Duration(milliseconds: 10));
          async.flushMicrotasks();
        }

        // Wait for all to process
        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();

        // Verify all reloads happened
        verify(() => settingsDb.itemByKey(lightSchemeNameKey))
            .called(greaterThanOrEqualTo(5));

        unawaited(cubit.close());
      });
    });

    test('stream subscription is cancelled on cubit close', () {
      fakeAsync((async) {
        // Create cubit
        final cubit = ThemingCubit();
        async.flushMicrotasks();

        // Close cubit
        cubit.close();
        async.flushMicrotasks();

        // Emit after close should not cause errors or reloads
        clearInteractions(settingsDb);

        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        themePrefsController.add([
          SettingsItem(
            configKey: themePrefsUpdatedAtKey,
            value: timestamp,
            updatedAt: DateTime.now(),
          ),
        ]);

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        // Verify no reloads happened
        verifyNever(() => settingsDb.itemByKey(lightSchemeNameKey));
      });
    });

    test('cubit handles stream emission during initial load', () {
      fakeAsync((async) {
        // Setup slow initial load
        when(() => settingsDb.itemByKey(lightSchemeNameKey)).thenAnswer(
          (_) => Future.delayed(
            const Duration(milliseconds: 100),
            () => 'Grey Law',
          ),
        );

        // Create cubit
        final cubit = ThemingCubit();

        // Immediately emit stream change before init completes
        async.elapse(const Duration(milliseconds: 10));
        async.flushMicrotasks();
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        themePrefsController.add([
          SettingsItem(
            configKey: themePrefsUpdatedAtKey,
            value: timestamp,
            updatedAt: DateTime.now(),
          ),
        ]);

        // Wait for everything to complete
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        // Verify no crashes and cubit is in valid state
        expect(cubit.state.lightThemeName, isNotNull);

        unawaited(cubit.close());
      });
    });

    test('prevents infinite loop between local and synced changes', () {
      fakeAsync((async) {
        // Create cubit
        final cubit = ThemingCubit();
        async.flushMicrotasks();

        clearInteractions(outboxService);
        clearInteractions(settingsDb);

        // Simulate synced change
        var timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        themePrefsController.add([
          SettingsItem(
            configKey: themePrefsUpdatedAtKey,
            value: timestamp,
            updatedAt: DateTime.now(),
          ),
        ]);

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        // Should NOT have enqueued sync message
        verifyNever(() => outboxService.enqueueMessage(any<SyncMessage>()));

        // Now simulate another synced change immediately after
        timestamp = (DateTime.now().millisecondsSinceEpoch + 1).toString();
        themePrefsController.add([
          SettingsItem(
            configKey: themePrefsUpdatedAtKey,
            value: timestamp,
            updatedAt: DateTime.now(),
          ),
        ]);

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        // Still should NOT have enqueued any sync messages
        verifyNever(() => outboxService.enqueueMessage(any<SyncMessage>()));

        unawaited(cubit.close());
      });
    });

    test('state is emitted after applying synced changes', () {
      fakeAsync((async) {
        // Setup mock to return specific theme
        when(() => settingsDb.itemByKey(lightSchemeNameKey))
            .thenAnswer((_) async => 'Shark');
        when(() => settingsDb.itemByKey(darkSchemeNameKey))
            .thenAnswer((_) async => 'Indigo');

        // Create cubit
        final cubit = ThemingCubit();
        async.flushMicrotasks();

        // Listen to state changes
        final states = <String>[];
        cubit.stream.listen((state) {
          states.add('${state.lightThemeName}-${state.darkThemeName}');
        });

        // Emit synced change
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        themePrefsController.add([
          SettingsItem(
            configKey: themePrefsUpdatedAtKey,
            value: timestamp,
            updatedAt: DateTime.now(),
          ),
        ]);

        // Wait for processing
        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        // Verify state was emitted with updated themes
        expect(states, contains('Shark-Indigo'));

        unawaited(cubit.close());
      });
    });
  });
}
