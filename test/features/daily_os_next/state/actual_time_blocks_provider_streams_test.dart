import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/daily_os_next/state/actual_time_blocks_provider.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import 'actual_time_blocks_provider_test_helpers.dart';

void main() {
  group('debugResolveLinkedFrom (pure linked-from picker)', () {
    final day = DateTime(2026, 5, 27);

    glados.Glados(
      glados.ListAnys(glados.any).listWithLengthInRange(
        0,
        5,
        glados.AnyUtils(
          glados.any,
        ).choose(const ['task', 'entry', 'rating', 'deleted-task', 'missing']),
      ),
      glados.ExploreConfig(numRuns: 140),
    ).test(
      'prefers tasks, excludes ratings and tombstones, falls back to the '
      'first surviving non-task',
      (kinds) {
        final pool = <String, JournalEntity>{
          'task': hTask(
            id: 'task',
            title: 'A task',
            categoryId: 'cat',
            day: day,
          ),
          'entry': hEntry(id: 'entry', day: day, startHour: 9, endHour: 10),
          'rating': JournalEntity.rating(
            meta: Metadata(
              id: 'rating',
              createdAt: day,
              updatedAt: day,
              dateFrom: day,
              dateTo: day,
            ),
            data: const RatingData(targetId: 'entry', dimensions: []),
          ),
          'deleted-task': JournalEntity.task(
            meta: Metadata(
              id: 'deleted-task',
              createdAt: day,
              updatedAt: day,
              dateFrom: day,
              dateTo: day,
              deletedAt: day,
            ),
            data: TaskData(
              status: TaskStatus.open(
                id: 'dt-status',
                createdAt: day,
                utcOffset: 0,
              ),
              dateFrom: day,
              dateTo: day,
              statusHistory: const [],
              title: 'Deleted',
            ),
          ),
        };
        // Insertion-ordered set mirrors the production LinkedHashSet input.
        final ids = <String>{...kinds};

        final result = debugResolveLinkedFrom(
          linkedFromIds: ids,
          linkedFromById: pool,
        );
        final reason = 'kinds=$kinds';

        // Oracle: first surviving Task wins; else first non-rating
        // survivor; tombstones and ratings never surface.
        JournalEntity? expected;
        for (final id in ids) {
          final entity = pool[id];
          if (entity == null || entity.meta.deletedAt != null) continue;
          if (entity is Task) {
            expected = entity;
            break;
          }
          if (entity is RatingEntry) continue;
          expected ??= entity;
        }

        expect(result?.meta.id, expected?.meta.id, reason: reason);
        expect(result is RatingEntry, isFalse, reason: reason);
        expect(result?.meta.deletedAt, isNull, reason: reason);

        // Null ids short-circuit to null.
        expect(
          debugResolveLinkedFrom(linkedFromIds: null, linkedFromById: pool),
          isNull,
        );
      },
      tags: 'glados',
    );
  });

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
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Wait for the StreamProvider to settle to its empty stream value.
        await container
            .read(dailyOsActualTimeUpdateProvider.future)
            .timeout(const Duration(seconds: 1))
            .catchError((Object _) => <String>{});
        expect(
          container.read(dailyOsActualTimeUpdateProvider).asData,
          isNull,
        );
      },
    );

    test('forwards non-empty batches from UpdateNotifications', () async {
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

      notifications.notify({'entry-1'});
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(sub.read().asData?.value, {'entry-1'});
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

        final blocks = await container.read(
          dailyOsActualTimeBlocksProvider(day).future,
        );

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

        final blocks = await container.read(
          dailyOsActualTimeBlocksProvider(day).future,
        );

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

        final blocks = await container.read(
          dailyOsActualTimeBlocksProvider(day).future,
        );

        expect(blocks.single.category.name, 'Work');
        expect(blocks.single.category.colorHex, '5ED4B7');
        verify(() => cache.getCategoryById('cat-work')).called(1);
      },
    );
  });
}
