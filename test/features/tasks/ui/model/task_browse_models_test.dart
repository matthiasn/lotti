import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/ui/model/task_browse_models.dart';

import '../../../../helpers/entity_factories.dart';

void main() {
  group('buildTaskBrowseEntries', () {
    test(
      'groups due-date sort into due buckets and hides partial trailing count',
      () {
        final now = DateTime(2026, 4, 8, 9);
        final items = <JournalEntity>[
          TestTaskFactory.create(
            id: 'today-1',
            title: 'Today 1',
            dateFrom: DateTime(2026, 4, 8, 9),
          ).copyWith(
            data: TestTaskDataFactory.create(
              title: 'Today 1',
              dateFrom: DateTime(2026, 4, 8, 9),
              dateTo: DateTime(2026, 4, 8, 10),
            ).copyWith(due: DateTime(2026, 4, 8, 18)),
          ),
          TestTaskFactory.create(
            id: 'today-2',
            title: 'Today 2',
            dateFrom: DateTime(2026, 4, 8, 11),
          ).copyWith(
            data: TestTaskDataFactory.create(
              title: 'Today 2',
              dateFrom: DateTime(2026, 4, 8, 11),
              dateTo: DateTime(2026, 4, 8, 12),
            ).copyWith(due: DateTime(2026, 4, 8, 20)),
          ),
          TestTaskFactory.create(
            id: 'tomorrow-1',
            title: 'Tomorrow 1',
            dateFrom: DateTime(2026, 4, 7, 11),
          ).copyWith(
            data: TestTaskDataFactory.create(
              title: 'Tomorrow 1',
              dateFrom: DateTime(2026, 4, 7, 11),
              dateTo: DateTime(2026, 4, 7, 12),
            ).copyWith(due: DateTime(2026, 4, 9, 9)),
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
  });
}
