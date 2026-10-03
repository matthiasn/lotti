import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/features/daily_os_next/logic/actual_time_blocks.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';

import '../../../test_data/test_data.dart';
import '../state/actual_time_blocks_provider_test_helpers.dart';

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
        eventsEnabled: true,
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
          eventsEnabled: true,
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
        eventsEnabled: true,
      );

      // No task is linked, so taskId stays null and the category comes from
      // the note's categoryId (since the note is the non-rating fallback).
      expect(blocks.single.taskId, isNull);
      expect(blocks.single.category.id, 'cat-note');
    });

    test('a check-in with a length is recorded time, titled by the person '
        'and coloured by their category; one without a length stays off', () {
      final day = DateTime(2026, 9, 6);
      final person = testRelationship.copyWith(
        meta: testRelationship.meta.copyWith(categoryId: 'cat-people'),
      );
      CheckInEntry checkIn(String id, DateTime from, Duration length) =>
          CheckInEntry(
            meta: Metadata(
              id: id,
              createdAt: from,
              updatedAt: from,
              dateFrom: from,
              dateTo: from.add(length),
              categoryId: 'cat-people',
            ),
            data: CheckInData(
              relationshipId: person.meta.id,
              interactionType: CheckInInteractionType.call,
            ),
            entryText: const EntryText(plainText: 'Talked about the move.'),
          );
      final longCall = checkIn(
        'call-long',
        day.add(const Duration(hours: 12, minutes: 44)),
        const Duration(hours: 1, minutes: 15),
      );
      final shortCall = checkIn(
        'call-short',
        day.add(const Duration(hours: 18)),
        const Duration(minutes: 15),
      );
      final noLength = checkIn(
        'call-no-length',
        day.add(const Duration(hours: 20)),
        Duration.zero,
      );

      final blocks = actualTimeBlocksForEntries(
        entries: [shortCall, noLength, longCall],
        links: [
          for (final call in [longCall, shortCall, noLength])
            EntryLink.relationship(
              id: 'l-${call.meta.id}',
              fromId: person.meta.id,
              toId: call.meta.id,
              createdAt: day,
              updatedAt: day,
              vectorClock: null,
            ),
        ],
        linkedFromById: {person.meta.id: person},
        categoryById: (_) => null,
        eventsEnabled: true,
      );

      expect(blocks.map((b) => b.id), [
        'actual:call-long',
        'actual:call-short',
      ]);
      expect(blocks.map((b) => b.end.difference(b.start)), [
        const Duration(hours: 1, minutes: 15),
        const Duration(minutes: 15),
      ]);
      expect(blocks.map((b) => b.title), ['Anna', 'Anna']);
      expect(blocks.first.category.id, 'cat-people');
      expect(blocks.first.type, TimeBlockType.manual);
      expect(blocks.first.state, TimeBlockState.completed);
      expect(blocks.first.taskId, isNull);
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
        eventsEnabled: true,
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
        eventsEnabled: true,
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
        eventsEnabled: true,
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
        eventsEnabled: true,
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
        eventsEnabled: true,
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
        eventsEnabled: true,
      );

      expect(blocks.single.title, 'Morning walk');
    });

    // The event the user edited on the events page to run from 18:00 to
    // midnight: it is recorded time like any session, but it is its own
    // thing — its own title, its own category, no task behind it — and a
    // calendar block so the timeline can open the event page from it.
    test('projects an event as a calendar block titled by the event, in its '
        'own category, sorted among the recordings', () {
      final day = DateTime(2026, 5, 27);
      final task = hTask(
        id: 'task-1',
        title: 'Plan the reunion',
        categoryId: 'cat-work',
        day: day,
      );
      final event = hEvent(
        id: 'evt-1',
        day: day,
        startHour: 18,
        endHour: 24,
        title: ' Dinner with a friend ',
        categoryId: 'cat-social',
      );

      final blocks = actualTimeBlocksForEntries(
        entries: [
          event,
          hEntry(id: 'entry-1', day: day, startHour: 9, endHour: 10),
        ],
        links: [
          hLink('l1', from: task.meta.id, to: event.meta.id, day: day),
        ],
        linkedFromById: {task.meta.id: task},
        categoryById: (id) => id == 'cat-social'
            ? hCategory(id: id, name: 'Social', color: '#E8A33D')
            : hCategory(id: id, name: 'Work', color: '#5ED4B7'),
        eventsEnabled: true,
      );

      expect(blocks.map((block) => block.id), [
        'actual:entry-1',
        'actual:evt-1',
      ]);
      final eventBlock = blocks.last;
      expect(eventBlock.title, 'Dinner with a friend');
      expect(eventBlock.type, TimeBlockType.cal);
      // Planned, not done: the lane shows it filled but unchecked.
      expect(eventBlock.state, TimeBlockState.committed);
      expect(eventBlock.taskId, isNull);
      expect(eventBlock.trackedEntryId, 'evt-1');
      expect(eventBlock.category.name, 'Social');
      expect(eventBlock.category.colorHex, 'E8A33D');
      expect(eventBlock.start, day.add(const Duration(hours: 18)));
      expect(eventBlock.end, day.add(const Duration(days: 1)));
      expect(blocks.first.type, TimeBlockType.manual);
    });

    // A recording is finished by definition; an event is only as far along as
    // its status says — a dinner still ahead must not wear the lane's check
    // mark or count as done.
    test('the block state follows the event status', () {
      final day = DateTime(2026, 5, 27);
      final byStatus = {
        for (final status in EventStatus.values)
          status: eventBlockState(
            hEvent(
              id: 'evt-${status.name}',
              day: day,
              startHour: 18,
              endHour: 20,
              status: status,
            ),
          ),
      };

      expect(byStatus, {
        EventStatus.completed: TimeBlockState.completed,
        EventStatus.ongoing: TimeBlockState.inProgress,
        EventStatus.tentative: TimeBlockState.committed,
        EventStatus.planned: TimeBlockState.committed,
        EventStatus.rescheduled: TimeBlockState.committed,
        EventStatus.cancelled: TimeBlockState.dropped,
        EventStatus.missed: TimeBlockState.dropped,
        EventStatus.postponed: TimeBlockState.dropped,
      });
    });

    test('a completed event is checked on the lane, an ongoing one is in '
        'progress, and a recording is always completed', () {
      final day = DateTime(2026, 5, 27);

      final blocks = actualTimeBlocksForEntries(
        entries: [
          hEvent(
            id: 'done',
            day: day,
            startHour: 12,
            endHour: 13,
            status: EventStatus.completed,
          ),
          hEvent(
            id: 'now',
            day: day,
            startHour: 18,
            endHour: 20,
            status: EventStatus.ongoing,
          ),
          hEntry(id: 'entry-1', day: day, startHour: 9, endHour: 10),
        ],
        links: const [],
        linkedFromById: const {},
        categoryById: (_) => null,
        eventsEnabled: true,
      );

      expect(blocks.map((block) => block.state), [
        TimeBlockState.completed,
        TimeBlockState.completed,
        TimeBlockState.inProgress,
      ]);
    });

    test('an untitled event falls through to its text, then its category', () {
      final day = DateTime(2026, 5, 27);

      final blocks = actualTimeBlocksForEntries(
        entries: [
          hEvent(
            id: 'noted',
            day: day,
            startHour: 18,
            endHour: 20,
            title: '',
            text: 'Table for two\nby the window',
          ),
          hEvent(
            id: 'bare',
            day: day,
            startHour: 20,
            endHour: 22,
            title: '  ',
            categoryId: 'cat-social',
          ),
        ],
        links: const [],
        linkedFromById: const {},
        categoryById: (id) =>
            hCategory(id: id, name: 'Social', color: '#E8A33D'),
        eventsEnabled: true,
      );

      expect(blocks.map((block) => block.title), ['Table for two', 'Social']);
    });

    test('a cancelled event stays off the lane', () {
      final day = DateTime(2026, 5, 27);

      final blocks = actualTimeBlocksForEntries(
        entries: [
          hEvent(
            id: 'evt-1',
            day: day,
            startHour: 18,
            endHour: 20,
            status: EventStatus.cancelled,
          ),
          hEntry(id: 'entry-1', day: day, startHour: 9, endHour: 10),
        ],
        links: const [],
        linkedFromById: const {},
        categoryById: (_) => null,
        eventsEnabled: true,
      );

      expect(blocks.map((block) => block.id), ['actual:entry-1']);
    });

    test('events stay off the lane while the Events feature is off', () {
      final day = DateTime(2026, 5, 27);

      final blocks = actualTimeBlocksForEntries(
        entries: [
          hEvent(id: 'evt-1', day: day, startHour: 18, endHour: 20),
          hEntry(id: 'entry-1', day: day, startHour: 9, endHour: 10),
        ],
        links: const [],
        linkedFromById: const {},
        categoryById: (_) => null,
        eventsEnabled: false,
      );

      expect(blocks.map((block) => block.id), ['actual:entry-1']);
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
        eventsEnabled: true,
      );

      expect(blocks.single.title, 'blank');
    });
  });
}
