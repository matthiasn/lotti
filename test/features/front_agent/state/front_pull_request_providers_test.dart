import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/front_agent/state/front_pull_request_providers.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockJournalDb journalDb;
  late List<PullRequestStatRowRecord> rows;

  // Monday 2026-10-26 through Wednesday 2026-10-28.
  final monday = epochDay(DateTime(2026, 10, 26));
  final chart = FrontPullRequestChart(
    range: InsightsRange(startDay: monday, endDayExclusive: monday + 3),
    categoryIds: const {},
  );

  PullRequestStatRowRecord row(String key, int day, int additions) => (
    entryId: 'entry-$key',
    key: key,
    taskCategoryId: null,
    title: key,
    authorLogin: null,
    createdAt: dayStart(monday + day).add(const Duration(hours: 10)),
    mergedAt: null,
    additions: additions,
    deletions: 1,
  );

  setUp(() {
    journalDb = MockJournalDb();
    rows = [row('p/c#1', 0, 10), row('p/c#2', 2, 30)];
    when(() => journalDb.pullRequestStatRows()).thenAnswer((_) async => rows);
    when(() => journalDb.getAllCategories()).thenAnswer((_) async => []);
    when(
      () => journalDb.getAllCategoriesIncludingPrivate(),
    ).thenAnswer((_) async => []);
  });

  test('reads the days charted from the device, one value per day', () async {
    final container = ProviderContainer(
      overrides: [journalDbProvider.overrideWithValue(journalDb)],
    );
    addTearDown(container.dispose);
    final provider = frontPullRequestChartProvider(chart);
    container.listen(provider, (_, _) {});

    final days = await container.read(provider.future);

    expect(days.days, [
      DateTime(2026, 10, 26),
      DateTime(2026, 10, 27),
      DateTime(2026, 10, 28),
    ]);
    expect(days.opened, [1, 0, 1]);
    expect(days.additions, [10, 0, 30]);
    expect(days.deletions, [1, 0, 1]);
  });

  test('a refreshed pull request redraws a shown chart; an unwatched one '
      'stops reading', () async {
    final updates = StreamController<Set<String>>.broadcast();
    addTearDown(updates.close);
    final notifications = MockUpdateNotifications();
    when(() => notifications.updateStream).thenAnswer((_) => updates.stream);
    final container = ProviderContainer(
      overrides: [
        journalDbProvider.overrideWithValue(journalDb),
        maybeUpdateNotificationsProvider.overrideWithValue(notifications),
      ],
    );
    addTearDown(container.dispose);
    final provider = frontPullRequestChartProvider(chart);
    final seen = <List<int>>[];
    final redrawn = Completer<void>();
    final subscription = container.listen(provider, (_, next) {
      final opened = next.value?.opened;
      if (opened == null) return;
      seen.add(opened);
      if (opened[1] == 1 && !redrawn.isCompleted) redrawn.complete();
    }, fireImmediately: true);
    await container.read(provider.future);
    expect(seen.single, [1, 0, 1]);

    rows = [...rows, row('p/c#3', 1, 5)];
    updates.add({pullRequestNotification});
    await redrawn.future;
    expect(seen.last, [1, 1, 1]);

    subscription.close();
    await pumpEventQueue();
    clearInteractions(journalDb);
    updates.add({pullRequestNotification});
    await pumpEventQueue();
    verifyNever(() => journalDb.pullRequestStatRows());
  });
}
