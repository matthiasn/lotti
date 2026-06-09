import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/insights/logic/period_navigation.dart';
import 'package:lotti/features/insights/logic/range_presets.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/repository/insights_repository.dart';
import 'package:lotti/features/insights/state/insights_providers.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/device_region.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  final fixedNow = DateTime(2026, 6, 7, 16);
  final windowStartDay = epochDay(DateTime(2026));
  final window = (startDay: windowStartDay, endYear: 2026);

  late MockInsightsRepository repository;
  late MockUpdateNotifications notifications;
  late StreamController<Set<String>> notificationController;

  setUp(() {
    repository = MockInsightsRepository();
    notifications = MockUpdateNotifications();
    notificationController = StreamController<Set<String>>.broadcast();
    when(
      () => notifications.updateStream,
    ).thenAnswer((_) => notificationController.stream);
  });

  tearDown(() async {
    await notificationController.close();
  });

  ProviderContainer makeContainer({
    UpdateNotifications? withNotifications,
    Override? firstDayOfWeek,
  }) {
    final container = ProviderContainer(
      overrides: [
        insightsRepositoryProvider.overrideWithValue(repository),
        maybeUpdateNotificationsProvider.overrideWith(
          (ref) => withNotifications,
        ),
        // Immediate refetches in tests; the 5s production throttle has its
        // own fakeAsync coverage in notification_stream_test.dart.
        insightsRefetchThrottleProvider.overrideWithValue(null),
        // Default: deterministic Monday-start weeks regardless of host
        // region. Synchronous so AsyncData lands at build time; an async
        // override resolves on a microtask and leaves Riverpod's refresh
        // timer pending past teardown. Tests that exercise other regions or
        // the async resolve path pass their own [firstDayOfWeek] override.
        firstDayOfWeek ??
            firstDayOfWeekIndexProvider.overrideWith(
              (ref) => DateTime.monday % 7,
            ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  void stubRows(List<InsightsTimeRow> rows) {
    when(
      () => repository.fetchTimeRows(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) async => rows);
  }

  InsightsTimeRow row({required int hour, String? categoryId = 'work'}) =>
      InsightsTimeRow(
        dateFrom: DateTime(2026, 6, 7, hour),
        dateTo: DateTime(2026, 6, 7, hour + 1),
        categoryId: categoryId,
      );

  /// Subscribes like a real UI would (the stream provider only fetches
  /// while listened to) and returns the first emitted buckets.
  Future<InsightsDayBuckets> listenAndAwait(
    ProviderContainer container,
    InsightsWindow window, {
    List<AsyncValue<InsightsDayBuckets>>? into,
  }) {
    // The listen() eagerly builds the StreamProvider, which synchronously runs
    // fetch()'s prefix — including the `clock.now()` that sets the moving end.
    // Wrap the whole thing (not just the .future read) so that read happens
    // under the fixed clock; otherwise the moving end tracks real wall time
    // and the captured end drifts a day once "today" passes fixedNow.
    return withClock(Clock.fixed(fixedNow), () {
      final sub = container.listen(
        insightsBucketsProvider(window),
        (_, next) => into?.add(next),
        fireImmediately: into != null,
      );
      addTearDown(sub.close);
      return container.read(insightsBucketsProvider(window).future);
    });
  }

  group('insightsBucketsProvider', () {
    test('fetches the window and bucketizes rows', () async {
      stubRows([row(hour: 9)]);
      final container = makeContainer();

      final buckets = await listenAndAwait(container, window);

      expect(buckets.windowStartDay, windowStartDay);
      expect(
        buckets.days[epochDay(DateTime(2026, 6, 7))]!['work']!.seconds,
        3600,
      );
      final captured = verify(
        () => repository.fetchTimeRows(
          start: captureAny(named: 'start'),
          end: captureAny(named: 'end'),
        ),
      ).captured;
      expect(captured[0], DateTime(2026)); // window start
      expect(captured[1], DateTime(2026, 6, 9)); // end of tomorrow
    });

    test('without notifications service emits exactly one fetch', () async {
      stubRows([row(hour: 9)]);
      final container = makeContainer();

      await listenAndAwait(container, window);

      verify(
        () => repository.fetchTimeRows(
          start: any(named: 'start'),
          end: any(named: 'end'),
        ),
      ).called(1);
    });

    test('refetches when a subscribed notification token arrives', () async {
      stubRows([row(hour: 9)]);
      final container = makeContainer(withNotifications: notifications);

      final states = <AsyncValue<InsightsDayBuckets>>[];
      await listenAndAwait(container, window, into: states);

      // New data arrives, then a matching notification fires.
      stubRows([row(hour: 9), row(hour: 14)]);
      await withClock(Clock.fixed(fixedNow), () async {
        notificationController.add({textEntryNotification});
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
      });

      verify(
        () => repository.fetchTimeRows(
          start: any(named: 'start'),
          end: any(named: 'end'),
        ),
      ).called(2);
      final latest = states.last.value!;
      final day = latest.days[epochDay(DateTime(2026, 6, 7))]!;
      expect(day['work']!.seconds, 2 * 3600);
    });

    test(
      'linking a time entry to a task refetches so attribution updates',
      () async {
        stubRows([row(hour: 9, categoryId: null)]);
        final container = makeContainer(withNotifications: notifications);

        final states = <AsyncValue<InsightsDayBuckets>>[];
        await listenAndAwait(container, window, into: states);

        // The link lands and the entry is now attributed to the task's
        // category — standalone link creation fires only linkNotification.
        stubRows([row(hour: 9, categoryId: 'task-category')]);
        await withClock(Clock.fixed(fixedNow), () async {
          notificationController.add({linkNotification});
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
        });

        verify(
          () => repository.fetchTimeRows(
            start: any(named: 'start'),
            end: any(named: 'end'),
          ),
        ).called(2);
        final day = states.last.value!.days[epochDay(DateTime(2026, 6, 7))]!;
        expect(day['task-category']!.seconds, 3600);
        expect(day.containsKey(null), isFalse);
      },
    );

    test('ignores unrelated notification tokens', () async {
      stubRows([row(hour: 9)]);
      final container = makeContainer(withNotifications: notifications);

      await listenAndAwait(container, window);

      notificationController.add({audioNotification, 'SOMETHING_ELSE'});
      await Future<void>.delayed(Duration.zero);

      verify(
        () => repository.fetchTimeRows(
          start: any(named: 'start'),
          end: any(named: 'end'),
        ),
      ).called(1);
    });

    test(
      'unchanged refetch emits an equal value (no-flash invariant)',
      () async {
        stubRows([row(hour: 9)]);
        final container = makeContainer(withNotifications: notifications);

        final states = <AsyncValue<InsightsDayBuckets>>[];
        await listenAndAwait(container, window, into: states);

        await withClock(Clock.fixed(fixedNow), () async {
          notificationController.add({taskNotification});
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
        });

        // The refetch ran...
        verify(
          () => repository.fetchTimeRows(
            start: any(named: 'start'),
            end: any(named: 'end'),
          ),
        ).called(2);
        // ...but deep value equality made the new state equal the old, so
        // Riverpod never re-notified listeners: zero rebuilds, zero flash.
        final dataStates = states.where((s) => s.hasValue).toList();
        expect(dataStates, hasLength(1));
      },
    );

    test('different windows are independent provider instances', () async {
      stubRows([row(hour: 9)]);
      final container = makeContainer();
      final previousYearWindow = (
        startDay: epochDay(DateTime(2025)),
        endYear: 2025,
      );

      await listenAndAwait(container, window);
      await listenAndAwait(container, previousYearWindow);

      final captured = verify(
        () => repository.fetchTimeRows(
          start: captureAny(named: 'start'),
          end: captureAny(named: 'end'),
        ),
      ).captured;
      expect(captured[0], DateTime(2026)); // current-year start
      expect(captured[1], DateTime(2026, 6, 9)); // moving end of tomorrow
      expect(captured[2], DateTime(2025)); // past-year start
      // Past-year windows are capped at Jan 1 of the following year —
      // a small 2025 range never fetches 2026 data.
      expect(captured[3], DateTime(2026));
    });
  });

  group('InsightsRangeController', () {
    test('defaults to the current Monday-start week', () {
      final container = makeContainer();
      final selection = withClock(
        Clock.fixed(fixedNow),
        () => container.read(insightsRangeControllerProvider),
      );
      expect(selection.unit, InsightsPeriodUnit.week);
      expect(selection.range.dayCount, 7);
      // fixedNow is Sun 2026-06-07; its week is Mon Jun 1 – Sun Jun 7.
      expect(dayStart(selection.range.startDay), DateTime(2026, 6));
      expect(dayStart(selection.range.endDayExclusive), DateTime(2026, 6, 8));
    });

    test('selectUnit re-derives the period for the new granularity', () {
      final container = makeContainer();
      withClock(Clock.fixed(fixedNow), () {
        container
            .read(insightsRangeControllerProvider.notifier)
            .selectUnit(InsightsPeriodUnit.month);
      });
      final selection = container.read(insightsRangeControllerProvider);
      expect(selection.unit, InsightsPeriodUnit.month);
      expect(dayStart(selection.range.startDay), DateTime(2026, 6));
      expect(dayStart(selection.range.endDayExclusive), DateTime(2026, 7));
    });

    test('step browses to the previous and forward periods', () {
      final container = makeContainer();
      final notifier = withClock(
        Clock.fixed(fixedNow),
        () => container.read(insightsRangeControllerProvider.notifier),
      );

      // ignore: cascade_invocations
      notifier.step(-1);
      expect(
        dayStart(
          container.read(insightsRangeControllerProvider).range.startDay,
        ),
        DateTime(2026, 5, 25), // previous week's Monday
      );

      notifier.step(2);
      expect(
        dayStart(
          container.read(insightsRangeControllerProvider).range.startDay,
        ),
        DateTime(2026, 6, 8), // two weeks forward
      );
    });

    test('jumpTo snaps to the current granularity period of a far date', () {
      final container = makeContainer();
      withClock(Clock.fixed(fixedNow), () {
        container
            .read(insightsRangeControllerProvider.notifier)
            .jumpTo(DateTime(2025, 11, 19)); // a Wednesday
      });
      final selection = container.read(insightsRangeControllerProvider);
      // Still a week (granularity unchanged); snapped to that day's Monday.
      expect(selection.unit, InsightsPeriodUnit.week);
      expect(dayStart(selection.range.startDay), DateTime(2025, 11, 17));
    });

    test('toggleCompare flips and survives navigation', () {
      final container = makeContainer();
      final notifier = withClock(
        Clock.fixed(fixedNow),
        () => container.read(insightsRangeControllerProvider.notifier),
      );
      bool compareOn() =>
          container.read(insightsRangeControllerProvider).compareEnabled;

      expect(compareOn(), isFalse);
      notifier.toggleCompare();
      expect(compareOn(), isTrue);

      // Stepping and switching granularity keep comparison enabled.
      notifier
        ..step(-1)
        ..selectUnit(InsightsPeriodUnit.month)
        ..jumpTo(DateTime(2025));
      expect(compareOn(), isTrue);

      notifier.toggleCompare();
      expect(compareOn(), isFalse);
    });

    test('previousComparisonRange is null until compare is enabled', () {
      final container = makeContainer();
      final notifier = withClock(
        Clock.fixed(fixedNow),
        () => container.read(insightsRangeControllerProvider.notifier),
      );
      expect(notifier.previousComparisonRange, isNull);
      notifier.toggleCompare();
      expect(notifier.previousComparisonRange, isNotNull);
    });

    test(
      'previousComparisonRange aligns to the region first weekday (Sunday)',
      () {
        // Regression: with a Sunday-first region the comparison week must be
        // the immediately preceding Sunday→Saturday week, not a Monday-default
        // week shifted ~13 days back.
        final container = makeContainer(
          firstDayOfWeek: firstDayOfWeekIndexProvider.overrideWith((ref) => 0),
        );
        final notifier = withClock(
          Clock.fixed(fixedNow),
          () => container.read(insightsRangeControllerProvider.notifier),
        );
        // fixedNow is Sun 2026-06-07 → current week Sun Jun 7 – Sat Jun 13.
        final current = container.read(insightsRangeControllerProvider).range;
        expect(dayStart(current.startDay), DateTime(2026, 6, 7));
        expect(dayStart(current.endDayExclusive), DateTime(2026, 6, 14));

        notifier.toggleCompare();
        final previous = notifier.previousComparisonRange!;
        expect(dayStart(previous.startDay), DateTime(2026, 5, 31));
        expect(dayStart(previous.endDayExclusive), DateTime(2026, 6, 7));
      },
    );

    test(
      're-anchors the untouched default week when the region resolves',
      () async {
        final completer = Completer<int>();
        final container = makeContainer(
          firstDayOfWeek: firstDayOfWeekIndexProvider.overrideWith(
            (ref) => completer.future,
          ),
        );

        DateTime startDay() => dayStart(
          container.read(insightsRangeControllerProvider).range.startDay,
        );

        await withClock(Clock.fixed(fixedNow), () async {
          // First frame: region unresolved → Monday-start default.
          expect(startDay(), DateTime(2026, 6)); // Mon Jun 1

          // Region resolves to Sunday-first.
          completer.complete(0);
          await pumpEventQueue();

          // The untouched default re-anchors to the Sunday-aligned current week.
          expect(startDay(), DateTime(2026, 6, 7)); // Sun Jun 7
        });
      },
    );

    test('region resolving never clobbers prior navigation', () async {
      final completer = Completer<int>();
      final container = makeContainer(
        firstDayOfWeek: firstDayOfWeekIndexProvider.overrideWith(
          (ref) => completer.future,
        ),
      );

      InsightsPeriodSelection selection() =>
          container.read(insightsRangeControllerProvider);

      await withClock(Clock.fixed(fixedNow), () async {
        // Navigate to the previous (Monday-aligned) week and turn compare on.
        container.read(insightsRangeControllerProvider.notifier)
          ..step(-1)
          ..toggleCompare();
        expect(dayStart(selection().range.startDay), DateTime(2026, 5, 25));

        completer.complete(0); // Sunday-first resolves late
        await pumpEventQueue();

        // The stepped period and the compare toggle both survive.
        expect(dayStart(selection().range.startDay), DateTime(2026, 5, 25));
        expect(selection().compareEnabled, isTrue);

        // And the comparison window stays one week back from the (unchanged)
        // current range — no drift even though the first weekday resolved to
        // Sunday after navigation.
        final previous = container
            .read(insightsRangeControllerProvider.notifier)
            .previousComparisonRange!;
        expect(dayStart(previous.startDay), DateTime(2026, 5, 18));
        expect(dayStart(previous.endDayExclusive), DateTime(2026, 5, 25));
      });
    });
  });

  group('insightsRepositoryProvider', () {
    test('default factory builds a repository over journalDbProvider', () {
      final container = ProviderContainer(
        overrides: [journalDbProvider.overrideWithValue(MockJournalDb())],
      );
      addTearDown(container.dispose);
      expect(
        container.read(insightsRepositoryProvider),
        isA<InsightsRepository>(),
      );
    });
  });

  group('windowStartDayFor integration', () {
    test('periods within one year share one bucket window key', () {
      final week = periodContaining(
        InsightsPeriodUnit.week,
        DateTime(2026, 3, 10),
      );
      final month = periodContaining(
        InsightsPeriodUnit.month,
        DateTime(2026, 9, 5),
      );
      final year = periodContaining(InsightsPeriodUnit.year, DateTime(2026, 6));
      expect(windowStartDayFor(week), windowStartDayFor(month));
      expect(windowStartDayFor(month), windowStartDayFor(year));
    });
  });
}
