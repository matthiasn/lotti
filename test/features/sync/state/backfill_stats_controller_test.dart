import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleState, WidgetsBinding, WidgetsFlutterBinding;
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
      burnedCount: 0,
    ),
  ]);

  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

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

    /// Creates the container, subscribes to the provider (keeping it alive for
    /// the duration of the test), and flushes microtasks so [_loadStats]
    /// completes synchronously under [fakeAsync].
    ///
    /// Using [ProviderContainer.listen] instead of [read] prevents Riverpod's
    /// auto-dispose scheduler from cancelling the provider's internal timer
    /// before the test can exercise it.
    void createAndLoad(FakeAsync async) {
      container = ProviderContainer()
        ..listen(backfillStatsControllerProvider, (_, _) {});
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
        final backfill = Completer<int>();
        when(() => mockBackfillService.processFullBackfill()).thenAnswer(
          (_) => backfill.future,
        );

        createAndLoad(async);

        container
            .read(backfillStatsControllerProvider.notifier)
            .triggerFullBackfill();
        async.flushMicrotasks();

        var state = container.read(backfillStatsControllerProvider);
        expect(state.isProcessing, isTrue);

        backfill.complete(5);
        async.flushMicrotasks();

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
        final backfill = Completer<int>();
        when(() => mockBackfillService.processFullBackfill()).thenAnswer(
          (_) => backfill.future,
        );

        createAndLoad(async);

        // Start first trigger, then try a second while first is processing
        act(async, (c) => c.triggerFullBackfill());
        act(async, (c) => c.triggerFullBackfill());

        // Complete the first one
        backfill.complete(5);
        async.flushMicrotasks();

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
        final reRequest = Completer<int>();
        when(() => mockBackfillService.processReRequest()).thenAnswer(
          (_) => reRequest.future,
        );

        createAndLoad(async);

        container
            .read(backfillStatsControllerProvider.notifier)
            .triggerReRequest();
        async.flushMicrotasks();

        var state = container.read(backfillStatsControllerProvider);
        expect(state.isReRequesting, isTrue);

        reRequest.complete(8);
        async.flushMicrotasks();

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
        final reRequest = Completer<int>();
        when(() => mockBackfillService.processReRequest()).thenAnswer(
          (_) => reRequest.future,
        );

        createAndLoad(async);

        act(async, (c) => c.triggerReRequest());
        act(async, (c) => c.triggerReRequest());

        reRequest.complete(5);
        async.flushMicrotasks();

        verify(() => mockBackfillService.processReRequest()).called(1);
      });
    });

    test('triggerReRequest does nothing if already processing backfill', () {
      fakeAsync((async) {
        when(
          () => mockSequenceService.getBackfillStats(),
        ).thenAnswer((_) async => testStats);
        final backfill = Completer<int>();
        when(() => mockBackfillService.processFullBackfill()).thenAnswer(
          (_) => backfill.future,
        );

        createAndLoad(async);

        // Start full backfill, then try re-request while it's processing
        act(async, (c) => c.triggerFullBackfill());
        act(async, (c) => c.triggerReRequest());

        // Complete the backfill
        backfill.complete(5);
        async.flushMicrotasks();

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
        final reset = Completer<int>();
        when(() => mockSequenceService.resetUnresolvableEntries()).thenAnswer(
          (_) => reset.future,
        );

        createAndLoad(async);

        act(async, (c) => c.resetUnresolvable());

        var state = container.read(backfillStatsControllerProvider);
        expect(state.isResetting, isTrue);

        reset.complete(10);
        async.flushMicrotasks();

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
        final reset = Completer<int>();
        when(() => mockSequenceService.resetUnresolvableEntries()).thenAnswer(
          (_) => reset.future,
        );

        createAndLoad(async);

        act(async, (c) => c.resetUnresolvable());
        act(async, (c) => c.resetUnresolvable());

        reset.complete(5);
        async.flushMicrotasks();

        verify(() => mockSequenceService.resetUnresolvableEntries()).called(1);
      });
    });

    test('resetUnresolvable does nothing if already processing backfill', () {
      fakeAsync((async) {
        when(
          () => mockSequenceService.getBackfillStats(),
        ).thenAnswer((_) async => testStats);
        final backfill = Completer<int>();
        when(() => mockBackfillService.processFullBackfill()).thenAnswer(
          (_) => backfill.future,
        );

        createAndLoad(async);

        act(async, (c) => c.triggerFullBackfill());
        act(async, (c) => c.resetUnresolvable());

        backfill.complete(5);
        async.flushMicrotasks();

        verifyNever(() => mockSequenceService.resetUnresolvableEntries());
      });
    });

    test(
      'retireStuckNow calls retireAgedOutRequestedEntries with zero amnesty '
      'window and refreshes stats — the manual diagnostic path that bypasses '
      'the 7-day default so a user can unblock the watermark immediately',
      () {
        fakeAsync((async) {
          when(
            () => mockSequenceService.getBackfillStats(),
          ).thenAnswer((_) async => testStats);
          when(
            () => mockSequenceService.retireAgedOutRequestedEntries(
              amnestyWindow: any(named: 'amnestyWindow'),
            ),
          ).thenAnswer((_) async => 7);

          createAndLoad(async);
          clearInteractions(mockSequenceService);

          act(async, (c) => c.retireStuckNow());

          verify(
            () => mockSequenceService.retireAgedOutRequestedEntries(
              amnestyWindow: Duration.zero,
            ),
          ).called(1);
          verify(() => mockSequenceService.getBackfillStats()).called(1);

          final state = container.read(backfillStatsControllerProvider);
          expect(state.isRetiringStuck, isFalse);
          expect(state.lastRetiredStuckCount, 7);
        });
      },
    );

    test('retireStuckNow sets isRetiringStuck during operation', () {
      fakeAsync((async) {
        when(
          () => mockSequenceService.getBackfillStats(),
        ).thenAnswer((_) async => testStats);
        final retire = Completer<int>();
        when(
          () => mockSequenceService.retireAgedOutRequestedEntries(
            amnestyWindow: any(named: 'amnestyWindow'),
          ),
        ).thenAnswer((_) => retire.future);

        createAndLoad(async);

        container
            .read(backfillStatsControllerProvider.notifier)
            .retireStuckNow();
        async.flushMicrotasks();

        var state = container.read(backfillStatsControllerProvider);
        expect(state.isRetiringStuck, isTrue);

        retire.complete(3);
        async.flushMicrotasks();

        state = container.read(backfillStatsControllerProvider);
        expect(state.isRetiringStuck, isFalse);
      });
    });

    test('retireStuckNow surfaces service errors', () {
      fakeAsync((async) {
        when(
          () => mockSequenceService.getBackfillStats(),
        ).thenAnswer((_) async => testStats);
        when(
          () => mockSequenceService.retireAgedOutRequestedEntries(
            amnestyWindow: any(named: 'amnestyWindow'),
          ),
        ).thenAnswer((_) async => throw Exception('retire blew up'));

        createAndLoad(async);

        act(async, (c) => c.retireStuckNow());

        final state = container.read(backfillStatsControllerProvider);
        expect(state.isRetiringStuck, isFalse);
        expect(state.error, contains('retire blew up'));
      });
    });

    test(
      'resetAllUnresolvable calls resetAllUnresolvableEntries and refreshes '
      'stats — the peer-reask path that covers unresolvable rows with no '
      'known entryId, which resetUnresolvable (the narrower variant) skips',
      () {
        fakeAsync((async) {
          when(
            () => mockSequenceService.getBackfillStats(),
          ).thenAnswer((_) async => testStats);
          when(
            () => mockSequenceService.resetAllUnresolvableEntries(),
          ).thenAnswer((_) async => 144087);

          createAndLoad(async);
          clearInteractions(mockSequenceService);

          act(async, (c) => c.resetAllUnresolvable());

          verify(
            () => mockSequenceService.resetAllUnresolvableEntries(),
          ).called(1);
          verify(() => mockSequenceService.getBackfillStats()).called(1);

          final state = container.read(backfillStatsControllerProvider);
          expect(state.isResettingAllUnresolvable, isFalse);
          expect(state.lastResetAllUnresolvableCount, 144087);
        });
      },
    );

    test(
      'resetAllUnresolvable surfaces service errors',
      () {
        fakeAsync((async) {
          when(
            () => mockSequenceService.getBackfillStats(),
          ).thenAnswer((_) async => testStats);
          when(
            () => mockSequenceService.resetAllUnresolvableEntries(),
          ).thenAnswer((_) async => throw Exception('reset blew up'));

          createAndLoad(async);

          act(async, (c) => c.resetAllUnresolvable());

          final state = container.read(backfillStatsControllerProvider);
          expect(state.isResettingAllUnresolvable, isFalse);
          expect(state.error, contains('reset blew up'));
        });
      },
    );

    test(
      'retireStuckNow is mutually exclusive with the other manual operations '
      "so concurrent triggers don't double-fire the retire",
      () {
        fakeAsync((async) {
          when(
            () => mockSequenceService.getBackfillStats(),
          ).thenAnswer((_) async => testStats);
          final backfill = Completer<int>();
          when(() => mockBackfillService.processFullBackfill()).thenAnswer(
            (_) => backfill.future,
          );
          when(
            () => mockSequenceService.retireAgedOutRequestedEntries(
              amnestyWindow: any(named: 'amnestyWindow'),
            ),
          ).thenAnswer((_) async => 1);

          createAndLoad(async);

          // Start full backfill, then try retireStuckNow while it runs.
          act(async, (c) => c.triggerFullBackfill());
          act(async, (c) => c.retireStuckNow());

          backfill.complete(2);
          async.flushMicrotasks();

          verifyNever(
            () => mockSequenceService.retireAgedOutRequestedEntries(
              amnestyWindow: any(named: 'amnestyWindow'),
            ),
          );
        });
      },
    );

    group('auto-refresh timer dispose', () {
      test(
        'provider dispose cancels the timer so no ticks fire after the '
        'Backfill Settings page is closed — the @riverpod auto-dispose '
        'is the backstop for "zero cost when page is closed"',
        () {
          fakeAsync((async) {
            when(
              () => mockSequenceService.getBackfillStats(),
            ).thenAnswer((_) async => testStats);

            createAndLoad(async);
            clearInteractions(mockSequenceService);

            container.dispose();

            // Recreate for the tearDown hook; the explicit dispose
            // above is the assertion subject.
            container = ProviderContainer();

            async.elapse(const Duration(seconds: 30));
            verifyNever(() => mockSequenceService.getBackfillStats());
          });
        },
      );
    });

    group('auto-refresh timer silent refresh', () {
      test(
        'timer tick calls _loadStatsSilent which updates stats without '
        'touching isLoading or error — the silent background path',
        () {
          fakeAsync((async) {
            final updatedStats = BackfillStats.fromHostStats([
              const BackfillHostStats(
                receivedCount: 200,
                missingCount: 3,
                requestedCount: 1,
                backfilledCount: 20,
                deletedCount: 2,
                unresolvableCount: 0,
                burnedCount: 0,
              ),
            ]);

            // Track total calls so we can assert the timer fired without
            // relying on clearInteractions.
            var callCount = 0;
            when(() => mockSequenceService.getBackfillStats()).thenAnswer((
              _,
            ) async {
              callCount++;
              // First call is from build/_loadStats; subsequent calls are from
              // the timer-driven _loadStatsSilent.
              return callCount == 1 ? testStats : updatedStats;
            });

            createAndLoad(async);
            expect(callCount, 1); // sanity: build loaded stats once

            // Advance one auto-refresh interval; elapse() already flushes
            // microtasks internally after each timer fire.
            async.elapse(const Duration(seconds: 30));

            // callCount == 2 means the timer fired and called getBackfillStats.
            expect(callCount, 2);

            final state = container.read(backfillStatsControllerProvider);
            // Silent refresh must update stats to the newer value.
            expect(state.stats?.totalReceived, 200);
            // isLoading must not have been toggled during silent refresh.
            expect(state.isLoading, isFalse);
            // No error should have been set by silent refresh.
            expect(state.error, isNull);
          });
        },
      );

      test(
        'timer tick skips _loadStatsSilent when isProcessing is true — '
        'manual operations own the refresh cycle while they run',
        () {
          fakeAsync((async) {
            when(
              () => mockSequenceService.getBackfillStats(),
            ).thenAnswer((_) async => testStats);
            final backfill = Completer<int>();
            when(() => mockBackfillService.processFullBackfill()).thenAnswer(
              (_) => backfill.future,
            );

            createAndLoad(async);
            clearInteractions(mockSequenceService);

            // Start a manual action so isProcessing = true.
            act(async, (c) => c.triggerFullBackfill());

            // Timer fires while the manual action is still in-flight.
            async
              ..elapse(const Duration(seconds: 30))
              ..flushMicrotasks();

            // Silent refresh must NOT have fired.
            verifyNever(() => mockSequenceService.getBackfillStats());

            // Complete the manual action to stop the Completer leak.
            backfill.complete(0);
            async.flushMicrotasks();
          });
        },
      );

      test(
        'timer tick skips _loadStatsSilent when isReRequesting is true',
        () {
          fakeAsync((async) {
            when(
              () => mockSequenceService.getBackfillStats(),
            ).thenAnswer((_) async => testStats);
            final reRequest = Completer<int>();
            when(() => mockBackfillService.processReRequest()).thenAnswer(
              (_) => reRequest.future,
            );

            createAndLoad(async);
            clearInteractions(mockSequenceService);

            act(async, (c) => c.triggerReRequest());

            async
              ..elapse(const Duration(seconds: 30))
              ..flushMicrotasks();

            verifyNever(() => mockSequenceService.getBackfillStats());

            reRequest.complete(0);
            async.flushMicrotasks();
          });
        },
      );

      test(
        'timer tick skips _loadStatsSilent when isResetting is true',
        () {
          fakeAsync((async) {
            when(
              () => mockSequenceService.getBackfillStats(),
            ).thenAnswer((_) async => testStats);
            final reset = Completer<int>();
            when(
              () => mockSequenceService.resetUnresolvableEntries(),
            ).thenAnswer(
              (_) => reset.future,
            );

            createAndLoad(async);
            clearInteractions(mockSequenceService);

            act(async, (c) => c.resetUnresolvable());

            async
              ..elapse(const Duration(seconds: 30))
              ..flushMicrotasks();

            verifyNever(() => mockSequenceService.getBackfillStats());

            reset.complete(0);
            async.flushMicrotasks();
          });
        },
      );

      test(
        'timer tick skips _loadStatsSilent when isRetiringStuck is true',
        () {
          fakeAsync((async) {
            when(
              () => mockSequenceService.getBackfillStats(),
            ).thenAnswer((_) async => testStats);
            final retire = Completer<int>();
            when(
              () => mockSequenceService.retireAgedOutRequestedEntries(
                amnestyWindow: any(named: 'amnestyWindow'),
              ),
            ).thenAnswer((_) => retire.future);

            createAndLoad(async);
            clearInteractions(mockSequenceService);

            act(async, (c) => c.retireStuckNow());

            async
              ..elapse(const Duration(seconds: 30))
              ..flushMicrotasks();

            verifyNever(() => mockSequenceService.getBackfillStats());

            retire.complete(0);
            async.flushMicrotasks();
          });
        },
      );

      test(
        'timer tick skips _loadStatsSilent when isResettingAllUnresolvable is true',
        () {
          fakeAsync((async) {
            when(
              () => mockSequenceService.getBackfillStats(),
            ).thenAnswer((_) async => testStats);
            final resetAll = Completer<int>();
            when(
              () => mockSequenceService.resetAllUnresolvableEntries(),
            ).thenAnswer(
              (_) => resetAll.future,
            );

            createAndLoad(async);
            clearInteractions(mockSequenceService);

            act(async, (c) => c.resetAllUnresolvable());

            async
              ..elapse(const Duration(seconds: 30))
              ..flushMicrotasks();

            verifyNever(() => mockSequenceService.getBackfillStats());

            resetAll.complete(0);
            async.flushMicrotasks();
          });
        },
      );

      test(
        '_loadStatsSilent swallows DB errors silently — an existing error '
        'banner from a previous manual action is preserved rather than '
        'overwritten with a transient background failure',
        () {
          fakeAsync((async) {
            var callCount = 0;
            when(() => mockSequenceService.getBackfillStats()).thenAnswer((
              _,
            ) async {
              callCount++;
              if (callCount == 1) return testStats;
              throw Exception('transient DB error');
            });

            createAndLoad(async);

            // Initial load succeeds; no error set.
            expect(
              container.read(backfillStatsControllerProvider).error,
              isNull,
            );

            // Timer fires and _loadStatsSilent throws; elapse flushes
            // microtasks internally.
            async.elapse(const Duration(seconds: 30));

            // The timer called getBackfillStats (callCount 2 = thrown).
            expect(callCount, 2);

            final state = container.read(backfillStatsControllerProvider);
            // Silent errors must not surface in state.error.
            expect(state.error, isNull);
            // stats remain as they were before the failed silent refresh.
            expect(state.stats, testStats);
          });
        },
      );

      test(
        '_silentRefreshInFlight guard prevents overlapping timer ticks — '
        'a second tick while the first query is still running is a no-op',
        () {
          fakeAsync((async) {
            // Stall the second getBackfillStats call so the slow aggregation
            // never completes before the second timer tick.
            final slowQuery = Completer<BackfillStats>();
            var callCount = 0;
            when(() => mockSequenceService.getBackfillStats()).thenAnswer((
              _,
            ) async {
              callCount++;
              if (callCount == 1) return testStats;
              // Second call returns a stalled future, leaving
              // _silentRefreshInFlight = true when the next tick fires.
              return slowQuery.future;
            });

            createAndLoad(async);
            expect(callCount, 1); // sanity

            // First tick starts a slow silent refresh.
            async.elapse(const Duration(seconds: 30));
            expect(callCount, 2); // first silent call started

            // Second tick fires while the first query is still in-flight;
            // _silentRefreshInFlight must gate it out.
            async.elapse(const Duration(seconds: 30));
            expect(callCount, 2); // no additional call

            // Clean up the stalled future.
            slowQuery.complete(testStats);
            async.flushMicrotasks();
          });
        },
      );

      test(
        '_silentRefreshInFlight is reset to false in finally block even when '
        'the query throws — subsequent timer ticks can fire again',
        () {
          fakeAsync((async) {
            var callCount = 0;
            when(() => mockSequenceService.getBackfillStats()).thenAnswer((
              _,
            ) async {
              callCount++;
              if (callCount == 1) return testStats;
              throw Exception('db error');
            });

            createAndLoad(async);
            expect(callCount, 1); // sanity

            // First tick: _loadStatsSilent throws, finally block resets flag.
            async.elapse(const Duration(seconds: 30));
            expect(callCount, 2);

            // Second tick: flag was reset, so the second call fires.
            async.elapse(const Duration(seconds: 30));
            expect(callCount, 3);
          });
        },
      );
    });

    group('app visibility lifecycle', () {
      late WidgetsBinding binding;

      setUp(() {
        // Establish a deterministic `resumed` baseline so the
        // AppLifecycleListener created inside the controller's build()
        // starts from a known state and the resumed -> inactive -> hidden
        // -> inactive transitions below are all valid.
        binding = WidgetsFlutterBinding.ensureInitialized()
          ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      });

      tearDown(() {
        // Restore a resumed state for any subsequent tests.
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      });

      test(
        'onHide pauses the auto-refresh timer so a backgrounded app stops '
        'running the stats aggregation even while the provider stays mounted',
        () {
          fakeAsync((async) {
            var callCount = 0;
            when(() => mockSequenceService.getBackfillStats()).thenAnswer((
              _,
            ) async {
              callCount++;
              return testStats;
            });

            createAndLoad(async);
            expect(callCount, 1); // build/_loadStats ran once

            // Drive the app to the background: resumed -> inactive -> hidden
            // fires the listener's onHide, which cancels the timer.
            binding
              ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
              ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);

            // A full auto-refresh interval passes while backgrounded.
            async.elapse(const Duration(seconds: 30));

            // The silent refresh must NOT have fired — the timer is paused.
            expect(callCount, 1);
          });
        },
      );

      test(
        'onShow re-arms the auto-refresh timer when the app returns to the '
        'foreground so live stats resume ticking',
        () {
          fakeAsync((async) {
            var callCount = 0;
            when(() => mockSequenceService.getBackfillStats()).thenAnswer((
              _,
            ) async {
              callCount++;
              return testStats;
            });

            createAndLoad(async);
            expect(callCount, 1);

            // Background the app (onHide cancels the timer).
            binding
              ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
              ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);

            async.elapse(const Duration(seconds: 30));
            expect(callCount, 1); // confirmed paused

            // Foreground the app again: hidden -> inactive fires onShow,
            // which sets _appVisible = true and restarts the timer.
            binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);

            // The re-armed timer fires after one more interval.
            async.elapse(const Duration(seconds: 30));
            expect(callCount, 2);
          });
        },
      );

      test(
        'repeated hide -> show -> hide leaves the timer cancelled so a '
        'backgrounded app never silently refreshes across multiple intervals',
        () {
          // NOTE on the in-callback `if (!_appVisible) return;` guard:
          // `onHide` sets `_appVisible = false` AND synchronously cancels the
          // periodic timer (and `onShow` re-arms it only after flipping
          // `_appVisible` back to true). Because `Timer.cancel()` prevents a
          // not-yet-fired periodic tick from running, there is no execution
          // window in which the periodic callback fires while
          // `_appVisible == false` — the in-callback guard is unreachable
          // defensive code. This test therefore asserts the actually-reachable
          // contract: after a hide/show/hide churn the timer ends cancelled and
          // no silent refresh fires, no matter how many intervals elapse. A
          // regression that dropped only the in-callback guard would (correctly)
          // still pass here; a regression that dropped the `onHide` cancel would
          // fail.
          fakeAsync((async) {
            var callCount = 0;
            when(() => mockSequenceService.getBackfillStats()).thenAnswer((
              _,
            ) async {
              callCount++;
              return testStats;
            });

            createAndLoad(async);
            expect(callCount, 1);

            // Hide -> show -> hide. The final transition is `onHide`, which
            // cancels the timer; `onShow` in the middle re-armed it, so this
            // also proves the final hide re-cancels a freshly-armed timer.
            binding
              ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
              ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
              ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
              ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);

            // Many intervals pass while backgrounded; the cancelled timer must
            // never fire.
            async.elapse(const Duration(seconds: 120));
            expect(callCount, 1);
          });
        },
      );

      test(
        'a periodic tick that fires while the app is visible runs the silent '
        'refresh, confirming the timer/guard wiring is exercised end to end',
        () {
          // Positive counterpart to the cancel test above: with the app
          // visible (`_appVisible == true`) and the timer armed, an elapsed
          // interval drives the periodic callback past its guards into
          // `_loadStatsSilent`, incrementing the call count. This is the
          // reachable path the in-callback guard *would* protect if a tick
          // could ever fire while hidden.
          fakeAsync((async) {
            var callCount = 0;
            when(() => mockSequenceService.getBackfillStats()).thenAnswer((
              _,
            ) async {
              callCount++;
              return testStats;
            });

            createAndLoad(async);
            expect(callCount, 1);

            // App stays in the foreground; the armed timer fires each interval.
            async
              ..elapse(const Duration(seconds: 30))
              ..flushMicrotasks();
            expect(callCount, 2);

            async
              ..elapse(const Duration(seconds: 30))
              ..flushMicrotasks();
            expect(callCount, 3);
          });
        },
      );
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
