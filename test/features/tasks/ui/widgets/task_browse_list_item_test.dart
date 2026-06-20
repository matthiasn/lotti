// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/ui/model/task_browse_models.dart';
import 'package:lotti/features/tasks/ui/widgets/task_browse_list_item.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_shared_widgets.dart';

import '../../../../helpers/entity_factories.dart';
import '../../../../widget_test_utils.dart';
import 'task_browse_list_item_test_helpers.dart';

void main() {
  setUp(setUpTaskBrowse);
  tearDown(tearDownTestGetIt);

  group('Section headers', () {
    testWidgets('renders priority section header with glyph and title', (
      tester,
    ) async {
      final task = TestTaskFactory.create(
        id: 'task-priority',
        title: 'Priority Task',
        dateFrom: DateTime(2026, 4, 8),
      );

      await pumpTaskBrowseItem(
        tester,
        task,
        sectionKey: const TaskBrowseSectionKey.priority(
          TaskPriority.p1High,
        ),
        showSectionHeader: true,
      );

      // The priority section header renders a TaskShowcasePriorityGlyph
      expect(find.byType(TaskShowcasePriorityGlyph), findsAtLeastNWidgets(1));
      // The header shows the plain priority word only — no "P1" code.
      expect(find.text('High'), findsOneWidget);
      expect(find.textContaining('P1'), findsNothing);
    });

    testWidgets('renders dueToday section header', (tester) async {
      final task = TestTaskFactory.create(
        id: 'task-due-today',
        title: 'Due Today Task',
        dateFrom: DateTime(2026, 4, 8),
      );

      await pumpTaskBrowseItem(
        tester,
        task,
        sectionKey: const TaskBrowseSectionKey.dueToday(),
        showSectionHeader: true,
      );

      expect(find.text('Due Today'), findsOneWidget);
    });

    testWidgets('renders dueTomorrow section header', (tester) async {
      final task = TestTaskFactory.create(
        id: 'task-due-tomorrow',
        title: 'Due Tomorrow Task',
        dateFrom: DateTime(2026, 4, 8),
      );

      await pumpTaskBrowseItem(
        tester,
        task,
        sectionKey: const TaskBrowseSectionKey.dueTomorrow(),
        showSectionHeader: true,
      );

      expect(find.text('Due Tomorrow'), findsOneWidget);
    });

    testWidgets('renders dueYesterday section header', (tester) async {
      final task = TestTaskFactory.create(
        id: 'task-due-yesterday',
        title: 'Due Yesterday Task',
        dateFrom: DateTime(2026, 4, 8),
      );

      await pumpTaskBrowseItem(
        tester,
        task,
        sectionKey: const TaskBrowseSectionKey.dueYesterday(),
        showSectionHeader: true,
      );

      expect(find.text('Due Yesterday'), findsOneWidget);
    });

    testWidgets('renders createdDate section header', (tester) async {
      final task = TestTaskFactory.create(
        id: 'task-created-date',
        title: 'Created Date Task',
        dateFrom: DateTime(2026, 4, 8),
      );

      await pumpTaskBrowseItem(
        tester,
        task,
        sectionKey: TaskBrowseSectionKey.createdDate(DateTime(2026, 4, 8)),
        showSectionHeader: true,
      );

      // MaterialLocalizations.formatMediumDate(DateTime(2026, 4, 8)) → "Apr 8, 2026"
      expect(find.textContaining('Apr'), findsAtLeastNWidgets(1));
    });

    testWidgets('renders dueDate section header', (tester) async {
      final task = TestTaskFactory.create(
        id: 'task-due-date',
        title: 'Specific Due Date Task',
        dateFrom: DateTime(2026, 4, 8),
      );

      await pumpTaskBrowseItem(
        tester,
        task,
        sectionKey: TaskBrowseSectionKey.dueDate(DateTime(2026, 4, 15)),
        showSectionHeader: true,
      );

      // "Due: Apr 15, 2026"
      expect(find.textContaining('Due:'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Apr 15'), findsAtLeastNWidgets(1));
    });

    testWidgets('renders noDueDate section header', (tester) async {
      final task = TestTaskFactory.create(
        id: 'task-no-due',
        title: 'No Due Date Task',
        dateFrom: DateTime(2026, 4, 8),
      );

      await pumpTaskBrowseItem(
        tester,
        task,
        sectionKey: const TaskBrowseSectionKey.noDueDate(),
        showSectionHeader: true,
      );

      expect(find.text('No due date'), findsOneWidget);
    });

    testWidgets('renders section count when provided', (tester) async {
      final task = TestTaskFactory.create(
        id: 'task-count',
        title: 'Count Task',
        dateFrom: DateTime(2026, 4, 8),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          TaskBrowseListItem(
            entry: TaskBrowseEntry(
              task: task,
              sectionKey: const TaskBrowseSectionKey.dueToday(),
              showSectionHeader: true,
              isFirstInSection: true,
              isLastInSection: true,
              sectionCount: 5,
            ),
            sortOption: TaskSortOption.byPriority,
            showCreationDate: false,
            showDueDate: false,
            showCoverArt: false,
            trackedDurationLabelOverride: '0h 0m',
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      // "5 tasks" via taskShowcaseTaskCount("{count} tasks")
      expect(find.text('5 tasks'), findsOneWidget);
    });

    testWidgets('renders titleOverride instead of computed section title', (
      tester,
    ) async {
      final task = TestTaskFactory.create(
        id: 'task-override',
        title: 'Override Title Task',
        dateFrom: DateTime(2026, 4, 8),
      );

      await pumpTaskBrowseItem(
        tester,
        task,
        sectionKey: const TaskBrowseSectionKey.dueToday(),
        showSectionHeader: true,
        sectionHeaderTitleOverride: 'My Custom Header',
      );

      expect(find.text('My Custom Header'), findsOneWidget);
      // "Due Today" should NOT appear since override takes precedence
      expect(find.text('Due Today'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // Footer chips
  // -------------------------------------------------------------------------

  group('Footer chips', () {
    testWidgets(
      'shows creation date chip when showCreationDate is true and sortOption is not byDate',
      (
        tester,
      ) async {
        final task = TestTaskFactory.create(
          id: 'task-creation-date',
          title: 'Task With Creation Date',
          dateFrom: DateTime(2026, 4, 8),
        );

        await pumpTaskBrowseItem(
          tester,
          task,
          sortOption: TaskSortOption.byPriority,
          showCreationDate: true,
        );

        // TaskShowcaseMetaChip with calendar icon represents the creation date
        final chips = tester.widgetList<TaskShowcaseMetaChip>(
          find.byType(TaskShowcaseMetaChip),
        );
        final dateChips = chips
            .where((c) => c.icon == Icons.calendar_today_outlined)
            .toList();
        expect(dateChips, hasLength(1));
      },
    );

    testWidgets('hides creation date chip when sortOption is byDate', (
      tester,
    ) async {
      final task = TestTaskFactory.create(
        id: 'task-by-date',
        title: 'Task Sorted By Date',
        dateFrom: DateTime(2026, 4, 8),
      );

      await pumpTaskBrowseItem(
        tester,
        task,
        sortOption: TaskSortOption.byDate,
        showCreationDate: true,
      );

      final chips = tester.widgetList<TaskShowcaseMetaChip>(
        find.byType(TaskShowcaseMetaChip),
      );
      final dateChips = chips
          .where((c) => c.icon == Icons.calendar_today_outlined)
          .toList();
      expect(dateChips, isEmpty);
    });

    testWidgets(
      'shows due date chip when conditions are met (open task, showDueDate, byPriority sort)',
      (tester) async {
        final openStatus = TaskStatus.open(
          id: 'status-1',
          createdAt: DateTime(2024),
          utcOffset: 0,
        );
        final task =
            TestTaskFactory.create(
              id: 'task-due',
              title: 'Task With Due Date',
              dateFrom: DateTime(2026, 4, 8),
              status: openStatus,
            ).copyWith(
              data: TestTaskDataFactory.create(
                title: 'Task With Due Date',
                status: openStatus,
              ).copyWith(due: DateTime(2026, 4, 20)),
            );

        await pumpTaskBrowseItem(
          tester,
          task,
          sortOption: TaskSortOption.byPriority,
          showDueDate: true,
        );

        // DueDateText is rendered as a widget in the footer
        expect(find.byIcon(Icons.event_rounded), findsAtLeastNWidgets(1));
      },
    );

    testWidgets('hides due date chip when task is done', (tester) async {
      final doneStatus = TaskStatus.done(
        id: 'status-done',
        createdAt: DateTime(2024),
        utcOffset: 0,
      );
      final task =
          TestTaskFactory.create(
            id: 'task-done',
            title: 'Done Task',
            dateFrom: DateTime(2026, 4, 8),
            status: doneStatus,
          ).copyWith(
            data: TestTaskDataFactory.create(
              title: 'Done Task',
              status: doneStatus,
            ).copyWith(due: DateTime(2026, 4, 20)),
          );

      await pumpTaskBrowseItem(
        tester,
        task,
        sortOption: TaskSortOption.byPriority,
        showDueDate: true,
      );

      // DueDateText should NOT appear for done tasks
      expect(find.byIcon(Icons.event_rounded), findsNothing);
    });

    testWidgets('hides due date chip when task is rejected', (tester) async {
      final rejectedStatus = TaskStatus.rejected(
        id: 'status-rejected',
        createdAt: DateTime(2024),
        utcOffset: 0,
      );
      final task =
          TestTaskFactory.create(
            id: 'task-rejected',
            title: 'Rejected Task',
            dateFrom: DateTime(2026, 4, 8),
            status: rejectedStatus,
          ).copyWith(
            data: TestTaskDataFactory.create(
              title: 'Rejected Task',
              status: rejectedStatus,
            ).copyWith(due: DateTime(2026, 4, 20)),
          );

      await pumpTaskBrowseItem(
        tester,
        task,
        sortOption: TaskSortOption.byPriority,
        showDueDate: true,
      );

      expect(find.byIcon(Icons.event_rounded), findsNothing);
    });

    testWidgets('hides due date chip when sortOption is byDueDate', (
      tester,
    ) async {
      final openStatus = TaskStatus.open(
        id: 'status-2',
        createdAt: DateTime(2024),
        utcOffset: 0,
      );
      final task =
          TestTaskFactory.create(
            id: 'task-by-due-date',
            title: 'Task With Due Date (byDueDate sort)',
            dateFrom: DateTime(2026, 4, 8),
            status: openStatus,
          ).copyWith(
            data: TestTaskDataFactory.create(
              title: 'Task With Due Date (byDueDate sort)',
              status: openStatus,
            ).copyWith(due: DateTime(2026, 4, 20)),
          );

      await pumpTaskBrowseItem(
        tester,
        task,
        sortOption: TaskSortOption.byDueDate,
        showDueDate: true,
      );

      expect(find.byIcon(Icons.event_rounded), findsNothing);
    });

    testWidgets('shows vector distance chip when vectorDistance is provided', (
      tester,
    ) async {
      final task = TestTaskFactory.create(
        id: 'task-vector',
        title: 'Task With Vector Distance',
        dateFrom: DateTime(2026, 4, 8),
      );

      await pumpTaskBrowseItem(tester, task, vectorDistance: 0.42);

      // TaskShowcaseMetaChip with hub icon for vector distance
      final chips = tester.widgetList<TaskShowcaseMetaChip>(
        find.byType(TaskShowcaseMetaChip),
      );
      final vectorChips = chips
          .where((c) => c.icon == Icons.hub_outlined)
          .toList();
      expect(vectorChips, hasLength(1));
      // The label is distance.toStringAsFixed(2) = "0.42"
      expect(vectorChips.first.label, '0.42');
    });

    testWidgets('hides vector distance chip when not provided', (tester) async {
      final task = TestTaskFactory.create(
        id: 'task-no-vector',
        title: 'Task Without Vector Distance',
        dateFrom: DateTime(2026, 4, 8),
      );

      await pumpTaskBrowseItem(tester, task, vectorDistance: null);

      final chips = tester.widgetList<TaskShowcaseMetaChip>(
        find.byType(TaskShowcaseMetaChip),
      );
      final vectorChips = chips
          .where((c) => c.icon == Icons.hub_outlined)
          .toList();
      expect(vectorChips, isEmpty);
    });
  });

  group('Tracked duration', () {
    testWidgets('renders the tracked-duration chip for a non-zero override', (
      tester,
    ) async {
      final task = TestTaskFactory.create(
        id: 'task-tracked',
        title: 'Tracked Task',
        dateFrom: DateTime(2026, 4, 8),
      );

      await pumpTaskBrowseItem(
        tester,
        task,
        trackedDurationLabelOverride: '1h 30m',
      );

      expect(find.byIcon(Icons.timelapse_rounded), findsOneWidget);
      expect(find.text('1h 30m'), findsOneWidget);
    });

    testWidgets('suppresses the chip when the override is a zero duration', (
      tester,
    ) async {
      final task = TestTaskFactory.create(
        id: 'task-tracked-zero',
        title: 'Untracked Task',
        dateFrom: DateTime(2026, 4, 8),
      );

      // "0h 0m" equals designSystemMyDailyDurationHoursMinutesCompact(0, 0), so
      // it must be suppressed rather than cluttering an untouched task's row.
      await pumpTaskBrowseItem(
        tester,
        task,
        trackedDurationLabelOverride: '0h 0m',
      );

      expect(find.byIcon(Icons.timelapse_rounded), findsNothing);
      expect(find.text('0h 0m'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // Cover art
  // -------------------------------------------------------------------------
}
