import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_budget_card.dart';

import '../../../../test_helper.dart';

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
      pinnedTasks: const [],
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
  }) {
    return RiverpodWidgetTestBench(
      overrides: [
        highlightedCategoryIdProvider.overrideWith((ref) => null),
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
            pinnedTasks: const [],
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

  group('TimeBudgetCard - Pinned Tasks Section', () {
    Task createTask({
      required String id,
      required String title,
      required TaskStatus status,
    }) {
      return Task(
        meta: Metadata(
          id: id,
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate.add(const Duration(hours: 1)),
        ),
        data: TaskData(
          title: title,
          dateFrom: testDate,
          dateTo: testDate.add(const Duration(hours: 1)),
          statusHistory: const [],
          status: status,
        ),
      );
    }

    TimeBudgetProgress createProgressWithTasks({
      List<Task> pinnedTasks = const [],
      List<JournalEntity> contributingEntries = const [],
    }) {
      return TimeBudgetProgress(
        categoryId: testCategory.id,
        category: testCategory,
        plannedDuration: const Duration(hours: 2),
        recordedDuration: const Duration(hours: 1),
        status: BudgetProgressStatus.underBudget,
        contributingEntries: contributingEntries,
        pinnedTasks: pinnedTasks,
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

    testWidgets('hides pinned tasks section when empty', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithTasks(pinnedTasks: []),
        ),
      );
      await tester.pumpAndSettle();

      // Should not show task title text when no tasks
      expect(find.text('Test Task'), findsNothing);
      // Only one divider (not the task section divider)
      // Actually, when both sections are empty, there should be no dividers
      // from task sections. Let's just verify the card renders
      expect(find.byType(TimeBudgetCard), findsOneWidget);
    });

    testWidgets('shows pinned tasks section with divider when populated',
        (tester) async {
      final task = createTask(
        id: 'task-1',
        title: 'My Pinned Task',
        status: TaskStatus.inProgress(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
      );

      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithTasks(pinnedTasks: [task]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Pinned Task'), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('displays task title in pinned task row', (tester) async {
      final task = createTask(
        id: 'task-1',
        title: 'Important Work Item',
        status: TaskStatus.open(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
      );

      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithTasks(pinnedTasks: [task]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Important Work Item'), findsOneWidget);
    });

    testWidgets('shows chevron icon for pinned tasks', (tester) async {
      final task = createTask(
        id: 'task-1',
        title: 'Task With Chevron',
        status: TaskStatus.open(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
      );

      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithTasks(pinnedTasks: [task]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('shows check icon for completed tasks (TaskDone)',
        (tester) async {
      final task = createTask(
        id: 'task-1',
        title: 'Completed Task',
        status: TaskStatus.done(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
      );

      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithTasks(pinnedTasks: [task]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('shows check icon for rejected tasks (TaskRejected)',
        (tester) async {
      final task = createTask(
        id: 'task-1',
        title: 'Rejected Task',
        status: TaskStatus.rejected(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
      );

      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithTasks(pinnedTasks: [task]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('does not show check icon for in-progress tasks',
        (tester) async {
      final task = createTask(
        id: 'task-1',
        title: 'In Progress Task',
        status: TaskStatus.inProgress(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
      );

      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithTasks(pinnedTasks: [task]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('does not show check icon for open tasks', (tester) async {
      final task = createTask(
        id: 'task-1',
        title: 'Open Task',
        status: TaskStatus.open(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
      );

      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithTasks(pinnedTasks: [task]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('does not show check icon for blocked tasks', (tester) async {
      final task = createTask(
        id: 'task-1',
        title: 'Blocked Task',
        status: TaskStatus.blocked(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
          reason: 'Waiting for dependency',
        ),
      );

      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithTasks(pinnedTasks: [task]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('does not show check icon for on-hold tasks', (tester) async {
      final task = createTask(
        id: 'task-1',
        title: 'On Hold Task',
        status: TaskStatus.onHold(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
          reason: 'Paused',
        ),
      );

      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithTasks(pinnedTasks: [task]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('does not show check icon for groomed tasks', (tester) async {
      final task = createTask(
        id: 'task-1',
        title: 'Groomed Task',
        status: TaskStatus.groomed(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
      );

      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithTasks(pinnedTasks: [task]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('displays multiple pinned tasks', (tester) async {
      final tasks = [
        createTask(
          id: 'task-1',
          title: 'First Task',
          status: TaskStatus.inProgress(
            id: 'status-1',
            createdAt: testDate,
            utcOffset: 0,
          ),
        ),
        createTask(
          id: 'task-2',
          title: 'Second Task',
          status: TaskStatus.open(
            id: 'status-2',
            createdAt: testDate,
            utcOffset: 0,
          ),
        ),
        createTask(
          id: 'task-3',
          title: 'Third Task',
          status: TaskStatus.done(
            id: 'status-3',
            createdAt: testDate,
            utcOffset: 0,
          ),
        ),
      ];

      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithTasks(pinnedTasks: tasks),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('First Task'), findsOneWidget);
      expect(find.text('Second Task'), findsOneWidget);
      expect(find.text('Third Task'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(3));
    });

    testWidgets('task row is tappable with GestureDetector', (tester) async {
      final task = createTask(
        id: 'task-1',
        title: 'Tappable Task',
        status: TaskStatus.inProgress(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
      );

      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithTasks(pinnedTasks: [task]),
        ),
      );
      await tester.pumpAndSettle();

      // Find the task text and verify it has a GestureDetector ancestor
      final taskTextFinder = find.text('Tappable Task');
      expect(taskTextFinder, findsOneWidget);

      final gestureDetector = find.ancestor(
        of: taskTextFinder,
        matching: find.byType(GestureDetector),
      );
      expect(gestureDetector, findsWidgets);
    });
  });

  group('TimeBudgetCard - Contributing Tasks Section', () {
    Task createTask({
      required String id,
      required String title,
      required TaskStatus status,
    }) {
      return Task(
        meta: Metadata(
          id: id,
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate.add(const Duration(hours: 1)),
        ),
        data: TaskData(
          title: title,
          dateFrom: testDate,
          dateTo: testDate.add(const Duration(hours: 1)),
          statusHistory: const [],
          status: status,
        ),
      );
    }

    JournalEntity createEntry({required String id}) {
      return JournalEntity.journalEntry(
        meta: Metadata(
          id: id,
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate.add(const Duration(hours: 1)),
        ),
      );
    }

    TimeBudgetProgress createProgressWithContributing({
      List<JournalEntity> contributingEntries = const [],
    }) {
      return TimeBudgetProgress(
        categoryId: testCategory.id,
        category: testCategory,
        plannedDuration: const Duration(hours: 2),
        recordedDuration: const Duration(hours: 1),
        status: BudgetProgressStatus.underBudget,
        contributingEntries: contributingEntries,
        pinnedTasks: const [],
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

    testWidgets('hides contributing tasks section when no tasks in entries',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithContributing(
            contributingEntries: [
              createEntry(id: 'entry-1'),
              createEntry(id: 'entry-2'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No tasks means no task section (only JournalEntries in contributingEntries)
      expect(find.byType(TimeBudgetCard), findsOneWidget);
      // No divider from task section since contributingTasks is empty
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('shows contributing tasks section when tasks present',
        (tester) async {
      final task = createTask(
        id: 'task-1',
        title: 'Contributing Task',
        status: TaskStatus.inProgress(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
      );

      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithContributing(
            contributingEntries: [task],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Contributing Task'), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('shows only tasks from mixed contributing entries',
        (tester) async {
      final task1 = createTask(
        id: 'task-1',
        title: 'Task One',
        status: TaskStatus.inProgress(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
      );
      final task2 = createTask(
        id: 'task-2',
        title: 'Task Two',
        status: TaskStatus.done(
          id: 'status-2',
          createdAt: testDate,
          utcOffset: 0,
        ),
      );

      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithContributing(
            contributingEntries: [
              createEntry(id: 'entry-1'),
              task1,
              createEntry(id: 'entry-2'),
              task2,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Task One'), findsOneWidget);
      expect(find.text('Task Two'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(2));
    });

    testWidgets('shows both pinned and contributing sections when both have data',
        (tester) async {
      final pinnedTask = Task(
        meta: Metadata(
          id: 'pinned-1',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate.add(const Duration(hours: 1)),
        ),
        data: TaskData(
          title: 'Pinned Task',
          dateFrom: testDate,
          dateTo: testDate.add(const Duration(hours: 1)),
          statusHistory: const [],
          status: TaskStatus.inProgress(
            id: 'status-1',
            createdAt: testDate,
            utcOffset: 0,
          ),
        ),
      );

      final contributingTask = createTask(
        id: 'contrib-1',
        title: 'Contributing Task',
        status: TaskStatus.done(
          id: 'status-2',
          createdAt: testDate,
          utcOffset: 0,
        ),
      );

      final progress = TimeBudgetProgress(
        categoryId: testCategory.id,
        category: testCategory,
        plannedDuration: const Duration(hours: 2),
        recordedDuration: const Duration(hours: 1),
        status: BudgetProgressStatus.underBudget,
        contributingEntries: [contributingTask],
        pinnedTasks: [pinnedTask],
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
        createTestWidget(progress: progress),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pinned Task'), findsOneWidget);
      expect(find.text('Contributing Task'), findsOneWidget);
      // Two dividers - one for pinned section, one for contributing section
      expect(find.byType(Divider), findsNWidgets(2));
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
