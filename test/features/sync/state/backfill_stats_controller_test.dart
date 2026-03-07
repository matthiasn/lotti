import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/backfill/backfill_request_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/state/backfill_stats_controller.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testStats = BackfillStats.fromHostStats([
    const BackfillHostStats(
      receivedCount: 100,
      missingCount: 5,
      requestedCount: 2,
      backfilledCount: 10,
      deletedCount: 1,
      unresolvableCount: 0,
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

    /// Creates the container, triggers the provider build, and flushes
    /// microtasks so that [_loadStats] completes synchronously under
    /// [fakeAsync].
    void createAndLoad(FakeAsync async) {
      container = ProviderContainer()..read(backfillStatsControllerProvider);
      async.flushMicrotasks();
    }

    /// Reads the controller notifier and invokes [action] on it, then
    /// flushes microtasks so the async operation progresses.
    void act(
      FakeAsync async,
      void Function(BackfillStatsController) action,
    ) {
      action(container.read(backfillStatsControllerProvider.notifier));
      async.flushMicrotasks();
    }

    test('loads stats on build', () {
      fakeAsync((async) {
        when(
          () => mockSequenceService.getBackfillStats(),
        ).thenAnswer((_) async => testStats);

        createAndLoad(async);

        final state = container.read(backfillStatsControllerProvider);
        expect(state.stats, testStats);
        expect(state.error, isNull);
      });
    });

    test('refresh reloads stats', () {
      fakeAsync((async) {
        when(
          () => mockSequenceService.getBackfillStats(),
        ).thenAnswer((_) async => testStats);

        createAndLoad(async);
        clearInteractions(mockSequenceService);

        container.read(backfillStatsControllerProvider.notifier).refresh();
        async.flushMicrotasks();

        verify(() => mockSequenceService.getBackfillStats()).called(1);
      });
    });

    test('handles error during refresh', () {
      fakeAsync((async) {
        var callCount = 0;
        when(() => mockSequenceService.getBackfillStats()).thenAnswer((
          _,
        ) async {
          callCount++;
          if (callCount == 1) return testStats;
          throw Exception('Test error');
        });

        createAndLoad(async);

        container.read(backfillStatsControllerProvider.notifier).refresh();
        async.flushMicrotasks();

        final state = container.read(backfillStatsControllerProvider);
        expect(state.error, contains('Test error'));
      });
    });

    test('triggerFullBackfill calls service and refreshes stats', () {
      fakeAsync((async) {
        when(
          () => mockSequenceService.getBackfillStats(),
        ).thenAnswer((_) async => testStats);
        when(
          () => mockBackfillService.processFullBackfill(),
        ).thenAnswer((_) async => 10);

        createAndLoad(async);
        clearInteractions(mockSequenceService);

        container
            .read(backfillStatsControllerProvider.notifier)
            .triggerFullBackfill();
        async.flushMicrotasks();

        verify(() => mockBackfillService.processFullBackfill()).called(1);
        verify(() => mockSequenceService.getBackfillStats()).called(1);

        final state = container.read(backfillStatsControllerProvider);
        expect(state.isProcessing, isFalse);
        expect(state.lastProcessedCount, 10);
      });
    });

    test('triggerFullBackfill sets isProcessing during operation', () {
      fakeAsync((async) {
        when(
          () => mockSequenceService.getBackfillStats(),
        ).thenAnswer((_) async => testStats);
        when(() => mockBackfillService.processFullBackfill()).thenAnswer(
          (_) async {
            await Future<void>.delayed(const Duration(milliseconds: 200));
            return 5;
          },
        );

        createAndLoad(async);

        container
            .read(backfillStatsControllerProvider.notifier)
            .triggerFullBackfill();
        async.flushMicrotasks();

        var state = container.read(backfillStatsControllerProvider);
        expect(state.isProcessing, isTrue);

        async
          ..elapse(const Duration(milliseconds: 200))
          ..flushMicrotasks();

        state = container.read(backfillStatsControllerProvider);
        expect(state.isProcessing, isFalse);
      });
    });

    test('triggerFullBackfill handles errors', () {
      fakeAsync((async) {
        when(
          () => mockSequenceService.getBackfillStats(),
        ).thenAnswer((_) async => testStats);
        when(
          () => mockBackfillService.processFullBackfill(),
        ).thenAnswer((_) async => throw Exception('Backfill failed'));

        createAndLoad(async);

        container
            .read(backfillStatsControllerProvider.notifier)
            .triggerFullBackfill();
        async.flushMicrotasks();

        final state = container.read(backfillStatsControllerProvider);
        expect(state.isProcessing, isFalse);
        expect(state.error, contains('Backfill failed'));
      });
    });

    test('triggerFullBackfill does nothing if already processing', () {
      fakeAsync((async) {
        when(
          () => mockSequenceService.getBackfillStats(),
        ).thenAnswer((_) async => testStats);
        when(() => mockBackfillService.processFullBackfill()).thenAnswer(
          (_) async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            return 5;
          },
        );

        createAndLoad(async);

        // Start first trigger, then try a second while first is processing
        act(async, (c) => c.triggerFullBackfill());
        act(async, (c) => c.triggerFullBackfill());

        // Complete the first one
        async
          ..elapse(const Duration(milliseconds: 100))
          ..flushMicrotasks();

        verify(() => mockBackfillService.processFullBackfill()).called(1);
      });
    });

    test('triggerReRequest calls service and refreshes stats', () {
      fakeAsync((async) {
        when(
          () => mockSequenceService.getBackfillStats(),
        ).thenAnswer((_) async => testStats);
        when(
          () => mockBackfillService.processReRequest(),
        ).thenAnswer((_) async => 15);

        createAndLoad(async);
        clearInteractions(mockSequenceService);

        container
            .read(backfillStatsControllerProvider.notifier)
            .triggerReRequest();
        async.flushMicrotasks();

        verify(() => mockBackfillService.processReRequest()).called(1);
        verify(() => mockSequenceService.getBackfillStats()).called(1);

        final state = container.read(backfillStatsControllerProvider);
        expect(state.isReRequesting, isFalse);
        expect(state.lastReRequestedCount, 15);
      });
    });

    test('triggerReRequest sets isReRequesting during operation', () {
      fakeAsync((async) {
        when(
          () => mockSequenceService.getBackfillStats(),
        ).thenAnswer((_) async => testStats);
        when(() => mockBackfillService.processReRequest()).thenAnswer(
          (_) async {
            await Future<void>.delayed(const Duration(milliseconds: 200));
            return 8;
          },
        );

        createAndLoad(async);

        container
            .read(backfillStatsControllerProvider.notifier)
            .triggerReRequest();
        async.flushMicrotasks();

        var state = container.read(backfillStatsControllerProvider);
        expect(state.isReRequesting, isTrue);

        async
          ..elapse(const Duration(milliseconds: 200))
          ..flushMicrotasks();

        state = container.read(backfillStatsControllerProvider);
        expect(state.isReRequesting, isFalse);
      });
    });

    test('triggerReRequest handles errors', () {
      fakeAsync((async) {
        when(
          () => mockSequenceService.getBackfillStats(),
        ).thenAnswer((_) async => testStats);
        when(
          () => mockBackfillService.processReRequest(),
        ).thenAnswer((_) async => throw Exception('Re-request failed'));

        createAndLoad(async);

        container
            .read(backfillStatsControllerProvider.notifier)
            .triggerReRequest();
        async.flushMicrotasks();

        final state = container.read(backfillStatsControllerProvider);
        expect(state.isReRequesting, isFalse);
        expect(state.error, contains('Re-request failed'));
      });
    });

    test('triggerReRequest does nothing if already re-requesting', () {
      fakeAsync((async) {
        when(
          () => mockSequenceService.getBackfillStats(),
        ).thenAnswer((_) async => testStats);
        when(() => mockBackfillService.processReRequest()).thenAnswer(
          (_) async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            return 5;
          },
        );

        createAndLoad(async);

        act(async, (c) => c.triggerReRequest());
        act(async, (c) => c.triggerReRequest());

        async
          ..elapse(const Duration(milliseconds: 100))
          ..flushMicrotasks();

        verify(() => mockBackfillService.processReRequest()).called(1);
      });
    });

    test('triggerReRequest does nothing if already processing backfill', () {
      fakeAsync((async) {
        when(
          () => mockSequenceService.getBackfillStats(),
        ).thenAnswer((_) async => testStats);
        when(() => mockBackfillService.processFullBackfill()).thenAnswer(
          (_) async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            return 5;
          },
        );

        createAndLoad(async);

        // Start full backfill, then try re-request while it's processing
        act(async, (c) => c.triggerFullBackfill());
        act(async, (c) => c.triggerReRequest());

        // Complete the backfill
        async
          ..elapse(const Duration(milliseconds: 100))
          ..flushMicrotasks();

        verifyNever(() => mockBackfillService.processReRequest());
      });
    });

    test('resetUnresolvable calls service and refreshes stats', () {
      fakeAsync((async) {
        when(
          () => mockSequenceService.getBackfillStats(),
        ).thenAnswer((_) async => testStats);
        when(
          () => mockSequenceService.resetUnresolvableEntries(),
        ).thenAnswer((_) async => 42);

        createAndLoad(async);
        clearInteractions(mockSequenceService);

        act(async, (c) => c.resetUnresolvable());

        verify(() => mockSequenceService.resetUnresolvableEntries()).called(1);
        verify(() => mockSequenceService.getBackfillStats()).called(1);

        final state = container.read(backfillStatsControllerProvider);
        expect(state.isResetting, isFalse);
        expect(state.lastResetCount, 42);
      });
    });

    test('resetUnresolvable sets isResetting during operation', () {
      fakeAsync((async) {
        when(
          () => mockSequenceService.getBackfillStats(),
        ).thenAnswer((_) async => testStats);
        when(() => mockSequenceService.resetUnresolvableEntries()).thenAnswer(
          (_) async {
            await Future<void>.delayed(const Duration(milliseconds: 200));
            return 10;
          },
        );

        createAndLoad(async);

        act(async, (c) => c.resetUnresolvable());

        var state = container.read(backfillStatsControllerProvider);
        expect(state.isResetting, isTrue);

        async
          ..elapse(const Duration(milliseconds: 200))
          ..flushMicrotasks();

        state = container.read(backfillStatsControllerProvider);
        expect(state.isResetting, isFalse);
      });
    });

    test('resetUnresolvable handles errors', () {
      fakeAsync((async) {
        when(
          () => mockSequenceService.getBackfillStats(),
        ).thenAnswer((_) async => testStats);
        when(
          () => mockSequenceService.resetUnresolvableEntries(),
        ).thenAnswer((_) async => throw Exception('Reset failed'));

        createAndLoad(async);

        act(async, (c) => c.resetUnresolvable());

        final state = container.read(backfillStatsControllerProvider);
        expect(state.isResetting, isFalse);
        expect(state.error, contains('Reset failed'));
      });
    });

    test('resetUnresolvable does nothing if already resetting', () {
      fakeAsync((async) {
        when(
          () => mockSequenceService.getBackfillStats(),
        ).thenAnswer((_) async => testStats);
        when(() => mockSequenceService.resetUnresolvableEntries()).thenAnswer(
          (_) async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            return 5;
          },
        );

        createAndLoad(async);

        act(async, (c) => c.resetUnresolvable());
        act(async, (c) => c.resetUnresolvable());

        async
          ..elapse(const Duration(milliseconds: 100))
          ..flushMicrotasks();

        verify(() => mockSequenceService.resetUnresolvableEntries()).called(1);
      });
    });

    test('resetUnresolvable does nothing if already processing backfill', () {
      fakeAsync((async) {
        when(
          () => mockSequenceService.getBackfillStats(),
        ).thenAnswer((_) async => testStats);
        when(() => mockBackfillService.processFullBackfill()).thenAnswer(
          (_) async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            return 5;
          },
        );

        createAndLoad(async);

        act(async, (c) => c.triggerFullBackfill());
        act(async, (c) => c.resetUnresolvable());

        async
          ..elapse(const Duration(milliseconds: 100))
          ..flushMicrotasks();

        verifyNever(() => mockSequenceService.resetUnresolvableEntries());
      });
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

    test('copyWith preserves isResetting when not overridden', () {
      const state = BackfillStatsState(isResetting: true);

      final copied = state.copyWith();

      expect(copied.isResetting, isTrue);
    });

    test('copyWith overrides isResetting', () {
      const state = BackfillStatsState();

      final copied = state.copyWith(isResetting: true);

      expect(copied.isResetting, isTrue);
    });

    test('copyWith overrides lastResetCount', () {
      const state = BackfillStatsState();

      final copied = state.copyWith(lastResetCount: 99);

      expect(copied.lastResetCount, 99);
    });

    test('copyWith clearLastReset removes lastResetCount', () {
      const state = BackfillStatsState(lastResetCount: 10);

      final copied = state.copyWith(clearLastReset: true);

      expect(copied.lastResetCount, isNull);
    });
  });
}
