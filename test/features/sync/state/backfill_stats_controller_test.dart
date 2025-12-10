import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/backfill/backfill_request_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/state/backfill_stats_controller.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSyncSequenceLogService extends Mock
    implements SyncSequenceLogService {}

class MockBackfillRequestService extends Mock
    implements BackfillRequestService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testStats = BackfillStats.fromHostStats([
    const BackfillHostStats(
      hostId: 'host-1',
      receivedCount: 100,
      missingCount: 5,
      requestedCount: 2,
      backfilledCount: 10,
      deletedCount: 1,
      latestCounter: 118,
    ),
  ]);

  group('BackfillStatsController', () {
    late MockSyncSequenceLogService mockSequenceService;
    late MockBackfillRequestService mockBackfillService;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'backfill_enabled': true});
      await getIt.reset();

      mockSequenceService = MockSyncSequenceLogService();
      mockBackfillService = MockBackfillRequestService();

      getIt
        ..registerSingleton<SyncSequenceLogService>(mockSequenceService)
        ..registerSingleton<BackfillRequestService>(mockBackfillService);
    });

    tearDown(() async {
      container.dispose();
      await getIt.reset();
    });

    Future<void> waitForStats(ProviderContainer c) async {
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final state = c.read(backfillStatsControllerProvider);
        if (state.stats != null) return;
      }
    }

    test('loads stats on build', () async {
      when(() => mockSequenceService.getBackfillStats())
          .thenAnswer((_) async => testStats);

      container = ProviderContainer();

      // Listen to state changes
      final completer = Completer<BackfillStatsState>();
      container.listen(
        backfillStatsControllerProvider,
        (previous, next) {
          if (next.stats != null && !completer.isCompleted) {
            completer.complete(next);
          }
        },
        fireImmediately: true,
      );

      // Wait for stats to load with timeout
      final state = await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => container.read(backfillStatsControllerProvider),
      );

      expect(state.stats, testStats);
      expect(state.error, isNull);
    });

    test('refresh reloads stats', () async {
      when(() => mockSequenceService.getBackfillStats())
          .thenAnswer((_) async => testStats);

      container = ProviderContainer();
      await waitForStats(container);

      // Reset verify counts after initial load
      clearInteractions(mockSequenceService);

      final controller =
          container.read(backfillStatsControllerProvider.notifier);
      await controller.refresh();

      // Should only count the refresh call, not the initial build call
      verify(() => mockSequenceService.getBackfillStats()).called(1);
    });

    test('handles error during refresh', () async {
      var callCount = 0;
      when(() => mockSequenceService.getBackfillStats()).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          return testStats;
        }
        throw Exception('Test error');
      });

      container = ProviderContainer();
      await waitForStats(container);

      final controller =
          container.read(backfillStatsControllerProvider.notifier);
      await controller.refresh();

      final state = container.read(backfillStatsControllerProvider);
      expect(state.error, contains('Test error'));
    });

    test('triggerFullBackfill calls service and refreshes stats', () async {
      when(() => mockSequenceService.getBackfillStats())
          .thenAnswer((_) async => testStats);
      when(() => mockBackfillService.processFullBackfill())
          .thenAnswer((_) async => 10);

      container = ProviderContainer();
      await waitForStats(container);

      // Reset verify counts after initial load
      clearInteractions(mockSequenceService);

      final controller =
          container.read(backfillStatsControllerProvider.notifier);
      await controller.triggerFullBackfill();

      verify(() => mockBackfillService.processFullBackfill()).called(1);
      // Should call getBackfillStats once on refresh after backfill
      verify(() => mockSequenceService.getBackfillStats()).called(1);

      final state = container.read(backfillStatsControllerProvider);
      expect(state.isProcessing, isFalse);
      expect(state.lastProcessedCount, 10);
    });

    test('triggerFullBackfill sets isProcessing during operation', () async {
      when(() => mockSequenceService.getBackfillStats())
          .thenAnswer((_) async => testStats);

      var backfillStarted = false;
      when(() => mockBackfillService.processFullBackfill()).thenAnswer(
        (_) async {
          backfillStarted = true;
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return 5;
        },
      );

      container = ProviderContainer();
      await waitForStats(container);

      final controller =
          container.read(backfillStatsControllerProvider.notifier);
      final future = controller.triggerFullBackfill();

      // Wait for backfill to start
      while (!backfillStarted) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      var state = container.read(backfillStatsControllerProvider);
      expect(state.isProcessing, isTrue);

      await future;

      state = container.read(backfillStatsControllerProvider);
      expect(state.isProcessing, isFalse);
    });

    test('triggerFullBackfill handles errors', () async {
      when(() => mockSequenceService.getBackfillStats())
          .thenAnswer((_) async => testStats);
      when(() => mockBackfillService.processFullBackfill())
          .thenAnswer((_) async => throw Exception('Backfill failed'));

      container = ProviderContainer();
      await waitForStats(container);

      final controller =
          container.read(backfillStatsControllerProvider.notifier);
      await controller.triggerFullBackfill();

      final state = container.read(backfillStatsControllerProvider);
      expect(state.isProcessing, isFalse);
      expect(state.error, contains('Backfill failed'));
    });

    test('triggerFullBackfill does nothing if already processing', () async {
      when(() => mockSequenceService.getBackfillStats())
          .thenAnswer((_) async => testStats);
      when(() => mockBackfillService.processFullBackfill()).thenAnswer(
        (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return 5;
        },
      );

      container = ProviderContainer();
      await waitForStats(container);

      final controller =
          container.read(backfillStatsControllerProvider.notifier);

      // Start first trigger
      final future1 = controller.triggerFullBackfill();

      // Wait a bit then try to trigger again
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await controller.triggerFullBackfill();

      await future1;

      // Should only have been called once
      verify(() => mockBackfillService.processFullBackfill()).called(1);
    });

    test('triggerReRequest calls service and refreshes stats', () async {
      when(() => mockSequenceService.getBackfillStats())
          .thenAnswer((_) async => testStats);
      when(() => mockBackfillService.processReRequest())
          .thenAnswer((_) async => 15);

      container = ProviderContainer();
      await waitForStats(container);

      // Reset verify counts after initial load
      clearInteractions(mockSequenceService);

      final controller =
          container.read(backfillStatsControllerProvider.notifier);
      await controller.triggerReRequest();

      verify(() => mockBackfillService.processReRequest()).called(1);
      // Should call getBackfillStats once on refresh after re-request
      verify(() => mockSequenceService.getBackfillStats()).called(1);

      final state = container.read(backfillStatsControllerProvider);
      expect(state.isReRequesting, isFalse);
      expect(state.lastReRequestedCount, 15);
    });

    test('triggerReRequest sets isReRequesting during operation', () async {
      when(() => mockSequenceService.getBackfillStats())
          .thenAnswer((_) async => testStats);

      var reRequestStarted = false;
      when(() => mockBackfillService.processReRequest()).thenAnswer(
        (_) async {
          reRequestStarted = true;
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return 8;
        },
      );

      container = ProviderContainer();
      await waitForStats(container);

      final controller =
          container.read(backfillStatsControllerProvider.notifier);
      final future = controller.triggerReRequest();

      // Wait for re-request to start
      while (!reRequestStarted) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      var state = container.read(backfillStatsControllerProvider);
      expect(state.isReRequesting, isTrue);

      await future;

      state = container.read(backfillStatsControllerProvider);
      expect(state.isReRequesting, isFalse);
    });

    test('triggerReRequest handles errors', () async {
      when(() => mockSequenceService.getBackfillStats())
          .thenAnswer((_) async => testStats);
      when(() => mockBackfillService.processReRequest())
          .thenAnswer((_) async => throw Exception('Re-request failed'));

      container = ProviderContainer();
      await waitForStats(container);

      final controller =
          container.read(backfillStatsControllerProvider.notifier);
      await controller.triggerReRequest();

      final state = container.read(backfillStatsControllerProvider);
      expect(state.isReRequesting, isFalse);
      expect(state.error, contains('Re-request failed'));
    });

    test('triggerReRequest does nothing if already re-requesting', () async {
      when(() => mockSequenceService.getBackfillStats())
          .thenAnswer((_) async => testStats);
      when(() => mockBackfillService.processReRequest()).thenAnswer(
        (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return 5;
        },
      );

      container = ProviderContainer();
      await waitForStats(container);

      final controller =
          container.read(backfillStatsControllerProvider.notifier);

      // Start first trigger
      final future1 = controller.triggerReRequest();

      // Wait a bit then try to trigger again
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await controller.triggerReRequest();

      await future1;

      // Should only have been called once
      verify(() => mockBackfillService.processReRequest()).called(1);
    });

    test('triggerReRequest does nothing if already processing backfill',
        () async {
      when(() => mockSequenceService.getBackfillStats())
          .thenAnswer((_) async => testStats);
      when(() => mockBackfillService.processFullBackfill()).thenAnswer(
        (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return 5;
        },
      );

      container = ProviderContainer();
      await waitForStats(container);

      final controller =
          container.read(backfillStatsControllerProvider.notifier);

      // Start full backfill first
      final future1 = controller.triggerFullBackfill();

      // Wait a bit then try to trigger re-request
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await controller.triggerReRequest();

      await future1;

      // processReRequest should not have been called
      verifyNever(() => mockBackfillService.processReRequest());
    });
  });

  group('BackfillStatsState', () {
    test('copyWith preserves values when not overridden', () {
      final state = BackfillStatsState(
        stats: testStats,
        isProcessing: true,
        lastProcessedCount: 5,
        error: 'some error',
      );

      final copied = state.copyWith();

      expect(copied.stats, testStats);
      expect(copied.isLoading, isFalse);
      expect(copied.isProcessing, isTrue);
      expect(copied.lastProcessedCount, 5);
      expect(copied.error, 'some error');
    });

    test('copyWith overrides specified values', () {
      const state = BackfillStatsState();

      final copied = state.copyWith(
        isLoading: true,
        isProcessing: true,
        lastProcessedCount: 10,
        error: 'new error',
      );

      expect(copied.isLoading, isTrue);
      expect(copied.isProcessing, isTrue);
      expect(copied.lastProcessedCount, 10);
      expect(copied.error, 'new error');
    });

    test('copyWith clearError removes error', () {
      const state = BackfillStatsState(error: 'some error');

      final copied = state.copyWith(clearError: true);

      expect(copied.error, isNull);
    });

    test('copyWith clearLastProcessed removes lastProcessedCount', () {
      const state = BackfillStatsState(lastProcessedCount: 10);

      final copied = state.copyWith(clearLastProcessed: true);

      expect(copied.lastProcessedCount, isNull);
    });

    test('copyWith clearLastReRequested removes lastReRequestedCount', () {
      const state = BackfillStatsState(lastReRequestedCount: 25);

      final copied = state.copyWith(clearLastReRequested: true);

      expect(copied.lastReRequestedCount, isNull);
    });

    test('copyWith preserves isReRequesting when not overridden', () {
      const state = BackfillStatsState(isReRequesting: true);

      final copied = state.copyWith();

      expect(copied.isReRequesting, isTrue);
    });

    test('copyWith overrides isReRequesting', () {
      const state = BackfillStatsState();

      final copied = state.copyWith(isReRequesting: true);

      expect(copied.isReRequesting, isTrue);
    });

    test('copyWith overrides lastReRequestedCount', () {
      const state = BackfillStatsState();

      final copied = state.copyWith(lastReRequestedCount: 42);

      expect(copied.lastReRequestedCount, 42);
    });
  });
}
