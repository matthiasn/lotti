import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/blocs/theming/theming_cubit.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
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
  late ThemingCubit cubit;

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

    // Setup default mock behaviors
    when(() => settingsDb.itemByKey(any<String>()))
        .thenAnswer((_) async => 'Grey Law');
    when(() => settingsDb.saveSettingsItem(any<String>(), any<String>()))
        .thenAnswer((_) async => 1);
    when(() => journalDb.watchConfigFlag(any<String>()))
        .thenAnswer((_) => Stream.value(false));
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

    // Create cubit
    cubit = ThemingCubit();

    // Wait for cubit initialization to complete
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Clear any interactions that happened during initialization
    clearInteractions(outboxService);
    clearInteractions(settingsDb);
    clearInteractions(loggingService);
  });

  tearDown(() async {
    EasyDebounce.cancelAll();
    await cubit.close();
  });

  group('ThemingCubit Sync', () {
    test('setLightTheme enqueues sync message', () async {
      // Cancel any pending debounces and clear interactions
      EasyDebounce.cancelAll();
      clearInteractions(outboxService);

      cubit.setLightTheme('Indigo');

      // Wait for debounce with extra time for first test
      await Future<void>.delayed(const Duration(milliseconds: 400));

      // Verify enqueueMessage was called
      final captured =
          verify(() => outboxService.enqueueMessage(captureAny())).captured;
      expect(captured.length, 1);

      final message = captured.first as SyncThemingSelection;
      expect(message.lightThemeName, 'Indigo');
      expect(message.status, SyncEntryStatus.update);
    });

    test('setDarkTheme enqueues sync message', () async {
      // Cancel any pending debounces and clear interactions
      EasyDebounce.cancelAll();
      clearInteractions(outboxService);

      cubit.setDarkTheme('Shark');

      // Wait for debounce with extra time
      await Future<void>.delayed(const Duration(milliseconds: 400));

      // Verify enqueueMessage was called
      final captured =
          verify(() => outboxService.enqueueMessage(captureAny())).captured;
      expect(captured.length, 1);

      final message = captured.first as SyncThemingSelection;
      expect(message.darkThemeName, 'Shark');
      expect(message.status, SyncEntryStatus.update);
    });

    test('onThemeSelectionChanged enqueues sync message', () async {
      // Cancel any pending debounces and clear interactions
      EasyDebounce.cancelAll();
      clearInteractions(outboxService);

      cubit.onThemeSelectionChanged({ThemeMode.dark});

      // Wait for debounce with extra time
      await Future<void>.delayed(const Duration(milliseconds: 400));

      // Verify enqueueMessage was called
      final captured =
          verify(() => outboxService.enqueueMessage(captureAny())).captured;
      expect(captured.length, 1);

      final message = captured.first as SyncThemingSelection;
      expect(message.themeMode, 'dark');
      expect(message.status, SyncEntryStatus.update);
    });

    test('debouncing - rapid changes send only final state', () async {
      // Make rapid changes
      cubit
        ..setLightTheme('Indigo')
        ..setDarkTheme('Shark')
        ..onThemeSelectionChanged({ThemeMode.dark});

      // Wait for debounce with sufficient time
      await Future<void>.delayed(const Duration(milliseconds: 300));

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

    test('gracefully handles OutboxService not registered', () async {
      // Create new cubit without OutboxService registered
      GetIt.I.unregister<OutboxService>();

      cubit.setLightTheme('Indigo');

      // Wait for debounce with sufficient time
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Should not throw exception
      // Test passes if no exception is thrown
    });

    test('logs error when enqueue fails', () async {
      // Mock enqueueMessage to throw
      when(() => outboxService.enqueueMessage(any<SyncMessage>()))
          .thenThrow(Exception('test error'));

      cubit.setLightTheme('Indigo');

      // Wait for debounce with sufficient time
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Verify logging service was called
      verify(
        () => loggingService.captureException(
          any<Object>(),
          domain: 'THEMING_SYNC',
          subDomain: 'enqueue',
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(1);
    });

    test('message contains all three settings', () async {
      // Set all three settings
      cubit
        ..setLightTheme('Indigo')
        ..setDarkTheme('Shark')
        ..onThemeSelectionChanged({ThemeMode.dark});

      // Wait for debounce with sufficient time
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Capture and verify message
      final captured =
          verify(() => outboxService.enqueueMessage(captureAny())).captured;
      expect(captured.length, 1);

      final message = captured.first as SyncThemingSelection;
      expect(message.lightThemeName, 'Indigo');
      expect(message.darkThemeName, 'Shark');
      expect(message.themeMode, 'dark');
    });
  });
}
