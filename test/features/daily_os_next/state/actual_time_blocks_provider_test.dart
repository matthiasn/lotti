import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
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

void main() {
  group('actualTimeBlocksForEntries', () {
    test('projects recorded entries through linked tasks and categories', () {
      final day = DateTime(2026, 5, 27);
      final task = _task(
        id: 'task-1',
        title: 'Write release notes',
        categoryId: 'cat-work',
        day: day,
      );
      final taskEntry = _entry(
        id: 'entry-1',
        day: day,
        startHour: 9,
        endHour: 12,
      );
      final noteEntry = _entry(
        id: 'entry-2',
        day: day,
        startHour: 13,
        endHour: 14,
        text: 'Loose research note\nwith detail',
        categoryId: 'cat-study',
      );

      final blocks = actualTimeBlocksForEntries(
        entries: [noteEntry, taskEntry],
        links: [
          EntryLink.basic(
            id: 'link-1',
            fromId: task.meta.id,
            toId: taskEntry.meta.id,
            createdAt: day,
            updatedAt: day,
            vectorClock: null,
          ),
        ],
        linkedFromById: {task.meta.id: task},
        categoryById: (id) => _category(
          id: id,
          name: id == 'cat-work' ? 'Work' : 'Study',
          color: id == 'cat-work' ? '#5ED4B7' : '#FFAA00',
        ),
      );

      expect(blocks.map((block) => block.id), [
        'actual:entry-1',
        'actual:entry-2',
      ]);
      expect(blocks.first.title, 'Write release notes');
      expect(blocks.first.taskId, 'task-1');
      expect(blocks.first.category.name, 'Work');
      expect(blocks.first.category.colorHex, '5ED4B7');
      expect(blocks.first.duration, const Duration(hours: 3));
      expect(blocks.last.title, 'Loose research note');
      expect(blocks.last.category.name, 'Study');
    });

    test(
      'prefers a task linked-from over other non-task entities and skips ratings',
      () {
        final day = DateTime(2026, 5, 27);
        final task = _task(
          id: 'task-1',
          title: 'Linked task',
          categoryId: 'cat-work',
          day: day,
        );
        final note = JournalEntity.journalEntry(
          meta: Metadata(
            id: 'fallback-note',
            createdAt: day,
            updatedAt: day,
            dateFrom: day,
            dateTo: day,
          ),
          entryText: const EntryText(plainText: 'Linked note body'),
        );
        final rating = JournalEntity.rating(
          meta: Metadata(
            id: 'rating-1',
            createdAt: day,
            updatedAt: day,
            dateFrom: day,
            dateTo: day,
          ),
          data: const RatingData(
            targetId: 'entry-1',
            dimensions: [],
          ),
        );
        final entry = _entry(
          id: 'entry-1',
          day: day,
          startHour: 9,
          endHour: 10,
        );

        final blocks = actualTimeBlocksForEntries(
          entries: [entry],
          links: [
            _link(
              'l-rating',
              from: rating.meta.id,
              to: entry.meta.id,
              day: day,
            ),
            _link('l-note', from: note.meta.id, to: entry.meta.id, day: day),
            _link('l-task', from: task.meta.id, to: entry.meta.id, day: day),
            _link(
              'l-deleted',
              from: 'never',
              to: entry.meta.id,
              day: day,
              deletedAt: day,
            ),
          ],
          linkedFromById: {
            rating.meta.id: rating,
            note.meta.id: note,
            task.meta.id: task,
          },
          categoryById: (id) =>
              _category(id: id, name: 'Work', color: '5ED4B7'),
        );

        expect(blocks.single.taskId, task.meta.id);
        expect(blocks.single.title, 'Linked task');
      },
    );

    test('falls back to a non-task, non-rating linked-from when no task is '
        'linked', () {
      final day = DateTime(2026, 5, 27);
      final note = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'fallback-note',
          createdAt: day,
          updatedAt: day,
          dateFrom: day,
          dateTo: day,
          categoryId: 'cat-note',
        ),
        entryText: const EntryText(plainText: 'Linked note body'),
      );
      final entry = _entry(
        id: 'entry-2',
        day: day,
        startHour: 9,
        endHour: 10,
        text: '   ',
      );

      final blocks = actualTimeBlocksForEntries(
        entries: [entry],
        links: [
          _link('l-note', from: note.meta.id, to: entry.meta.id, day: day),
        ],
        linkedFromById: {note.meta.id: note},
        categoryById: (_) => null,
      );

      // No task is linked, so taskId stays null and the category comes from
      // the note's categoryId (since the note is the non-rating fallback).
      expect(blocks.single.taskId, isNull);
      expect(blocks.single.category.id, 'cat-note');
    });

    test('uses entry text → category name → entry id as title fallbacks', () {
      final day = DateTime(2026, 5, 27);
      final entryWithText = _entry(
        id: 'e-text',
        day: day,
        startHour: 9,
        endHour: 10,
        text: 'First line\nSecond line',
      );
      final entryWithCategory = _entry(
        id: 'e-cat',
        day: day,
        startHour: 11,
        endHour: 12,
        categoryId: 'cat-named',
      );
      final entryWithNothing = _entry(
        id: 'e-bare',
        day: day,
        startHour: 13,
        endHour: 14,
      );

      final blocks = actualTimeBlocksForEntries(
        entries: [entryWithText, entryWithCategory, entryWithNothing],
        links: const [],
        linkedFromById: const {},
        categoryById: (id) => id == 'cat-named'
            ? _category(id: id, name: 'Named cat', color: '#112233')
            : null,
      );

      final byId = {for (final b in blocks) b.id: b};
      expect(byId['actual:e-text']!.title, 'First line');
      expect(byId['actual:e-cat']!.title, 'Named cat');
      expect(byId['actual:e-bare']!.title, 'e-bare');
    });

    test('drops the alpha suffix on long category color strings', () {
      final day = DateTime(2026, 5, 27);
      final entry = _entry(
        id: 'e-color',
        day: day,
        startHour: 9,
        endHour: 10,
        categoryId: 'cat-long',
      );

      final blocks = actualTimeBlocksForEntries(
        entries: [entry],
        links: const [],
        linkedFromById: const {},
        categoryById: (id) =>
            _category(id: id, name: 'Color cat', color: '#AABBCCDD'),
      );

      // RRGGBBAA → keep first 6 chars (RRGGBB) per project convention.
      expect(blocks.single.category.colorHex, 'AABBCC');
    });

    test('falls back to the default color when the category color is too '
        'short', () {
      final day = DateTime(2026, 5, 27);
      final entry = _entry(
        id: 'e-short',
        day: day,
        startHour: 9,
        endHour: 10,
        categoryId: 'cat-short',
      );

      final blocks = actualTimeBlocksForEntries(
        entries: [entry],
        links: const [],
        linkedFromById: const {},
        categoryById: (id) => _category(id: id, name: 'Short', color: '#ABC'),
      );

      expect(blocks.single.category.colorHex, '8E8E8E');
    });

    test('ignores zero-duration and deleted entries', () {
      final day = DateTime(2026, 5, 27);

      final blocks = actualTimeBlocksForEntries(
        entries: [
          _entry(id: 'zero', day: day, startHour: 9, endHour: 9),
          _entry(
            id: 'deleted',
            day: day,
            startHour: 10,
            endHour: 11,
            deletedAt: day,
          ),
        ],
        links: const [],
        linkedFromById: const {},
        categoryById: (_) => null,
      );

      expect(blocks, isEmpty);
    });
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
        final entry = _entry(
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
        final entry = _entry(
          id: 'entry-1',
          day: day,
          startHour: 9,
          endHour: 10,
        );
        final task = _task(
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
            _link('l-1', from: task.meta.id, to: entry.meta.id, day: day),
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
        ).thenReturn(_category(id: 'cat-work', name: 'Work', color: '5ED4B7'));
        GetIt.instance.registerSingleton<EntitiesCacheService>(cache);
        addTearDown(GetIt.instance.unregister<EntitiesCacheService>);

        final entry = _entry(
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

EntryLink _link(
  String id, {
  required String from,
  required String to,
  required DateTime day,
  DateTime? deletedAt,
}) {
  return EntryLink.basic(
    id: id,
    fromId: from,
    toId: to,
    createdAt: day,
    updatedAt: day,
    vectorClock: null,
    deletedAt: deletedAt,
  );
}

JournalEntry _entry({
  required String id,
  required DateTime day,
  required int startHour,
  required int endHour,
  String? text,
  String? categoryId,
  DateTime? deletedAt,
}) {
  return JournalEntity.journalEntry(
        meta: Metadata(
          id: id,
          createdAt: day,
          updatedAt: day,
          dateFrom: day.add(Duration(hours: startHour)),
          dateTo: day.add(Duration(hours: endHour)),
          categoryId: categoryId,
          deletedAt: deletedAt,
        ),
        entryText: text == null ? null : EntryText(plainText: text),
      )
      as JournalEntry;
}

Task _task({
  required String id,
  required String title,
  required String categoryId,
  required DateTime day,
}) {
  return JournalEntity.task(
        meta: Metadata(
          id: id,
          createdAt: day,
          updatedAt: day,
          dateFrom: day,
          dateTo: day,
          categoryId: categoryId,
        ),
        data: TaskData(
          status: TaskStatus.open(
            id: '$id-status',
            createdAt: day,
            utcOffset: 0,
          ),
          dateFrom: day,
          dateTo: day,
          statusHistory: const [],
          title: title,
        ),
      )
      as Task;
}

CategoryDefinition _category({
  required String id,
  required String name,
  required String color,
}) {
  final now = DateTime(2026, 5, 27);
  return CategoryDefinition(
    id: id,
    createdAt: now,
    updatedAt: now,
    name: name,
    vectorClock: null,
    private: false,
    active: true,
    color: color,
  );
}
