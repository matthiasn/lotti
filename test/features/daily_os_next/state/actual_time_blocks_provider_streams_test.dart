import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/daily_os_next/state/actual_time_blocks_provider.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import 'actual_time_blocks_provider_test_helpers.dart';

void main() {
  group('actualTimelineUpdateBatches', () {
    test('refreshes for any non-empty database update batch', () async {
      final batches = actualTimelineUpdateBatches(
        Stream<Set<String>>.fromIterable([
          const {},
          {'entry-1'},
          {'unrelated-row'},
        ]),
      );

      await expectLater(
        batches,
        emitsInOrder([
          {'entry-1'},
          {'unrelated-row'},
          emitsDone,
        ]),
      );
    });
  });

  group('dailyOsActualTimeUpdateProvider', () {
    test(
      'returns an empty stream when UpdateNotifications is not registered',
      () {
        fakeAsync((async) {
          final container = ProviderContainer(
            overrides: [
              maybeUpdateNotificationsProvider.overrideWith((ref) => null),
            ],
          );
          addTearDown(container.dispose);
          final states = <AsyncValue<Set<String>>>[];
          final subscription = container.listen(
            dailyOsActualTimeUpdateProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );
          addTearDown(subscription.close);

          async.flushMicrotasks();
          expect(states, [const AsyncLoading<Set<String>>()]);
          expect(subscription.read().hasError, isFalse);
        });
      },
    );

    test('forwards non-empty batches after the notification debounce', () {
      fakeAsync((async) {
        final notifications = UpdateNotifications();
        addTearDown(notifications.dispose);

        final container = ProviderContainer(
          overrides: [
            maybeUpdateNotificationsProvider.overrideWith(
              (ref) => notifications,
            ),
          ],
        );
        addTearDown(container.dispose);

        final sub = container.listen<AsyncValue<Set<String>>>(
          dailyOsActualTimeUpdateProvider,
          (_, _) {},
        );
        addTearDown(sub.close);

        notifications.notify({'entry-1'});
        async.elapse(const Duration(milliseconds: 99));
        expect(sub.read().hasValue, isFalse);
        notifications.notify({'entry-2'});
        async.elapse(const Duration(milliseconds: 100));

        expect(sub.read().asData?.value, {'entry-1', 'entry-2'});
      });
    });
  });

  group('dailyOsActualTimeBlocksProvider', () {
    test(
      'queries the journal DB for the day window and projects the entries',
      () async {
        final day = DateTime(2026, 5, 27);
        final dayStart = DateTime(day.year, day.month, day.day);
        final dayEnd = dayStart.add(const Duration(days: 1));
        final db = MockJournalDb();
        final entry = hEntry(
          id: 'entry-1',
          day: day,
          startHour: 9,
          endHour: 10,
          text: 'Day entry',
        );
        when(
          () => db.sortedCalendarEntries(
            rangeStart: dayStart,
            rangeEnd: dayEnd,
          ),
        ).thenAnswer((_) async => [entry]);
        when(
          () => db.basicLinksForEntryIds(any()),
        ).thenAnswer((_) async => const <EntryLink>[]);

        final container = ProviderContainer(
          overrides: [journalDbProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);

        final blocks = await readActualBlocks(container, day);

        expect(blocks.single.id, 'actual:entry-1');
        expect(blocks.single.title, 'Day entry');
      },
    );

    test(
      'resolves linked-from entities via getJournalEntitiesForIdsUnordered',
      () async {
        final day = DateTime(2026, 5, 27);
        final dayStart = DateTime(day.year, day.month, day.day);
        final dayEnd = dayStart.add(const Duration(days: 1));
        final db = MockJournalDb();
        final entry = hEntry(
          id: 'entry-1',
          day: day,
          startHour: 9,
          endHour: 10,
        );
        final task = hTask(
          id: 'task-1',
          title: 'From link',
          categoryId: 'cat-work',
          day: day,
        );
        when(
          () => db.sortedCalendarEntries(
            rangeStart: dayStart,
            rangeEnd: dayEnd,
          ),
        ).thenAnswer((_) async => [entry]);
        when(() => db.basicLinksForEntryIds(any())).thenAnswer(
          (_) async => [
            hLink('l-1', from: task.meta.id, to: entry.meta.id, day: day),
          ],
        );
        when(
          () => db.getJournalEntitiesForIdsUnordered(any()),
        ).thenAnswer((_) async => [task]);

        final container = ProviderContainer(
          overrides: [journalDbProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);

        final blocks = await readActualBlocks(container, day);

        expect(blocks.single.taskId, 'task-1');
        expect(blocks.single.title, 'From link');
      },
    );

    test(
      'uses EntitiesCacheService for category lookups when registered',
      () async {
        final day = DateTime(2026, 5, 27);
        final dayStart = DateTime(day.year, day.month, day.day);
        final dayEnd = dayStart.add(const Duration(days: 1));
        final db = MockJournalDb();
        final cache = MockEntitiesCacheService();
        when(
          () => cache.getCategoryById('cat-work'),
        ).thenReturn(hCategory(id: 'cat-work', name: 'Work', color: '5ED4B7'));
        GetIt.instance.registerSingleton<EntitiesCacheService>(cache);
        addTearDown(GetIt.instance.unregister<EntitiesCacheService>);

        final entry = hEntry(
          id: 'entry-1',
          day: day,
          startHour: 9,
          endHour: 10,
          categoryId: 'cat-work',
        );
        when(
          () => db.sortedCalendarEntries(
            rangeStart: dayStart,
            rangeEnd: dayEnd,
          ),
        ).thenAnswer((_) async => [entry]);
        when(
          () => db.basicLinksForEntryIds(any()),
        ).thenAnswer((_) async => const <EntryLink>[]);

        final container = ProviderContainer(
          overrides: [journalDbProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);

        final blocks = await readActualBlocks(container, day);

        expect(blocks.single.category.name, 'Work');
        expect(blocks.single.category.colorHex, '5ED4B7');
        verify(() => cache.getCategoryById('cat-work')).called(1);
      },
    );
  });
}
