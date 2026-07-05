import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/repository/consumption_repository.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/insights/logic/range_presets.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/state/insights_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/device_region.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../test_utils.dart';

void main() {
  final fixedNow = DateTime(2026, 6, 7, 16);
  final windowStartDay = epochDay(DateTime(2026));
  final window = (startDay: windowStartDay, endYear: 2026);

  late MockConsumptionRepository repository;
  late MockUpdateNotifications notifications;
  late StreamController<Set<String>> notificationController;

  setUp(() {
    repository = MockConsumptionRepository();
    notifications = MockUpdateNotifications();
    notificationController = StreamController<Set<String>>.broadcast();
    when(
      () => notifications.updateStream,
    ).thenAnswer((_) => notificationController.stream);
  });

  tearDown(() async {
    await notificationController.close();
  });

  ProviderContainer makeContainer({UpdateNotifications? withNotifications}) {
    final container = ProviderContainer(
      overrides: [
        consumptionRepositoryProvider.overrideWithValue(repository),
        maybeUpdateNotificationsProvider.overrideWith(
          (ref) => withNotifications,
        ),
        // Immediate refetches in tests; the 5s production throttle has its
        // own fakeAsync coverage in notification_stream_test.dart.
        consumptionRefetchThrottleProvider.overrideWithValue(null),
        // Deterministic Monday-start weeks regardless of host region.
        firstDayOfWeekIndexProvider.overrideWith((ref) => DateTime.monday % 7),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  void stubTotals(ConsumptionTotals totals) {
    when(
      () => repository.totalsForTask(any()),
    ).thenAnswer((_) async => totals);
  }

  void stubRows(List<ConsumptionMetricRow> rows) {
    when(
      () => repository.metricRowsInRange(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) async => rows);
  }

  /// Subscribes like a real UI would (the stream provider only fetches while
  /// listened to) and returns the first emitted totals.
  Future<ConsumptionTotals> listenTotals(
    ProviderContainer container,
    String taskId, {
    List<AsyncValue<ConsumptionTotals>>? into,
  }) {
    final sub = container.listen(
      taskConsumptionTotalsProvider(taskId),
      (_, next) => into?.add(next),
      fireImmediately: into != null,
    );
    addTearDown(sub.close);
    return container.read(taskConsumptionTotalsProvider(taskId).future);
  }

  /// Subscribes to the buckets provider under a fixed clock so the moving
  /// "end of tomorrow" is deterministic, and returns the first emission.
  Future<ConsumptionDayBuckets> listenBuckets(
    ProviderContainer container,
    InsightsWindow window, {
    List<AsyncValue<ConsumptionDayBuckets>>? into,
  }) {
    return withClock(Clock.fixed(fixedNow), () {
      final sub = container.listen(
        consumptionBucketsProvider(window),
        (_, next) => into?.add(next),
        fireImmediately: into != null,
      );
      addTearDown(sub.close);
      return container.read(consumptionBucketsProvider(window).future);
    });
  }

  void stubLedger(List<AiConsumptionEvent> events) {
    when(
      () => repository.newestEventsInRange(
        start: any(named: 'start'),
        end: any(named: 'end'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => events);
  }

  group('consumptionLedgerProvider', () {
    const range = InsightsRange(startDay: 20610, endDayExclusive: 20617);

    test('fetches the newest events for the day-aligned range with the '
        'ledger cap', () async {
      final events = [
        makeConsumptionEvent(id: 'e2', createdAt: DateTime(2026, 6, 6, 12)),
        makeConsumptionEvent(id: 'e1', createdAt: DateTime(2026, 6, 5, 9)),
      ];
      stubLedger(events);
      final container = makeContainer();

      final sub = container.listen(
        consumptionLedgerProvider(range),
        (_, _) {},
      );
      addTearDown(sub.close);
      final emitted = await container.read(
        consumptionLedgerProvider(range).future,
      );

      expect(emitted, events);
      final captured = verify(
        () => repository.newestEventsInRange(
          start: captureAny(named: 'start'),
          end: captureAny(named: 'end'),
          limit: captureAny(named: 'limit'),
        ),
      ).captured;
      expect(captured[0], dayStart(range.startDay));
      expect(captured[1], dayStart(range.endDayExclusive));
      expect(captured[2], kConsumptionLedgerLimit);
    });

    test(
      'refetches on aiConsumptionNotification and emits the new page',
      () async {
        stubLedger([
          makeConsumptionEvent(id: 'first', createdAt: DateTime(2026, 6, 5)),
        ]);
        final container = makeContainer(withNotifications: notifications);
        final emissions = <AsyncValue<List<AiConsumptionEvent>>>[];
        final sub = container.listen<AsyncValue<List<AiConsumptionEvent>>>(
          consumptionLedgerProvider(range),
          (_, next) => emissions.add(next),
          fireImmediately: true,
        );
        addTearDown(sub.close);
        final initial = await container.read(
          consumptionLedgerProvider(range).future,
        );
        expect(initial.single.id, 'first');

        stubLedger([
          makeConsumptionEvent(id: 'second', createdAt: DateTime(2026, 6, 6)),
          makeConsumptionEvent(id: 'first', createdAt: DateTime(2026, 6, 5)),
        ]);
        notificationController.add({aiConsumptionNotification});
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final latest = emissions.last.value!;
        expect(latest.map((e) => e.id).toList(), ['second', 'first']);
      },
    );
  });

  group('taskConsumptionTotalsProvider', () {
    test('emits the repository totals with exactly one fetch when no '
        'notifications service is registered', () async {
      final totals = makeConsumptionTotals(
        callCount: 3,
        impactCallCount: 2,
        totalTokens: 1500,
        credits: 0.5,
      );
      stubTotals(totals);
      final container = makeContainer();

      final emitted = await listenTotals(container, 'task-1');
      await pumpEventQueue();

      expect(emitted, totals);
      verify(() => repository.totalsForTask('task-1')).called(1);
    });

    test('an aiConsumptionNotification triggers a refetch with the new '
        'totals', () async {
      stubTotals(makeConsumptionTotals(callCount: 1, totalTokens: 100));
      final container = makeContainer(withNotifications: notifications);

      final states = <AsyncValue<ConsumptionTotals>>[];
      await listenTotals(container, 'task-1', into: states);

      // A new consumption event lands, then the matching notification fires.
      final updated = makeConsumptionTotals(callCount: 2, totalTokens: 300);
      stubTotals(updated);
      notificationController.add({aiConsumptionNotification});
      await pumpEventQueue();

      verify(() => repository.totalsForTask('task-1')).called(2);
      expect(states.last.value, updated);
    });

    test('ignores unrelated notification tokens', () async {
      stubTotals(makeConsumptionTotals(callCount: 1, totalTokens: 100));
      final container = makeContainer(withNotifications: notifications);

      await listenTotals(container, 'task-1');

      notificationController.add({taskNotification, 'SOMETHING_ELSE'});
      await pumpEventQueue();

      verify(() => repository.totalsForTask('task-1')).called(1);
    });
  });

  group('consumptionBucketsProvider', () {
    test('fetches window start to the moving end and bucketizes rows per '
        'day and category', () async {
      stubRows([
        makeMetricRow(createdAt: DateTime(2026, 6, 7, 9)),
        makeMetricRow(
          createdAt: DateTime(2026, 6, 7, 14),
          totalTokens: 200,
          credits: 0.5,
        ),
        makeMetricRow(
          createdAt: DateTime(2026, 6, 6, 9),
          categoryId: 'home',
          totalTokens: 40,
        ),
        makeMetricRow(
          createdAt: DateTime(2026, 6, 6, 10),
          categoryId: null,
          totalTokens: 7,
        ),
      ]);
      final container = makeContainer();

      final buckets = await listenBuckets(container, window);

      expect(buckets.windowStartDay, windowStartDay);
      final day7 = buckets.days[epochDay(DateTime(2026, 6, 7))]!;
      expect(
        day7['work'],
        const ConsumptionMetrics(callCount: 2, totalTokens: 300, credits: 0.75),
      );
      final day6 = buckets.days[epochDay(DateTime(2026, 6, 6))]!;
      expect(
        day6['home'],
        const ConsumptionMetrics(callCount: 1, totalTokens: 40, credits: 0.25),
      );
      expect(
        day6[null],
        const ConsumptionMetrics(callCount: 1, totalTokens: 7, credits: 0.25),
      );

      final captured = verify(
        () => repository.metricRowsInRange(
          start: captureAny(named: 'start'),
          end: captureAny(named: 'end'),
        ),
      ).captured;
      expect(captured[0], DateTime(2026)); // window start
      expect(captured[1], DateTime(2026, 6, 9)); // end of tomorrow
    });

    test(
      'caps a past-year window at January 1st of the following year',
      () async {
        stubRows([]);
        final container = makeContainer();
        final previousYearWindow = (
          startDay: epochDay(DateTime(2025)),
          endYear: 2025,
        );

        final buckets = await listenBuckets(container, previousYearWindow);

        expect(buckets.days, isEmpty);
        final captured = verify(
          () => repository.metricRowsInRange(
            start: captureAny(named: 'start'),
            end: captureAny(named: 'end'),
          ),
        ).captured;
        expect(captured[0], DateTime(2025));
        // A 2025 window never fetches 2026 data, no matter when "now" is.
        expect(captured[1], DateTime(2026));
      },
    );

    test('without notifications service emits exactly one fetch', () async {
      stubRows([makeMetricRow()]);
      final container = makeContainer();

      await listenBuckets(container, window);
      await pumpEventQueue();

      verify(
        () => repository.metricRowsInRange(
          start: any(named: 'start'),
          end: any(named: 'end'),
        ),
      ).called(1);
    });

    test('an aiConsumptionNotification triggers a refetch with the new '
        'rows', () async {
      stubRows([makeMetricRow()]);
      final container = makeContainer(withNotifications: notifications);

      final states = <AsyncValue<ConsumptionDayBuckets>>[];
      await listenBuckets(container, window, into: states);

      stubRows([
        makeMetricRow(),
        makeMetricRow(createdAt: DateTime(2026, 6, 7, 15)),
      ]);
      await withClock(Clock.fixed(fixedNow), () async {
        notificationController.add({aiConsumptionNotification});
        await pumpEventQueue();
      });

      verify(
        () => repository.metricRowsInRange(
          start: any(named: 'start'),
          end: any(named: 'end'),
        ),
      ).called(2);
      final day7 = states.last.value!.days[epochDay(DateTime(2026, 6, 7))]!;
      expect(day7['work']!.callCount, 2);
      expect(day7['work']!.totalTokens, 200);
    });
  });

  group('consumptionRangeControllerProvider', () {
    test('browses independently from the insights range controller', () {
      final container = makeContainer();
      withClock(Clock.fixed(fixedNow), () {
        final consumption = container.read(
          consumptionRangeControllerProvider.notifier,
        );
        final insights = container.read(
          insightsRangeControllerProvider.notifier,
        );
        expect(identical(consumption, insights), isFalse);

        DateTime consumptionStart() => dayStart(
          container.read(consumptionRangeControllerProvider).range.startDay,
        );
        DateTime insightsStart() => dayStart(
          container.read(insightsRangeControllerProvider).range.startDay,
        );

        // Both start at the current month-to-date default.
        expect(
          container.read(consumptionRangeControllerProvider).unit,
          InsightsPeriodUnit.month,
        );
        expect(consumptionStart(), DateTime(2026, 6));
        expect(insightsStart(), DateTime(2026, 6));

        consumption.step(-2);
        expect(consumptionStart(), DateTime(2026, 4));
        expect(
          insightsStart(),
          DateTime(2026, 6),
          reason: 'stepping the impact dashboard must not move the time one',
        );

        insights.step(-1);
        expect(insightsStart(), DateTime(2026, 5));
        expect(
          consumptionStart(),
          DateTime(2026, 4),
          reason: 'stepping the time dashboard must not move the impact one',
        );
      });
    });
  });

  group('provider defaults', () {
    test('repository default factory resolves the get_it registration and '
        'the throttle defaults to 5 seconds', () async {
      await setUpTestGetIt(
        additionalSetup: () {
          getIt.registerSingleton<ConsumptionRepository>(repository);
        },
      );
      addTearDown(tearDownTestGetIt);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(consumptionRepositoryProvider),
        same(repository),
      );
      expect(
        container.read(consumptionRefetchThrottleProvider),
        const Duration(seconds: 5),
      );
    });
  });
}
