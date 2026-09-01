import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/features/daily_os_next/state/actual_time_blocks_provider.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/signals/health_signal_refresh_service.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import 'actual_time_blocks_provider_test_helpers.dart';

void main() {
  group('actualTimeBlocksForEntries', () {
    test('projects recorded entries through linked tasks and categories', () {
      final day = DateTime(2026, 5, 27);
      final task = hTask(
        id: 'task-1',
        title: 'Write release notes',
        categoryId: 'cat-work',
        day: day,
      );
      final taskEntry = hEntry(
        id: 'entry-1',
        day: day,
        startHour: 9,
        endHour: 12,
      );
      final noteEntry = hEntry(
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
        categoryById: (id) => hCategory(
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
        final task = hTask(
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
        final entry = hEntry(
          id: 'entry-1',
          day: day,
          startHour: 9,
          endHour: 10,
        );

        final blocks = actualTimeBlocksForEntries(
          entries: [entry],
          links: [
            hLink(
              'l-rating',
              from: rating.meta.id,
              to: entry.meta.id,
              day: day,
            ),
            hLink('l-note', from: note.meta.id, to: entry.meta.id, day: day),
            hLink('l-task', from: task.meta.id, to: entry.meta.id, day: day),
            hLink(
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
              hCategory(id: id, name: 'Work', color: '5ED4B7'),
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
      final entry = hEntry(
        id: 'entry-2',
        day: day,
        startHour: 9,
        endHour: 10,
        text: '   ',
      );

      final blocks = actualTimeBlocksForEntries(
        entries: [entry],
        links: [
          hLink('l-note', from: note.meta.id, to: entry.meta.id, day: day),
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
      final entryWithText = hEntry(
        id: 'e-text',
        day: day,
        startHour: 9,
        endHour: 10,
        text: 'First line\nSecond line',
      );
      final entryWithCategory = hEntry(
        id: 'e-cat',
        day: day,
        startHour: 11,
        endHour: 12,
        categoryId: 'cat-named',
      );
      final entryWithNothing = hEntry(
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
            ? hCategory(id: id, name: 'Named cat', color: '#112233')
            : null,
      );

      final byId = {for (final b in blocks) b.id: b};
      expect(byId['actual:e-text']!.title, 'First line');
      expect(byId['actual:e-cat']!.title, 'Named cat');
      expect(byId['actual:e-bare']!.title, 'e-bare');
    });

    test('drops the alpha suffix on long category color strings', () {
      final day = DateTime(2026, 5, 27);
      final entry = hEntry(
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
            hCategory(id: id, name: 'Color cat', color: '#AABBCCDD'),
      );

      // RRGGBBAA → keep first 6 chars (RRGGBB) per project convention.
      expect(blocks.single.category.colorHex, 'AABBCC');
    });

    test('falls back to the default color when the category color is too '
        'short', () {
      final day = DateTime(2026, 5, 27);
      final entry = hEntry(
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
        categoryById: (id) => hCategory(id: id, name: 'Short', color: '#ABC'),
      );

      expect(blocks.single.category.colorHex, '8E8E8E');
    });

    test('ignores zero-duration and deleted entries', () {
      final day = DateTime(2026, 5, 27);

      final blocks = actualTimeBlocksForEntries(
        entries: [
          hEntry(id: 'zero', day: day, startHour: 9, endHour: 9),
          hEntry(
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

    // An imported workout has no text, no category and no linked task, so it
    // used to fall through every fallback and print its own id on the lane.
    test('titles an imported workout by its activity, in either spelling', () {
      final day = DateTime(2026, 5, 27);

      final blocks = actualTimeBlocksForEntries(
        entries: [
          hWorkout(id: 'walk', day: day, startHour: 7),
          hWorkout(
            id: 'strength',
            day: day,
            startHour: 18,
            workoutType: 'functionalStrengthTraining',
          ),
        ],
        links: const [],
        linkedFromById: const {},
        categoryById: (_) => null,
      );

      expect(blocks.map((b) => b.title), [
        'Walking',
        'Functional Strength Training',
      ]);
      expect(blocks.first.taskId, isNull);
      expect(blocks.first.duration, const Duration(minutes: 45));
      expect(blocks.first.category.name, isEmpty);
    });

    test('a workout the user annotated keeps the annotation as its title', () {
      final day = DateTime(2026, 5, 27);

      final blocks = actualTimeBlocksForEntries(
        entries: [
          hWorkout(
            id: 'walk',
            day: day,
            startHour: 7,
            text: 'Morning walk\nround the lake',
          ),
        ],
        links: const [],
        linkedFromById: const {},
        categoryById: (_) => null,
      );

      expect(blocks.single.title, 'Morning walk');
    });

    test('a workout without an activity falls through to the id', () {
      final day = DateTime(2026, 5, 27);

      final blocks = actualTimeBlocksForEntries(
        entries: [
          hWorkout(id: 'blank', day: day, startHour: 7, workoutType: ''),
        ],
        links: const [],
        linkedFromById: const {},
        categoryById: (_) => null,
      );

      expect(blocks.single.title, 'blank');
    });
  });

  group('dailyOsActualTimeUpdateProvider', () {
    test('actualTimelineUpdateBatches drops empty batches', () async {
      final batches = await actualTimelineUpdateBatches(
        Stream.fromIterable([
          <String>{},
          {'entry-1'},
          <String>{},
          {'entry-2', 'entry-3'},
        ]),
      ).toList();

      expect(batches, [
        {'entry-1'},
        {'entry-2', 'entry-3'},
      ]);
    });

    test(
      'bridges the registered notification stream, empties dropped',
      () async {
        final notifications = MockUpdateNotifications();
        when(() => notifications.updateStream).thenAnswer(
          (_) => Stream.fromIterable([
            <String>{},
            {'entry-1'},
          ]),
        );
        getIt.registerSingleton<UpdateNotifications>(notifications);
        addTearDown(getIt.reset);
        final container = ProviderContainer();
        addTearDown(container.dispose);
        // autoDispose: without a live listener the provider is torn down
        // between the read and the first emission.
        final subscription = container.listen(
          dailyOsActualTimeUpdateProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);

        final first = await container.read(
          dailyOsActualTimeUpdateProvider.future,
        );

        expect(first, {'entry-1'});
      },
    );
  });

  group('dailyOsActualTimeBlocksProvider', () {
    final day = DateTime(2026, 5, 27);
    late MockJournalDb db;

    setUp(() {
      db = MockJournalDb();
      final walk = hWorkout(id: 'walk', day: day, startHour: 7);
      when(
        () => db.sortedCalendarEntries(
          rangeStart: day,
          rangeEnd: day.add(const Duration(days: 1)),
        ),
      ).thenAnswer((_) async => [walk]);
      when(
        () => db.basicLinksForEntryIds({walk.meta.id}),
      ).thenAnswer((_) async => const []);
    });

    // Workouts reach the journal only through the health import, and this
    // lane used to wait for a dashboard to ask for one.
    test('nudges the workout importer and projects the day', () async {
      final healthImport = MockHealthImport();
      when(
        healthImport.getWorkoutsHealthDataDelta,
      ).thenAnswer((_) async => const HealthImportResult.imported(0));
      final container = ProviderContainer(
        overrides: [
          journalDbProvider.overrideWithValue(db),
          healthSignalRefreshServiceProvider.overrideWithValue(
            HealthSignalRefreshService(healthImport),
          ),
        ],
      );
      addTearDown(container.dispose);

      final blocks = await container.read(
        dailyOsActualTimeBlocksProvider(day).future,
      );

      expect(blocks.single.title, 'Walking');
      expect(blocks.single.id, 'actual:walk');
      verify(healthImport.getWorkoutsHealthDataDelta).called(1);
    });

    test(
      'projects the day without an importer (desktop, demo worlds)',
      () async {
        final container = ProviderContainer(
          overrides: [
            journalDbProvider.overrideWithValue(db),
            healthSignalRefreshServiceProvider.overrideWithValue(null),
          ],
        );
        addTearDown(container.dispose);

        final blocks = await container.read(
          dailyOsActualTimeBlocksProvider(day).future,
        );

        expect(blocks.single.title, 'Walking');
      },
    );

    test(
      'resolves linked-from entities through the database and categories '
      'through the cache',
      () async {
        final task = hTask(
          id: 'task-1',
          title: 'Write release notes',
          categoryId: 'cat-work',
          day: day,
        );
        final entry = hEntry(
          id: 'entry-1',
          day: day,
          startHour: 9,
          endHour: 10,
        );
        final link = hLink(
          'l1',
          from: task.meta.id,
          to: entry.meta.id,
          day: day,
        );
        when(
          () => db.sortedCalendarEntries(
            rangeStart: day,
            rangeEnd: day.add(const Duration(days: 1)),
          ),
        ).thenAnswer((_) async => [entry]);
        when(
          () => db.basicLinksForEntryIds({entry.meta.id}),
        ).thenAnswer((_) async => [link]);
        when(
          () => db.getJournalEntitiesForIdsUnordered({task.meta.id}),
        ).thenAnswer((_) async => [task]);
        final cache = MockEntitiesCacheService();
        when(() => cache.getCategoryById('cat-work')).thenReturn(
          hCategory(id: 'cat-work', name: 'Work', color: '#5ED4B7'),
        );
        getIt.registerSingleton<EntitiesCacheService>(cache);
        addTearDown(getIt.reset);
        final container = ProviderContainer(
          overrides: [
            journalDbProvider.overrideWithValue(db),
            healthSignalRefreshServiceProvider.overrideWithValue(null),
          ],
        );
        addTearDown(container.dispose);

        final blocks = await container.read(
          dailyOsActualTimeBlocksProvider(day).future,
        );

        expect(blocks.single.title, 'Write release notes');
        expect(blocks.single.taskId, 'task-1');
        expect(blocks.single.category.name, 'Work');
      },
    );

    test('a failing importer does not take the lane down', () async {
      final healthImport = MockHealthImport();
      when(
        healthImport.getWorkoutsHealthDataDelta,
      ).thenThrow(StateError('health store unavailable'));
      final container = ProviderContainer(
        overrides: [
          journalDbProvider.overrideWithValue(db),
          healthSignalRefreshServiceProvider.overrideWithValue(
            HealthSignalRefreshService(healthImport),
          ),
        ],
      );
      addTearDown(container.dispose);

      final blocks = await container.read(
        dailyOsActualTimeBlocksProvider(day).future,
      );

      expect(blocks.single.title, 'Walking');
    });
  });
}
