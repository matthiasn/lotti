import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/insights/logic/range_presets.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/state/insights_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  final fixedNow = DateTime(2026, 6, 7, 16);
  final windowStartDay = epochDay(DateTime(2026));

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

  ProviderContainer makeContainer({UpdateNotifications? withNotifications}) {
    final container = ProviderContainer(
      overrides: [
        insightsRepositoryProvider.overrideWithValue(repository),
        maybeUpdateNotificationsProvider.overrideWith(
          (ref) => withNotifications,
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
    int window, {
    List<AsyncValue<InsightsDayBuckets>>? into,
  }) {
    final sub = container.listen(
      insightsBucketsProvider(window),
      (_, next) => into?.add(next),
      fireImmediately: into != null,
    );
    addTearDown(sub.close);
    return withClock(
      Clock.fixed(fixedNow),
      () => container.read(insightsBucketsProvider(window).future),
    );
  }

  group('insightsBucketsProvider', () {
    test('fetches the window and bucketizes rows', () async {
      stubRows([row(hour: 9)]);
      final container = makeContainer();

      final buckets = await listenAndAwait(container, windowStartDay);

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

      await listenAndAwait(container, windowStartDay);

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
      await listenAndAwait(container, windowStartDay, into: states);

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

    test('ignores unrelated notification tokens', () async {
      stubRows([row(hour: 9)]);
      final container = makeContainer(withNotifications: notifications);

      await listenAndAwait(container, windowStartDay);

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
        await listenAndAwait(container, windowStartDay, into: states);

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
      final previousYearWindow = epochDay(DateTime(2025));

      await listenAndAwait(container, windowStartDay);
      await listenAndAwait(container, previousYearWindow);

      final captured = verify(
        () => repository.fetchTimeRows(
          start: captureAny(named: 'start'),
          end: any(named: 'end'),
        ),
      ).captured;
      expect(captured, [DateTime(2026), DateTime(2025)]);
    });
  });

  group('InsightsRangeController', () {
    test('defaults to the trailing 7 days', () {
      final container = makeContainer();
      final range = withClock(
        Clock.fixed(fixedNow),
        () => container.read(insightsRangeControllerProvider),
      );
      expect(range.preset, InsightsRangePreset.d7);
      expect(range.dayCount, 7);
      expect(dayStart(range.endDayExclusive), DateTime(2026, 6, 8));
    });

    test('selectPreset re-resolves against the current clock', () {
      final container = makeContainer();
      withClock(Clock.fixed(fixedNow), () {
        container
            .read(insightsRangeControllerProvider.notifier)
            .selectPreset(InsightsRangePreset.ytd);
      });
      final range = container.read(insightsRangeControllerProvider);
      expect(range.preset, InsightsRangePreset.ytd);
      expect(dayStart(range.startDay), DateTime(2026));
    });

    test('selectCustom applies an inclusive day range', () {
      final container = makeContainer();
      withClock(Clock.fixed(fixedNow), () {
        container
            .read(insightsRangeControllerProvider.notifier)
            .selectCustom(DateTime(2026, 5, 10), DateTime(2026, 5, 3));
      });
      final range = container.read(insightsRangeControllerProvider);
      expect(range.preset, isNull);
      expect(dayStart(range.startDay), DateTime(2026, 5, 3));
      expect(dayStart(range.endDayExclusive), DateTime(2026, 5, 11));
    });
  });

  group('windowStartDayFor integration', () {
    test('preset ranges in one year share one bucket window key', () {
      withClock(Clock.fixed(fixedNow), () {
        final d7 = resolvePreset(InsightsRangePreset.d7, clock.now());
        final ytd = resolvePreset(InsightsRangePreset.ytd, clock.now());
        final mtd = resolvePreset(InsightsRangePreset.mtd, clock.now());
        expect(windowStartDayFor(d7), windowStartDayFor(ytd));
        expect(windowStartDayFor(mtd), windowStartDayFor(ytd));
      });
    });
  });
}
