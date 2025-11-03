import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/blocs/theming/theming_cubit.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/settings/constants/theming_settings_keys.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

class MockSettingsDb extends Mock implements SettingsDb {}

class MockJournalDb extends Mock implements JournalDb {}

class MockLoggingService extends Mock implements LoggingService {}

class MockOutboxService extends Mock implements OutboxService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSettingsDb settingsDb;
  late MockJournalDb journalDb;
  late MockLoggingService loggingService;
  late MockOutboxService outboxService;
  late StreamController<bool> tooltipController;
  late StreamController<List<SettingsItem>> themePrefsController;

  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(
      const SyncMessage.themingSelection(
        lightThemeName: '',
        darkThemeName: '',
        themeMode: '',
        updatedAt: 0,
        status: SyncEntryStatus.update,
      ),
    );
  });

  setUp(() async {
    // Allow reassignment for testing
    GetIt.I.allowReassignment = true;

    // Create mocks
    settingsDb = MockSettingsDb();
    journalDb = MockJournalDb();
    loggingService = MockLoggingService();
    outboxService = MockOutboxService();

    // Create stream controllers
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

    // Register in GetIt
    GetIt.I.registerSingleton<SettingsDb>(settingsDb);
    GetIt.I.registerSingleton<JournalDb>(journalDb);
    GetIt.I.registerSingleton<LoggingService>(loggingService);
    GetIt.I.registerSingleton<OutboxService>(outboxService);
  });

  tearDown(() async {
    await tooltipController.close();
    await themePrefsController.close();
    await GetIt.I.reset();
  });

  group('ThemingCubit Error Handling', () {
    test('handles error in _loadSelectedSchemes and logs it', () async {
      // Setup mock to throw error
      when(() => settingsDb.itemByKey(lightSchemeNameKey))
          .thenThrow(Exception('Database error'));

      // Create cubit - should not crash
      final cubit = ThemingCubit();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify error was captured
      verify(
        () => loggingService.captureException(
          any<Object>(),
          domain: 'THEMING_CUBIT',
          subDomain: 'init',
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(1);

      // Cubit should still be in valid state (with initial values)
      expect(cubit.state, isNotNull);
      expect(cubit.state.enableTooltips, true);

      await cubit.close();
    });

    test('handles error in tooltip stream subscription', () async {
      // Setup tooltip stream to emit error with isolated controller
      final tooltipErrorController = StreamController<bool>.broadcast();
      when(() => journalDb.watchConfigFlag(enableTooltipFlag))
          .thenAnswer((_) => tooltipErrorController.stream);

      // Create cubit
      final cubit = ThemingCubit();
      // Increase delay for parallel test execution
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Emit error
      tooltipErrorController.addError(Exception('Stream error'));
      // Increase delay to ensure error handler processes it
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Cubit should still be functional
      expect(cubit.state, isNotNull);

      await tooltipErrorController.close();
      await cubit.close();
    });

    test('tooltip subscription is properly cleaned up on close', () async {
      // Create cubit
      final cubit = ThemingCubit();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Verify subscription was created
      verify(() => journalDb.watchConfigFlag(enableTooltipFlag)).called(1);

      // Close cubit
      await cubit.close();

      // Try to emit after close - should not cause errors
      tooltipController.add(false);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // No errors should occur
    });

    test('theme prefs subscription is properly cleaned up on close', () async {
      // Create cubit
      final cubit = ThemingCubit();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Close cubit
      await cubit.close();

      // Try to emit after close - should not cause errors
      themePrefsController.add([
        SettingsItem(
          configKey: themePrefsUpdatedAtKey,
          value: DateTime.now().millisecondsSinceEpoch.toString(),
          updatedAt: DateTime.now(),
        ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // No errors should occur
    });

    test('initial enableTooltips state matches state constructor', () async {
      // Create cubit
      final cubit = ThemingCubit();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Initial state should have enableTooltips: true (from constructor)
      expect(cubit.state.enableTooltips, true);

      await cubit.close();
    });

    test('enableTooltips updates when stream emits new value', () async {
      // Create cubit
      final cubit = ThemingCubit();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Listen to state changes
      final states = <bool>[];
      cubit.stream.listen((state) {
        states.add(state.enableTooltips);
      });

      // Emit tooltip change
      tooltipController.add(false);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Verify state was updated
      expect(cubit.state.enableTooltips, false);
      expect(states, contains(false));

      // Emit another change
      tooltipController.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(cubit.state.enableTooltips, true);
      expect(states, contains(true));

      await cubit.close();
    });

    test('multiple rapid tooltip changes are handled correctly', () async {
      // Create cubit
      final cubit = ThemingCubit();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Emit multiple rapid changes
      for (var i = 0; i < 10; i++) {
        tooltipController.add(i.isEven);
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      // Wait for processing
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Final state should reflect last emission (9.isEven is false)
      expect(cubit.state.enableTooltips, false);

      await cubit.close();
    });

    test('concurrent errors in init do not crash cubit', () async {
      // Setup multiple mocks to throw errors
      when(() => settingsDb.itemByKey(lightSchemeNameKey))
          .thenThrow(Exception('Light theme error'));
      when(() => settingsDb.itemByKey(darkSchemeNameKey))
          .thenThrow(Exception('Dark theme error'));

      // Create cubit - should not crash
      final cubit = ThemingCubit();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify error was captured
      verify(
        () => loggingService.captureException(
          any<Object>(),
          domain: 'THEMING_CUBIT',
          subDomain: 'init',
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(1);

      // Cubit should still be functional
      expect(cubit.state, isNotNull);

      await cubit.close();
    });

    test('error during theme load does not affect tooltip subscription',
        () async {
      // Setup theme load to fail
      when(() => settingsDb.itemByKey(lightSchemeNameKey))
          .thenThrow(Exception('Theme error'));

      // Create cubit
      final cubit = ThemingCubit();
      // Increase delay to ensure init completes even with error
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Listen to state changes to verify update
      final states = <bool>[];
      final subscription = cubit.stream.listen((state) {
        states.add(state.enableTooltips);
      });

      // Tooltip subscription should still work
      tooltipController.add(false);
      // Increase delay to ensure state update propagates in parallel test execution
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(cubit.state.enableTooltips, false);
      expect(states, contains(false));

      await subscription.cancel();
      await cubit.close();
    });
  });
}
