import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/features/daily_os_next/state/actual_time_blocks_provider.dart';

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
  });

  group('debugProjectCategory (pure color/category normalizer)', () {
    glados.Glados2(
      glados.AnyUtils(glados.any).choose(const [null, '', 'cat-1']),
      glados.AnyUtils(glados.any).choose(const [
        '5ED4B7',
        '#5ED4B7',
        '#AABBCCDD',
        'AABBCCDD',
        '#ABC',
        'ABC',
        '',
        '#',
      ]),
      glados.ExploreConfig(numRuns: 120),
    ).test('always yields a 6-char colorHex without a # prefix', (
      categoryId,
      rawColor,
    ) {
      final result = debugProjectCategory(
        categoryId,
        (id) => hCategory(id: id, name: 'Named', color: rawColor),
      );
      final reason = 'categoryId=$categoryId rawColor="$rawColor"';

      expect(result.colorHex.length, 6, reason: reason);
      expect(result.colorHex.contains('#'), isFalse, reason: reason);

      if (categoryId == null || categoryId.isEmpty) {
        // Fallback category, untouched by the raw color.
        expect(result, debugFallbackActualCategory, reason: reason);
      } else {
        expect(result.id, categoryId, reason: reason);
        expect(result.name, 'Named', reason: reason);
        final stripped = rawColor.replaceFirst('#', '');
        expect(
          result.colorHex,
          stripped.length >= 6
              ? stripped.substring(0, 6)
              : debugFallbackActualCategory.colorHex,
          reason: reason,
        );
      }
    }, tags: 'glados');
  });
}
