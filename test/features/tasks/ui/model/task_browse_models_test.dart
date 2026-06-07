import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/ui/model/task_browse_models.dart';

import '../../../../helpers/entity_factories.dart';

/// Task fixture with a due date — the repeated build/copyWith chain the
/// browse tests share.
JournalEntity _taskWithDue({
  required String id,
  required String title,
  required DateTime dateFrom,
  required DateTime due,
}) {
  return TestTaskFactory.create(
    id: id,
    title: title,
    dateFrom: dateFrom,
  ).copyWith(
    data: TestTaskDataFactory.create(
      title: title,
      dateFrom: dateFrom,
      dateTo: dateFrom.add(const Duration(hours: 1)),
    ).copyWith(due: due),
  );
}

void main() {
  group('buildTaskBrowseEntries', () {
    test(
      'groups due-date sort into due buckets and hides partial trailing count',
      () {
        final now = DateTime(2026, 4, 8, 9);
        final items = <JournalEntity>[
          _taskWithDue(
            id: 'today-1',
            title: 'Today 1',
            dateFrom: DateTime(2026, 4, 8, 9),
            due: DateTime(2026, 4, 8, 18),
          ),
          _taskWithDue(
            id: 'today-2',
            title: 'Today 2',
            dateFrom: DateTime(2026, 4, 8, 11),
            due: DateTime(2026, 4, 8, 20),
          ),
          _taskWithDue(
            id: 'tomorrow-1',
            title: 'Tomorrow 1',
            dateFrom: DateTime(2026, 4, 7, 11),
            due: DateTime(2026, 4, 9, 9),
          ),
        ];

        final entries = withClock(
          Clock.fixed(now),
          () => buildTaskBrowseEntries(
            items: items,
            sortOption: TaskSortOption.byDueDate,
            now: now,
            hasNextPage: true,
          ),
        );

        expect(entries, hasLength(3));
        expect(entries[0].sectionKey.kind, TaskBrowseSectionKind.dueToday);
        expect(entries[0].showSectionHeader, isTrue);
        expect(entries[0].sectionCount, 2);
        expect(entries[1].showSectionHeader, isFalse);
        expect(entries[1].isLastInSection, isTrue);
        expect(entries[2].sectionKey.kind, TaskBrowseSectionKind.dueTomorrow);
        expect(entries[2].showSectionHeader, isTrue);
        expect(entries[2].sectionCount, isNull);
      },
    );

    test('groups priority sort by priority buckets', () {
      final now = DateTime(2026, 4, 8, 9);
      final items = <JournalEntity>[
        TestTaskFactory.create(
          id: 'p0',
          title: 'P0',
          dateFrom: DateTime(2026, 4, 8, 9),
        ).copyWith(
          data: TestTaskDataFactory.create(
            title: 'P0',
            dateFrom: DateTime(2026, 4, 8, 9),
            dateTo: DateTime(2026, 4, 8, 10),
          ).copyWith(priority: TaskPriority.p0Urgent),
        ),
        TestTaskFactory.create(
          id: 'p1',
          title: 'P1',
          dateFrom: DateTime(2026, 4, 8, 8),
        ).copyWith(
          data: TestTaskDataFactory.create(
            title: 'P1',
            dateFrom: DateTime(2026, 4, 8, 8),
            dateTo: DateTime(2026, 4, 8, 9),
          ).copyWith(priority: TaskPriority.p1High),
        ),
      ];

      final entries = buildTaskBrowseEntries(
        items: items,
        sortOption: TaskSortOption.byPriority,
        now: now,
        hasNextPage: false,
      );

      expect(entries[0].sectionKey.kind, TaskBrowseSectionKind.priority);
      expect(entries[0].sectionKey.priority, TaskPriority.p0Urgent);
      expect(entries[0].sectionCount, 1);
      expect(entries[1].sectionKey.priority, TaskPriority.p1High);
      expect(entries[1].showSectionHeader, isTrue);
    });

    test('groups creation-date sort by the task creation day', () {
      final now = DateTime(2026, 4, 8, 9);
      final items = <JournalEntity>[
        TestTaskFactory.create(
          id: 'created-a',
          title: 'Created A',
          dateFrom: DateTime(2026, 4, 8, 9),
        ),
        TestTaskFactory.create(
          id: 'created-b',
          title: 'Created B',
          dateFrom: DateTime(2026, 4, 8, 11),
        ),
        TestTaskFactory.create(
          id: 'created-c',
          title: 'Created C',
          dateFrom: DateTime(2026, 4, 7, 11),
        ),
      ];

      final entries = buildTaskBrowseEntries(
        items: items,
        sortOption: TaskSortOption.byDate,
        now: now,
        hasNextPage: false,
      );

      expect(entries[0].sectionKey.kind, TaskBrowseSectionKind.createdDate);
      expect(entries[0].sectionKey.date, DateTime(2026, 4, 8));
      expect(entries[0].sectionCount, 2);
      expect(entries[1].showSectionHeader, isFalse);
      expect(entries[2].sectionKey.date, DateTime(2026, 4, 7));
      expect(entries[2].showSectionHeader, isTrue);
    });

    test('groups noDueDate when task has no due date', () {
      final now = DateTime(2026, 4, 8, 9);
      final items = <JournalEntity>[
        TestTaskFactory.create(
          id: 'no-due',
          title: 'No Due Date',
          dateFrom: DateTime(2026, 4, 8, 9),
        ).copyWith(
          data: TestTaskDataFactory.create(
            title: 'No Due Date',
            dateFrom: DateTime(2026, 4, 8, 9),
            dateTo: DateTime(2026, 4, 8, 10),
          ),
        ),
      ];

      final entries = buildTaskBrowseEntries(
        items: items,
        sortOption: TaskSortOption.byDueDate,
        now: now,
        hasNextPage: false,
      );

      expect(entries, hasLength(1));
      expect(entries[0].sectionKey.kind, TaskBrowseSectionKind.noDueDate);
    });

    test('groups dueYesterday when task is due yesterday', () {
      final now = DateTime(2026, 4, 8, 9);
      final yesterday = DateTime(2026, 4, 7, 18);
      final items = <JournalEntity>[
        TestTaskFactory.create(
          id: 'yesterday-1',
          title: 'Yesterday 1',
          dateFrom: DateTime(2026, 4, 7, 9),
        ).copyWith(
          data: TestTaskDataFactory.create(
            title: 'Yesterday 1',
            dateFrom: DateTime(2026, 4, 7, 9),
            dateTo: DateTime(2026, 4, 7, 10),
          ).copyWith(due: yesterday),
        ),
      ];

      final entries = buildTaskBrowseEntries(
        items: items,
        sortOption: TaskSortOption.byDueDate,
        now: now,
        hasNextPage: false,
      );

      expect(entries, hasLength(1));
      expect(entries[0].sectionKey.kind, TaskBrowseSectionKind.dueYesterday);
    });
    test(
      'due dates beyond the yesterday/tomorrow window fall into per-day '
      'dueDate sections (the overdue/later catch-all)',
      () {
        final now = DateTime(2026, 4, 8, 9);
        final entries = buildTaskBrowseEntries(
          items: [
            _taskWithDue(
              id: 'overdue-3d',
              title: 'Overdue 3d',
              dateFrom: DateTime(2026, 4, 1, 9),
              due: DateTime(2026, 4, 5, 18),
            ),
            _taskWithDue(
              id: 'later-5d',
              title: 'Later 5d',
              dateFrom: DateTime(2026, 4, 1, 9),
              due: DateTime(2026, 4, 13, 18),
            ),
          ],
          sortOption: TaskSortOption.byDueDate,
          now: now,
          hasNextPage: false,
        );

        // Both rows land in generic per-day dueDate sections — not the
        // today/tomorrow/yesterday specials.
        final keys = entries.map((e) => e.sectionKey.stableKey).toList();
        expect(keys, hasLength(2));
        expect(keys, everyElement(startsWith('due:2026-')));
        expect(keys.toSet(), hasLength(2));
      },
    );

    glados.Glados(
      glados.IntAnys(glados.any).intInRange(-10, 10),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'every due offset maps to exactly one section with the right kind',
      (offset) {
        final now = DateTime(2026, 4, 8, 9);
        final due = DateTime(2026, 4, 8 + offset, 15);
        final entries = buildTaskBrowseEntries(
          items: [
            _taskWithDue(
              id: 'gen-$offset',
              title: 'Gen $offset',
              dateFrom: DateTime(2026, 4, 1, 9),
              due: due,
            ),
          ],
          sortOption: TaskSortOption.byDueDate,
          now: now,
          hasNextPage: false,
        );

        // Partition property: one input task → exactly one entry.
        expect(entries, hasLength(1), reason: 'offset=$offset');
        final kind = entries.single.sectionKey.kind;
        final expected = switch (offset) {
          0 => TaskBrowseSectionKind.dueToday,
          1 => TaskBrowseSectionKind.dueTomorrow,
          -1 => TaskBrowseSectionKind.dueYesterday,
          _ => TaskBrowseSectionKind.dueDate,
        };
        expect(kind, expected, reason: 'offset=$offset');
      },
      tags: 'glados',
    );
  });
}
