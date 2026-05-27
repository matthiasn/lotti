import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/daily_os_next/state/actual_time_blocks_provider.dart';

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
