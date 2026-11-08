import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/front_agent/model/front_logged_time_chart.dart';
import 'package:lotti/features/front_agent/state/front_logged_time_providers.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../categories/test_utils.dart';

void main() {
  late MockJournalDb journalDb;
  late ProviderContainer container;

  // Monday 2026-10-26 through Wednesday 2026-10-28.
  final monday = epochDay(DateTime(2026, 10, 26));
  final range = InsightsRange(startDay: monday, endDayExclusive: monday + 3);

  ({String entryId, DateTime dateFrom, DateTime dateTo, String? categoryId})
  row(String? categoryId, int day, int fromHour, int toHour) {
    final date = dayStart(monday + day);
    return (
      entryId: '$categoryId-$day-$fromHour',
      dateFrom: date.add(Duration(hours: fromHour)),
      dateTo: date.add(Duration(hours: toHour)),
      categoryId: categoryId,
    );
  }

  setUp(() {
    journalDb = MockJournalDb();
    when(
      () => journalDb.insightsTimeRows(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer(
      (_) async => [
        row('colony', 0, 9, 11),
        // Overlaps the one before it: the shared hour counts once.
        row('colony', 0, 10, 12),
        row('fishing', 2, 8, 9),
        row(null, 2, 13, 14),
        // A private category while private entries are hidden.
        row('secret', 1, 9, 17),
      ],
    );
    when(() => journalDb.getAllCategories()).thenAnswer(
      (_) async => [
        CategoryTestUtils.createTestCategory(id: 'colony', name: 'Colony'),
        CategoryTestUtils.createTestCategory(id: 'fishing', name: 'Fishing'),
      ],
    );
    when(() => journalDb.getAllCategoriesIncludingPrivate()).thenAnswer(
      (_) async => [
        CategoryTestUtils.createTestCategory(id: 'colony', name: 'Colony'),
        CategoryTestUtils.createTestCategory(id: 'fishing', name: 'Fishing'),
        CategoryTestUtils.createTestCategory(
          id: 'secret',
          name: 'Secret',
          private: true,
        ),
      ],
    );
    container = ProviderContainer(
      overrides: [journalDbProvider.overrideWithValue(journalDb)],
    );
  });

  tearDown(() => container.dispose());

  Future<InsightsChartData> read(Set<String> categoryIds) {
    final provider = frontLoggedTimeChartProvider(
      FrontLoggedTimeChart(range: range, categoryIds: categoryIds),
    );
    // Shown while read: an unwatched chart is disposed.
    container.listen(provider, (_, _) {});
    return container.read(provider.future);
  }

  test('reads the days charted, one bucket per day, each category apart, '
      'overlaps once and a hidden private category never', () async {
    final data = await read(const {});

    verify(
      () => journalDb.insightsTimeRows(
        start: DateTime(2026, 10, 26),
        end: DateTime(2026, 10, 29),
      ),
    ).called(1);
    expect(data.granularity, InsightsGranularity.day);
    expect(data.bucketStarts, [
      DateTime(2026, 10, 26),
      DateTime(2026, 10, 27),
      DateTime(2026, 10, 28),
    ]);
    expect(data.seriesKeys, ['colony', 'fishing', null]);
    expect(data.values, [
      [3 * 3600, 0, 0],
      [0, 0, 3600],
      [0, 0, 3600],
    ]);
  });

  test(
    'a narrowed scope charts only its categories, never time in none',
    () async {
      final data = await read(const {'fishing'});

      expect(data.seriesKeys, ['fishing']);
      expect(data.values, [
        [0, 0, 3600],
      ]);
    },
  );

  test('hiding private entries takes their time off a shown chart at once, '
      'and the chart stops reading when no longer shown', () async {
    final updates = StreamController<Set<String>>.broadcast();
    addTearDown(updates.close);
    final notifications = MockUpdateNotifications();
    when(() => notifications.updateStream).thenAnswer((_) => updates.stream);
    // Private entries shown: the private category is in the visible read.
    final visible = [
      CategoryTestUtils.createTestCategory(id: 'colony', name: 'Colony'),
      CategoryTestUtils.createTestCategory(id: 'fishing', name: 'Fishing'),
      CategoryTestUtils.createTestCategory(
        id: 'secret',
        name: 'Secret',
        private: true,
      ),
    ];
    when(() => journalDb.getAllCategories()).thenAnswer((_) async => visible);
    final live = ProviderContainer(
      overrides: [
        journalDbProvider.overrideWithValue(journalDb),
        maybeUpdateNotificationsProvider.overrideWithValue(notifications),
      ],
    );
    addTearDown(live.dispose);
    final provider = frontLoggedTimeChartProvider(
      FrontLoggedTimeChart(range: range, categoryIds: const {}),
    );
    final seen = <List<String?>>[];
    final hidden = Completer<void>();
    final subscription = live.listen(provider, (_, next) {
      final keys = next.value?.seriesKeys;
      if (keys == null) return;
      seen.add(keys);
      if (!keys.contains('secret') && !hidden.isCompleted) hidden.complete();
    }, fireImmediately: true);
    await live.read(provider.future);
    expect(seen.single, contains('secret'));

    visible.removeLast();
    updates.add({privateToggleNotification});
    await hidden.future;
    expect(seen.last, ['colony', 'fishing', null]);

    subscription.close();
    // An unwatched chart is disposed on the next tick.
    await pumpEventQueue();
    clearInteractions(journalDb);
    updates.add({privateToggleNotification});
    await pumpEventQueue();
    verifyNever(() => journalDb.getAllCategories());
  });
}
