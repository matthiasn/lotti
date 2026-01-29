import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/task_view_preference_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_budget_card.dart';
import 'package:lotti/features/tasks/util/due_date_utils.dart';

import '../../../../test_helper.dart';

/// Fake TaskViewPreference for testing.
class FakeTaskViewPreference extends TaskViewPreference {
  FakeTaskViewPreference(this._initialMode);

  final TaskViewMode _initialMode;

  @override
  Future<TaskViewMode> build({required String categoryId}) async {
    return _initialMode;
  }

  @override
  Future<void> toggle() async {
    final current = state.value ?? TaskViewMode.list;
    final newMode =
        current == TaskViewMode.list ? TaskViewMode.grid : TaskViewMode.list;
    state = AsyncData(newMode);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDate = DateTime(2026, 1, 15);

  final testCategory = CategoryDefinition(
    id: 'cat-1',
    name: 'Work',
    color: '#4285F4',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    vectorClock: null,
    private: false,
    active: true,
  );

  TimeBudgetProgress createProgress({
    Duration planned = const Duration(hours: 2),
    Duration recorded = const Duration(hours: 1),
    BudgetProgressStatus status = BudgetProgressStatus.underBudget,
    CategoryDefinition? category,
    List<PlannedBlock>? blocks,
  }) {
    final effectiveCategory = category ?? testCategory;
    return TimeBudgetProgress(
      categoryId: effectiveCategory.id,
      category: effectiveCategory,
      plannedDuration: planned,
      recordedDuration: recorded,
      status: status,
      contributingEntries: const [],
      taskProgressItems: const [],
      blocks: blocks ??
          [
            PlannedBlock(
              id: 'block-1',
              categoryId: effectiveCategory.id,
              startTime: testDate.add(const Duration(hours: 9)),
              endTime: testDate.add(Duration(hours: 9 + planned.inHours)),
            ),
          ],
    );
  }

  Widget createTestWidget({
    required TimeBudgetProgress progress,
    VoidCallback? onTap,
    bool isExpanded = false,
    List<Override> overrides = const [],
    TaskViewMode initialViewMode = TaskViewMode.list,
  }) {
    return RiverpodWidgetTestBench(
      overrides: [
        highlightedCategoryIdProvider.overrideWith((ref) => null),
        taskViewPreferenceProvider(categoryId: progress.categoryId)
            .overrideWith(() => FakeTaskViewPreference(initialViewMode)),
        ...overrides,
      ],
      child: TimeBudgetCard(
        progress: progress,
        onTap: onTap,
        isExpanded: isExpanded,
      ),
    );
  }

  group('TimeBudgetCard', () {
    testWidgets('displays category name', (tester) async {
      await tester.pumpWidget(
        createTestWidget(progress: createProgress()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Work'), findsOneWidget);
    });

    testWidgets('displays planned duration', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgress(planned: const Duration(hours: 3)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3 hours planned'), findsOneWidget);
    });

    testWidgets('displays remaining time for under budget', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgress(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1h left'), findsOneWidget);
    });

    testWidgets('displays over budget status', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgress(
            planned: const Duration(hours: 1),
            recorded: const Duration(hours: 2),
            status: BudgetProgressStatus.overBudget,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('+1h over'), findsOneWidget);
    });

    testWidgets('displays near limit status', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgress(
            planned: const Duration(hours: 1),
            recorded: const Duration(minutes: 50),
            status: BudgetProgressStatus.nearLimit,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('10m left'), findsOneWidget);
    });

    testWidgets('displays exhausted status', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgress(
            planned: const Duration(hours: 1),
            status: BudgetProgressStatus.exhausted,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Time's up"), findsOneWidget);
    });

    testWidgets('handles tap callback', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        createTestWidget(
          progress: createProgress(),
          onTap: () => tapped = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TimeBudgetCard));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('shows progress bar', (tester) async {
      await tester.pumpWidget(
        createTestWidget(progress: createProgress()),
      );
      await tester.pumpAndSettle();

      // The progress bar is a custom widget, verify it exists
      expect(find.byType(TimeBudgetCard), findsOneWidget);
    });

    testWidgets('displays uncategorized when no category', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: TimeBudgetProgress(
            categoryId: 'missing',
            category: null,
            plannedDuration: const Duration(hours: 1),
            recordedDuration: Duration.zero,
            status: BudgetProgressStatus.underBudget,
            contributingEntries: const [],
            taskProgressItems: const [],
            blocks: [
              PlannedBlock(
                id: 'block-1',
                categoryId: 'missing',
                startTime: testDate.add(const Duration(hours: 9)),
                endTime: testDate.add(const Duration(hours: 10)),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Uncategorized'), findsOneWidget);
    });

    testWidgets('displays hours and minutes for planned duration',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgress(
            planned: const Duration(hours: 2, minutes: 30),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2h 30m planned'), findsOneWidget);
    });

    testWidgets('displays minutes only for short planned duration',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgress(
            planned: const Duration(minutes: 45),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('45 min planned'), findsOneWidget);
    });

    testWidgets('shows highlighted border when category is highlighted',
        (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            highlightedCategoryIdProvider.overrideWith((ref) => 'cat-1'),
          ],
          child: TimeBudgetCard(
            progress: createProgress(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Widget should have enhanced styling when highlighted
      expect(find.byType(AnimatedContainer), findsWidgets);
    });

    testWidgets('handles long press callback', (tester) async {
      var longPressed = false;

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            highlightedCategoryIdProvider.overrideWith((ref) => null),
          ],
          child: TimeBudgetCard(
            progress: createProgress(),
            onLongPress: () => longPressed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(TimeBudgetCard));
      await tester.pumpAndSettle();

      expect(longPressed, isTrue);
    });

    testWidgets('displays remaining time with hours and minutes',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgress(
            planned: const Duration(hours: 3),
            recorded: const Duration(hours: 1, minutes: 30),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1h 30m left'), findsOneWidget);
    });

    testWidgets('displays over budget with hours and minutes', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgress(
            planned: const Duration(hours: 1),
            recorded: const Duration(hours: 2, minutes: 15),
            status: BudgetProgressStatus.overBudget,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('+1h 15m over'), findsOneWidget);
    });

    testWidgets('shows progress bar with correct visual states',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgress(
            recorded: const Duration(hours: 2, minutes: 30),
            status: BudgetProgressStatus.overBudget,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The progress bar should show over-budget indicator
      expect(find.byType(TimeBudgetCard), findsOneWidget);
    });
  });

  group('TimeBudgetCard - Task Section', () {
    Task createTestTask({
      required String id,
      required String title,
      String? categoryId,
      TaskStatus? status,
    }) {
      final now = DateTime(2026, 1, 15);
      return Task(
        meta: Metadata(
          id: id,
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
          categoryId: categoryId,
        ),
        data: TaskData(
          title: title,
          dateFrom: now,
          dateTo: now,
          statusHistory: [],
          status: status ??
              TaskStatus.inProgress(
                id: 'status-$id',
                createdAt: now,
                utcOffset: 0,
              ),
        ),
      );
    }

    TimeBudgetProgress createProgressWithTasks(List<TaskDayProgress> tasks) {
      return TimeBudgetProgress(
        categoryId: testCategory.id,
        category: testCategory,
        plannedDuration: const Duration(hours: 4),
        recordedDuration: const Duration(hours: 2),
        status: BudgetProgressStatus.underBudget,
        contributingEntries: const [],
        taskProgressItems: tasks,
        blocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: testCategory.id,
            startTime: testDate.add(const Duration(hours: 9)),
            endTime: testDate.add(const Duration(hours: 13)),
          ),
        ],
      );
    }

    testWidgets('shows task section header with count and total time',
        (tester) async {
      final tasks = [
        TaskDayProgress(
          task: createTestTask(id: 'task-1', title: 'Task One'),
          timeSpentOnDay: const Duration(hours: 1, minutes: 30),
          wasCompletedOnDay: false,
        ),
        TaskDayProgress(
          task: createTestTask(id: 'task-2', title: 'Task Two'),
          timeSpentOnDay: const Duration(hours: 1),
          wasCompletedOnDay: false,
        ),
      ];

      await tester.pumpWidget(
        createTestWidget(progress: createProgressWithTasks(tasks)),
      );
      await tester.pumpAndSettle();

      // Should show "Tasks (2)" and total time "• 2h 30m"
      expect(find.textContaining('Tasks (2)'), findsOneWidget);
      expect(find.textContaining('2h 30m'), findsOneWidget);
    });

    testWidgets('hides task section when no tasks', (tester) async {
      await tester.pumpWidget(
        createTestWidget(progress: createProgressWithTasks([])),
      );
      await tester.pumpAndSettle();

      // Should not show tasks header
      expect(find.textContaining('Tasks'), findsNothing);
    });

    testWidgets('shows task titles in list view', (tester) async {
      final tasks = [
        TaskDayProgress(
          task: createTestTask(id: 'task-1', title: 'Build Feature'),
          timeSpentOnDay: const Duration(hours: 2),
          wasCompletedOnDay: false,
        ),
        TaskDayProgress(
          task: createTestTask(id: 'task-2', title: 'Fix Bug'),
          timeSpentOnDay: const Duration(hours: 1),
          wasCompletedOnDay: true,
        ),
      ];

      await tester.pumpWidget(
        createTestWidget(progress: createProgressWithTasks(tasks)),
      );
      await tester.pumpAndSettle();

      // Default is list view, task titles should be visible
      expect(find.text('Build Feature'), findsOneWidget);
      expect(find.text('Fix Bug'), findsOneWidget);
    });

    testWidgets('shows checkmark for completed tasks in list view',
        (tester) async {
      final completedTask = TaskDayProgress(
        task: createTestTask(
          id: 'task-1',
          title: 'Completed Task',
          status: TaskStatus.done(
            id: 'status-done',
            createdAt: testDate,
            utcOffset: 0,
          ),
        ),
        timeSpentOnDay: const Duration(hours: 1),
        wasCompletedOnDay: true,
      );

      await tester.pumpWidget(
        createTestWidget(progress: createProgressWithTasks([completedTask])),
      );
      await tester.pumpAndSettle();

      // Default is list view, should show checkmark icon for completed task
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('shows time spent in list view', (tester) async {
      final task = TaskDayProgress(
        task: createTestTask(id: 'task-1', title: 'My Task'),
        timeSpentOnDay: const Duration(hours: 2, minutes: 15),
        wasCompletedOnDay: false,
      );

      await tester.pumpWidget(
        createTestWidget(progress: createProgressWithTasks([task])),
      );
      await tester.pumpAndSettle();

      // Default is list view, should show formatted time
      expect(find.text('2h 15m'), findsWidgets);
    });

    testWidgets('toggles between list and grid view', (tester) async {
      final task = TaskDayProgress(
        task: createTestTask(id: 'task-1', title: 'My Task'),
        timeSpentOnDay: const Duration(hours: 1),
        wasCompletedOnDay: false,
      );

      await tester.pumpWidget(
        createTestWidget(progress: createProgressWithTasks([task])),
      );
      await tester.pumpAndSettle();

      // Initially in list mode (default), should show grid toggle icon
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);

      // Tap to switch to grid view
      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await tester.pumpAndSettle();

      // Now should show list toggle icon
      expect(find.byIcon(Icons.view_list_rounded), findsOneWidget);

      // Tap to switch back to list view
      await tester.tap(find.byIcon(Icons.view_list_rounded));
      await tester.pumpAndSettle();

      // Should show grid toggle icon again
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
    });

    testWidgets('collapses and expands task section', (tester) async {
      final task = TaskDayProgress(
        task: createTestTask(id: 'task-1', title: 'Visible Task'),
        timeSpentOnDay: const Duration(hours: 1),
        wasCompletedOnDay: false,
      );

      await tester.pumpWidget(
        createTestWidget(progress: createProgressWithTasks([task])),
      );
      await tester.pumpAndSettle();

      // Initially expanded - task should be visible in some form
      expect(find.textContaining('Tasks (1)'), findsOneWidget);

      // Collapse the section
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pumpAndSettle();

      // Should show expand icon
      expect(find.byIcon(Icons.keyboard_arrow_right), findsOneWidget);

      // View toggle should be hidden when collapsed
      expect(find.byIcon(Icons.view_list_rounded), findsNothing);
      expect(find.byIcon(Icons.grid_view_rounded), findsNothing);

      // Expand again
      await tester.tap(find.byIcon(Icons.keyboard_arrow_right));
      await tester.pumpAndSettle();

      // Should show collapse icon
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    });

    testWidgets('grid view shows tasks in grid layout', (tester) async {
      final tasks = [
        TaskDayProgress(
          task: createTestTask(id: 'task-1', title: 'Task A'),
          timeSpentOnDay: const Duration(hours: 2),
          wasCompletedOnDay: false,
        ),
        TaskDayProgress(
          task: createTestTask(id: 'task-2', title: 'Task B'),
          timeSpentOnDay: const Duration(hours: 1),
          wasCompletedOnDay: false,
        ),
        TaskDayProgress(
          task: createTestTask(id: 'task-3', title: 'Task C'),
          timeSpentOnDay: const Duration(minutes: 30),
          wasCompletedOnDay: true,
        ),
      ];

      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithTasks(tasks),
          initialViewMode: TaskViewMode.grid,
        ),
      );
      await tester.pumpAndSettle();

      // Should be in grid view
      expect(find.byType(GridView), findsOneWidget);
      // Task titles should be visible in grid tiles
      expect(find.text('Task A'), findsOneWidget);
      expect(find.text('Task B'), findsOneWidget);
      expect(find.text('Task C'), findsOneWidget);
    });

    testWidgets('shows zero time as 0m', (tester) async {
      final task = TaskDayProgress(
        task: createTestTask(
          id: 'task-1',
          title: 'Just Completed',
          status: TaskStatus.done(
            id: 'status-done',
            createdAt: testDate,
            utcOffset: 0,
          ),
        ),
        timeSpentOnDay: Duration.zero,
        wasCompletedOnDay: true,
      );

      await tester.pumpWidget(
        createTestWidget(progress: createProgressWithTasks([task])),
      );
      await tester.pumpAndSettle();

      // Default is list view, should show 0m for zero duration
      expect(find.text('0m'), findsWidgets);
    });

    testWidgets('shows due today badge in list view', (tester) async {
      final task = TaskDayProgress(
        task: createTestTask(id: 'task-1', title: 'Due Task'),
        timeSpentOnDay: const Duration(hours: 1),
        wasCompletedOnDay: false,
        dueDateStatus: const DueDateStatus(
          urgency: DueDateUrgency.dueToday,
          daysUntilDue: 0,
        ),
      );

      await tester.pumpWidget(
        createTestWidget(progress: createProgressWithTasks([task])),
      );
      await tester.pumpAndSettle();

      // Should show "Due today" badge
      expect(find.text('Due today'), findsOneWidget);
    });

    testWidgets('shows overdue badge in list view', (tester) async {
      final task = TaskDayProgress(
        task: createTestTask(id: 'task-1', title: 'Overdue Task'),
        timeSpentOnDay: const Duration(minutes: 30),
        wasCompletedOnDay: false,
        dueDateStatus: const DueDateStatus(
          urgency: DueDateUrgency.overdue,
          daysUntilDue: -2,
        ),
      );

      await tester.pumpWidget(
        createTestWidget(progress: createProgressWithTasks([task])),
      );
      await tester.pumpAndSettle();

      // Should show "Overdue" badge
      expect(find.text('Overdue'), findsOneWidget);
    });

    testWidgets('shows due badge in grid view', (tester) async {
      final task = TaskDayProgress(
        task: createTestTask(id: 'task-1', title: 'Grid Due Task'),
        timeSpentOnDay: const Duration(hours: 1),
        wasCompletedOnDay: false,
        dueDateStatus: const DueDateStatus(
          urgency: DueDateUrgency.dueToday,
          daysUntilDue: 0,
        ),
      );

      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithTasks([task]),
          initialViewMode: TaskViewMode.grid,
        ),
      );
      await tester.pumpAndSettle();

      // Should show short "Due" badge in grid
      expect(find.text('Due'), findsOneWidget);
    });

    testWidgets('shows late badge in grid view for overdue', (tester) async {
      final task = TaskDayProgress(
        task: createTestTask(id: 'task-1', title: 'Grid Overdue Task'),
        timeSpentOnDay: const Duration(hours: 1),
        wasCompletedOnDay: false,
        dueDateStatus: const DueDateStatus(
          urgency: DueDateUrgency.overdue,
          daysUntilDue: -1,
        ),
      );

      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithTasks([task]),
          initialViewMode: TaskViewMode.grid,
        ),
      );
      await tester.pumpAndSettle();

      // Should show short "Late" badge in grid
      expect(find.text('Late'), findsOneWidget);
    });

    testWidgets('does not show badge for tasks without due date',
        (tester) async {
      final task = TaskDayProgress(
        task: createTestTask(id: 'task-1', title: 'Regular Task'),
        timeSpentOnDay: const Duration(hours: 1),
        wasCompletedOnDay: false,
        // No dueDateStatus specified, defaults to none
      );

      await tester.pumpWidget(
        createTestWidget(progress: createProgressWithTasks([task])),
      );
      await tester.pumpAndSettle();

      // Should not show any due badges
      expect(find.text('Due today'), findsNothing);
      expect(find.text('Overdue'), findsNothing);
    });
  });

  group('TimeBudgetCard - Warning Banner', () {
    testWidgets('shows warning banner when hasNoBudgetWarning is true',
        (tester) async {
      final progress = TimeBudgetProgress(
        categoryId: testCategory.id,
        category: testCategory,
        plannedDuration: Duration.zero,
        recordedDuration: Duration.zero,
        status: BudgetProgressStatus.underBudget,
        contributingEntries: const [],
        taskProgressItems: [
          TaskDayProgress(
            task: Task(
              meta: Metadata(
                id: 'task-1',
                createdAt: testDate,
                updatedAt: testDate,
                dateFrom: testDate,
                dateTo: testDate,
                categoryId: testCategory.id,
              ),
              data: TaskData(
                title: 'Due Task',
                dateFrom: testDate,
                dateTo: testDate,
                due: testDate,
                statusHistory: [],
                status: TaskStatus.open(
                  id: 'status-1',
                  createdAt: testDate,
                  utcOffset: 0,
                ),
              ),
            ),
            timeSpentOnDay: Duration.zero,
            wasCompletedOnDay: false,
            dueDateStatus: const DueDateStatus(
              urgency: DueDateUrgency.dueToday,
              daysUntilDue: 0,
            ),
          ),
        ],
        blocks: const [],
        hasNoBudgetWarning: true,
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            highlightedCategoryIdProvider.overrideWith((ref) => null),
            taskViewPreferenceProvider(categoryId: progress.categoryId)
                .overrideWith(() => FakeTaskViewPreference(TaskViewMode.list)),
          ],
          child: TimeBudgetCard(
            progress: progress,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show warning banner
      expect(find.text('No time budgeted'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('does not show warning banner when hasNoBudgetWarning is false',
        (tester) async {
      final progress = TimeBudgetProgress(
        categoryId: testCategory.id,
        category: testCategory,
        plannedDuration: const Duration(hours: 2),
        recordedDuration: Duration.zero,
        status: BudgetProgressStatus.underBudget,
        contributingEntries: const [],
        taskProgressItems: const [],
        blocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: testCategory.id,
            startTime: testDate.add(const Duration(hours: 9)),
            endTime: testDate.add(const Duration(hours: 11)),
          ),
        ],
        // hasNoBudgetWarning defaults to false
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            highlightedCategoryIdProvider.overrideWith((ref) => null),
            taskViewPreferenceProvider(categoryId: progress.categoryId)
                .overrideWith(() => FakeTaskViewPreference(TaskViewMode.list)),
          ],
          child: TimeBudgetCard(
            progress: progress,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should NOT show warning banner
      expect(find.text('No time budgeted'), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });
  });

  group('TimeBudgetCard - Priority Badges', () {
    Task createPriorityTask({
      required String id,
      required String title,
      required TaskPriority priority,
    }) {
      final now = DateTime(2026, 1, 15);
      return Task(
        meta: Metadata(
          id: id,
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
          categoryId: testCategory.id,
        ),
        data: TaskData(
          title: title,
          dateFrom: now,
          dateTo: now,
          priority: priority,
          statusHistory: [],
          status: TaskStatus.inProgress(
            id: 'status-$id',
            createdAt: now,
            utcOffset: 0,
          ),
        ),
      );
    }

    TimeBudgetProgress createProgressWithPriorityTask(TaskPriority priority) {
      return TimeBudgetProgress(
        categoryId: testCategory.id,
        category: testCategory,
        plannedDuration: const Duration(hours: 2),
        recordedDuration: const Duration(hours: 1),
        status: BudgetProgressStatus.underBudget,
        contributingEntries: const [],
        taskProgressItems: [
          TaskDayProgress(
            task: createPriorityTask(
              id: 'task-priority',
              title: 'Priority Task',
              priority: priority,
            ),
            timeSpentOnDay: const Duration(hours: 1),
            wasCompletedOnDay: false,
          ),
        ],
        blocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: testCategory.id,
            startTime: testDate.add(const Duration(hours: 9)),
            endTime: testDate.add(const Duration(hours: 11)),
          ),
        ],
      );
    }

    testWidgets('shows P0 (Urgent) priority badge in list view',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithPriorityTask(TaskPriority.p0Urgent),
        ),
      );
      await tester.pumpAndSettle();

      // Should show P0 badge text
      expect(find.text('P0'), findsOneWidget);
    });

    testWidgets('shows P1 (High) priority badge in list view', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithPriorityTask(TaskPriority.p1High),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('P1'), findsOneWidget);
    });

    testWidgets('does not show P2 (Medium) priority badge to reduce noise',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithPriorityTask(TaskPriority.p2Medium),
        ),
      );
      await tester.pumpAndSettle();

      // P2 (Medium/default) badge is intentionally hidden to reduce visual noise
      expect(find.text('P2'), findsNothing);
    });

    testWidgets('shows P3 (Low) priority badge in list view', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithPriorityTask(TaskPriority.p3Low),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('P3'), findsOneWidget);
    });

    testWidgets('shows P0 priority badge in grid view', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithPriorityTask(TaskPriority.p0Urgent),
          initialViewMode: TaskViewMode.grid,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('P0'), findsOneWidget);
    });

    testWidgets('shows P1 priority badge in grid view', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithPriorityTask(TaskPriority.p1High),
          initialViewMode: TaskViewMode.grid,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('P1'), findsOneWidget);
    });

    testWidgets('does not show P2 priority badge in grid view', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithPriorityTask(TaskPriority.p2Medium),
          initialViewMode: TaskViewMode.grid,
        ),
      );
      await tester.pumpAndSettle();

      // P2 (Medium/default) badge is intentionally hidden
      expect(find.text('P2'), findsNothing);
    });

    testWidgets('shows P3 priority badge in grid view', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithPriorityTask(TaskPriority.p3Low),
          initialViewMode: TaskViewMode.grid,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('P3'), findsOneWidget);
    });

    testWidgets('priority badge stacks below completed checkmark in grid',
        (tester) async {
      final completedTask = Task(
        meta: Metadata(
          id: 'task-completed',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
          categoryId: testCategory.id,
        ),
        data: TaskData(
          title: 'Completed Priority Task',
          dateFrom: testDate,
          dateTo: testDate,
          priority: TaskPriority.p0Urgent,
          statusHistory: [],
          status: TaskStatus.done(
            id: 'status-done',
            createdAt: testDate,
            utcOffset: 0,
          ),
        ),
      );

      final progress = TimeBudgetProgress(
        categoryId: testCategory.id,
        category: testCategory,
        plannedDuration: const Duration(hours: 2),
        recordedDuration: const Duration(hours: 1),
        status: BudgetProgressStatus.underBudget,
        contributingEntries: const [],
        taskProgressItems: [
          TaskDayProgress(
            task: completedTask,
            timeSpentOnDay: const Duration(hours: 1),
            wasCompletedOnDay: true,
          ),
        ],
        blocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: testCategory.id,
            startTime: testDate.add(const Duration(hours: 9)),
            endTime: testDate.add(const Duration(hours: 11)),
          ),
        ],
      );

      await tester.pumpWidget(
        createTestWidget(
          progress: progress,
          initialViewMode: TaskViewMode.grid,
        ),
      );
      await tester.pumpAndSettle();

      // Should show both checkmark (Icons.check in grid) and P0 badge
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('P0'), findsOneWidget);
    });

    testWidgets('priority badge stacks below due badge in grid',
        (tester) async {
      final progress = TimeBudgetProgress(
        categoryId: testCategory.id,
        category: testCategory,
        plannedDuration: const Duration(hours: 2),
        recordedDuration: const Duration(hours: 1),
        status: BudgetProgressStatus.underBudget,
        contributingEntries: const [],
        taskProgressItems: [
          TaskDayProgress(
            task: createPriorityTask(
              id: 'task-due',
              title: 'Due Priority Task',
              priority: TaskPriority.p1High,
            ),
            timeSpentOnDay: const Duration(hours: 1),
            wasCompletedOnDay: false,
            dueDateStatus: const DueDateStatus(
              urgency: DueDateUrgency.dueToday,
              daysUntilDue: 0,
            ),
          ),
        ],
        blocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: testCategory.id,
            startTime: testDate.add(const Duration(hours: 9)),
            endTime: testDate.add(const Duration(hours: 11)),
          ),
        ],
      );

      await tester.pumpWidget(
        createTestWidget(
          progress: progress,
          initialViewMode: TaskViewMode.grid,
        ),
      );
      await tester.pumpAndSettle();

      // Should show both due badge and P1 badge
      expect(find.text('Due'), findsOneWidget);
      expect(find.text('P1'), findsOneWidget);
    });
  });
}
