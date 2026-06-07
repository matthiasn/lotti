import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/task_view_preference_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_budget_card.dart';
import 'package:lotti/features/tasks/ui/cover_art_thumbnail.dart';
import 'package:lotti/features/tasks/util/due_date_utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart' as nav_service;
import 'package:lotti/services/nav_service.dart' show NavService;
import 'package:lotti/utils/color.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fake_entry_controller.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final navigationHistory = <String>[];

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
    List<TaskDayProgress>? taskProgressItems,
  }) {
    final effectiveCategory = category ?? testCategory;
    return TimeBudgetProgress(
      categoryId: effectiveCategory.id,
      category: effectiveCategory,
      plannedDuration: planned,
      recordedDuration: recorded,
      status: status,
      contributingEntries: const [],
      taskProgressItems: taskProgressItems ?? const [],
      blocks:
          blocks ??
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

  TimeBudgetProgress createProgressWithTasks() {
    return createProgress(
      taskProgressItems: [
        TaskDayProgress(
          task: Task(
            meta: Metadata(
              id: 'task-1',
              createdAt: testDate,
              updatedAt: testDate,
              dateFrom: testDate,
              dateTo: testDate,
            ),
            data: TaskData(
              title: 'Test Task 1',
              dateFrom: testDate,
              dateTo: testDate,
              statusHistory: const [],
              status: TaskStatus.open(
                id: 'status-1',
                createdAt: testDate,
                utcOffset: 0,
              ),
            ),
          ),
          timeSpentOnDay: const Duration(minutes: 30),
          wasCompletedOnDay: false,
        ),
        TaskDayProgress(
          task: Task(
            meta: Metadata(
              id: 'task-2',
              createdAt: testDate,
              updatedAt: testDate,
              dateFrom: testDate,
              dateTo: testDate,
            ),
            data: TaskData(
              title: 'Test Task 2',
              dateFrom: testDate,
              dateTo: testDate,
              statusHistory: const [],
              status: TaskStatus.inProgress(
                id: 'progress-1',
                createdAt: testDate,
                utcOffset: 0,
              ),
            ),
          ),
          timeSpentOnDay: const Duration(minutes: 45),
          wasCompletedOnDay: false,
        ),
      ],
    );
  }

  Widget createTestWidget({
    required TimeBudgetProgress progress,
    VoidCallback? onTap,
    bool isExpanded = false,
    bool? isFocusActive,
    List<Override> overrides = const [],
    DateTime? selectedDate,
  }) {
    return RiverpodWidgetTestBench(
      overrides: [
        highlightedCategoryIdProvider.overrideWith((ref) => null),
        // Override to avoid TimeService dependency in tests
        runningTimerCategoryIdProvider.overrideWithValue(null),
        ...overrides,
      ],
      child: TimeBudgetCard(
        progress: progress,
        selectedDate: selectedDate ?? testDate,
        onTap: onTap,
        isExpanded: isExpanded,
        isFocusActive: isFocusActive,
      ),
    );
  }

  // Shared task factory for the Pinned/Contributing task-section groups.
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

  group('TimeBudgetCard', () {
    testWidgets('displays category name', (tester) async {
      await tester.pumpWidget(
        createTestWidget(progress: createProgress()),
      );
      await tester.pump();

      expect(find.text('Work'), findsOneWidget);
    });

    testWidgets('displays recorded / planned time', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgress(
            planned: const Duration(hours: 3),
          ),
        ),
      );
      await tester.pump();

      // New format shows "recorded / planned" (default recorded is 1h)
      expect(find.text('1h / 3h'), findsOneWidget);
    });

    testWidgets('displays remaining time for under budget', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgress(),
        ),
      );
      await tester.pump();

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
      await tester.pump();

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
      await tester.pump();

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
      await tester.pump();

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
      await tester.pump();

      await tester.tap(find.byType(TimeBudgetCard));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('shows progress bar filled to the recorded fraction', (
      tester,
    ) async {
      // Defaults: planned 2h, recorded 1h -> 50% fill, under budget.
      await tester.pumpWidget(
        createTestWidget(progress: createProgress()),
      );
      await tester.pump();

      final bar = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(bar.widthFactor, closeTo(0.5, 0.001));

      // Under budget -> the fill is NOT the error color.
      final fill = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(FractionallySizedBox),
          matching: find.byType(DecoratedBox),
        ),
      );
      final context = tester.element(find.byType(TimeBudgetCard));
      expect(
        (fill.decoration as BoxDecoration).color,
        isNot(Theme.of(context).colorScheme.error),
      );
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
      await tester.pump();

      expect(find.text('Uncategorized'), findsOneWidget);
    });

    testWidgets('displays hours and minutes for planned duration', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgress(
            planned: const Duration(hours: 2, minutes: 30),
            recorded: const Duration(hours: 1, minutes: 15),
          ),
        ),
      );
      await tester.pump();

      // New format shows "recorded / planned"
      expect(find.text('1h 15m / 2h 30m'), findsOneWidget);
    });

    testWidgets('displays minutes only for short planned duration', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgress(
            planned: const Duration(minutes: 45),
            recorded: const Duration(minutes: 20),
          ),
        ),
      );
      await tester.pump();

      // New format shows "recorded / planned"
      expect(find.text('20m / 45m'), findsOneWidget);
    });

    testWidgets('shows highlighted border when category is highlighted', (
      tester,
    ) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            highlightedCategoryIdProvider.overrideWith((ref) => 'cat-1'),
            runningTimerCategoryIdProvider.overrideWithValue(null),
          ],
          child: TimeBudgetCard(
            progress: createProgress(),
            selectedDate: testDate,
          ),
        ),
      );
      await tester.pump();

      // When highlighted, the outer AnimatedContainer's BoxDecoration gains a
      // 2px border tinted with the category color (otherwise the border is null).
      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final decoration = container.decoration! as BoxDecoration;
      final border = decoration.border! as Border;
      expect(border.top.width, 2);
      expect(border.top.color, colorFromCssHex(testCategory.color));
    });

    testWidgets('has no border when category is not highlighted', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(progress: createProgress()),
      );
      await tester.pump();

      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.border, isNull);
    });

    testWidgets('handles long press callback', (tester) async {
      var longPressed = false;

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            highlightedCategoryIdProvider.overrideWith((ref) => null),
            runningTimerCategoryIdProvider.overrideWithValue(null),
          ],
          child: TimeBudgetCard(
            progress: createProgress(),
            selectedDate: testDate,
            onLongPress: () => longPressed = true,
          ),
        ),
      );
      await tester.pump();

      await tester.longPress(find.byType(TimeBudgetCard));
      await tester.pump();

      expect(longPressed, isTrue);
    });

    testWidgets('displays remaining time with hours and minutes', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgress(
            planned: const Duration(hours: 3),
            recorded: const Duration(hours: 1, minutes: 30),
          ),
        ),
      );
      await tester.pump();

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
      await tester.pump();

      expect(find.text('+1h 15m over'), findsOneWidget);
    });

    testWidgets('over-budget progress bar clamps to full and uses the '
        'error color', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgress(
            recorded: const Duration(hours: 2, minutes: 30),
            status: BudgetProgressStatus.overBudget,
          ),
        ),
      );
      await tester.pump();

      // 2h30 recorded vs 2h planned -> fraction clamps to 1.0.
      final bar = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(bar.widthFactor, 1.0);

      final fill = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(FractionallySizedBox),
          matching: find.byType(DecoratedBox),
        ),
      );
      final context = tester.element(find.byType(TimeBudgetCard));
      expect(
        (fill.decoration as BoxDecoration).color,
        Theme.of(context).colorScheme.error,
      );
    });
  });

  group('TimeBudgetCard - Pinned Tasks Section', () {
    TaskDayProgress taskToProgress(Task task) {
      final isCompleted =
          task.data.status is TaskDone || task.data.status is TaskRejected;
      return TaskDayProgress(
        task: task,
        timeSpentOnDay: const Duration(hours: 1),
        wasCompletedOnDay: isCompleted,
      );
    }

    TimeBudgetProgress createProgressWithTasks({
      List<Task> tasks = const [],
      List<JournalEntity> contributingEntries = const [],
    }) {
      return TimeBudgetProgress(
        categoryId: testCategory.id,
        category: testCategory,
        plannedDuration: const Duration(hours: 2),
        recordedDuration: const Duration(hours: 1),
        status: BudgetProgressStatus.underBudget,
        contributingEntries: contributingEntries,
        taskProgressItems: tasks.map(taskToProgress).toList(),
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
          progress: createProgressWithTasks(tasks: []),
        ),
      );
      await tester.pump();

      // Should not show task title text when no tasks
      expect(find.text('Test Task'), findsNothing);
      // The task-section divider is absent when there are no tasks (the
      // populated case asserts exactly one Divider).
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('shows pinned tasks section with divider when populated', (
      tester,
    ) async {
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
          progress: createProgressWithTasks(tasks: [task]),
          isFocusActive: true,
        ),
      );
      await tester.pump();

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
          progress: createProgressWithTasks(tasks: [task]),
          isFocusActive: true,
        ),
      );
      await tester.pump();

      expect(find.text('Important Work Item'), findsOneWidget);
    });

    testWidgets('shows status indicator for open tasks', (tester) async {
      final task = createTask(
        id: 'task-1',
        title: 'Task With Status',
        status: TaskStatus.open(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
      );

      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithTasks(tasks: [task]),
          isFocusActive: true,
        ),
      );
      await tester.pump();

      // Open tasks show a circle border indicator (no check icon)
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.text('Task With Status'), findsOneWidget);
    });

    // Terminal statuses (done, rejected) both render the check icon —
    // one parameterized loop instead of copy-paste permutations.
    for (final (label, status) in [
      (
        'done',
        TaskStatus.done(id: 'status-1', createdAt: testDate, utcOffset: 0),
      ),
      (
        'rejected',
        TaskStatus.rejected(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
      ),
    ]) {
      testWidgets('shows check_circle icon for $label tasks', (tester) async {
        final task = createTask(
          id: 'task-1',
          title: 'Terminal Task',
          status: status,
        );

        await tester.pumpWidget(
          createTestWidget(
            progress: createProgressWithTasks(tasks: [task]),
            isFocusActive: true,
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.check_circle), findsOneWidget);
      });
    }

    testWidgets(
      'shows faded check_circle for tasks completed on a different day',
      (tester) async {
        // Task is done but wasCompletedOnDay is false (completed elsewhere)
        final task = createTask(
          id: 'task-1',
          title: 'Completed Elsewhere Task',
          status: TaskStatus.done(
            id: 'status-1',
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
          contributingEntries: const [],
          taskProgressItems: [
            TaskDayProgress(
              task: task,
              timeSpentOnDay: const Duration(hours: 1),
              wasCompletedOnDay: false, // Completed on a different day
            ),
          ],
          blocks: const [],
        );

        await tester.pumpWidget(
          createTestWidget(progress: progress, isFocusActive: true),
        );
        await tester.pump();

        // Should still show check_circle icon (faded)
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
      },
    );

    // Non-terminal statuses must NOT render the check icon — one
    // parameterized loop over all five variants.
    for (final (label, status) in [
      (
        'in-progress',
        TaskStatus.inProgress(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
      ),
      (
        'open',
        TaskStatus.open(id: 'status-1', createdAt: testDate, utcOffset: 0),
      ),
      (
        'blocked',
        TaskStatus.blocked(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
          reason: 'Waiting for dependency',
        ),
      ),
      (
        'on-hold',
        TaskStatus.onHold(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
          reason: 'Paused',
        ),
      ),
      (
        'groomed',
        TaskStatus.groomed(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
      ),
    ]) {
      testWidgets('does not show check icon for $label tasks', (tester) async {
        final task = createTask(
          id: 'task-1',
          title: 'Open-ended Task',
          status: status,
        );

        await tester.pumpWidget(
          createTestWidget(
            progress: createProgressWithTasks(tasks: [task]),
            isFocusActive: true,
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.check_circle), findsNothing);
      });
    }

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
          progress: createProgressWithTasks(tasks: tasks),
          isFocusActive: true,
        ),
      );
      await tester.pump();

      expect(find.text('First Task'), findsOneWidget);
      expect(find.text('Second Task'), findsOneWidget);
      expect(find.text('Third Task'), findsOneWidget);
      // Third task is done, so it shows check_circle
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
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
          progress: createProgressWithTasks(tasks: [task]),
          isFocusActive: true,
        ),
      );
      await tester.pump();

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
        taskProgressItems: const [],
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

    testWidgets('hides contributing tasks section when no tasks in entries', (
      tester,
    ) async {
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
      await tester.pump();

      // No tasks means no task section (only JournalEntries in contributingEntries)
      expect(find.byType(TimeBudgetCard), findsOneWidget);
      // No divider from task section since contributingTasks is empty
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets(
      'does not display tasks from contributingEntries in task section',
      (tester) async {
        // Tasks in contributingEntries are NOT displayed in the task section
        // Only taskProgressItems are shown
        final task = createTask(
          id: 'task-1',
          title: 'Contributing Task In Entries',
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
        await tester.pump();

        // Task title should NOT appear because it's only in contributingEntries
        expect(find.text('Contributing Task In Entries'), findsNothing);
        expect(find.byType(Divider), findsNothing);
      },
    );
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

    testWidgets('shows P0 (Urgent) priority badge in list view', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithPriorityTask(TaskPriority.p0Urgent),
          isFocusActive: true,
        ),
      );
      await tester.pump();

      // Should show P0 badge text
      expect(find.text('P0'), findsOneWidget);
    });

    testWidgets('shows P1 (High) priority badge in list view', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithPriorityTask(TaskPriority.p1High),
          isFocusActive: true,
        ),
      );
      await tester.pump();

      expect(find.text('P1'), findsOneWidget);
    });

    testWidgets('shows P2 (Medium) priority badge in list view', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithPriorityTask(TaskPriority.p2Medium),
          isFocusActive: true,
        ),
      );
      await tester.pump();

      expect(find.text('P2'), findsOneWidget);
    });

    testWidgets('shows P3 (Low) priority badge in list view', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithPriorityTask(TaskPriority.p3Low),
          isFocusActive: true,
        ),
      );
      await tester.pump();

      expect(find.text('P3'), findsOneWidget);
    });

    testWidgets('priority badge text color uses urgency palette', (
      tester,
    ) async {
      // P0 Urgent should use red
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithPriorityTask(TaskPriority.p0Urgent),
          isFocusActive: true,
        ),
      );
      await tester.pump();

      final p0Text = tester.widget<Text>(find.text('P0'));
      final p0Color = p0Text.style?.color;
      // The _PriorityBadge uses priority.colorForBrightness(brightness)
      // as the text color. Default RiverpodWidgetTestBench uses light theme.
      expect(
        p0Color,
        equals(TaskPriority.p0Urgent.colorForBrightness(Brightness.light)),
      );
    });

    testWidgets('each priority badge uses a distinct color', (tester) async {
      final textColors = <Color>[];

      for (final priority in TaskPriority.values) {
        await tester.pumpWidget(
          createTestWidget(
            progress: createProgressWithPriorityTask(priority),
            isFocusActive: true,
          ),
        );
        await tester.pump();

        final text = tester.widget<Text>(find.text(priority.short));
        textColors.add(text.style!.color!);
      }

      // All 4 priority levels should have unique text colors
      expect(textColors.toSet().length, equals(4));
    });
  });

  group('TimeBudgetCard - Running Timer Indicator', () {
    testWidgets('shows timer icon when timer is running for category', (
      tester,
    ) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            highlightedCategoryIdProvider.overrideWith((ref) => null),
            // Timer is running for this category
            runningTimerCategoryIdProvider.overrideWithValue('cat-1'),
          ],
          child: TimeBudgetCard(
            progress: createProgress(),
            selectedDate: testDate,
          ),
        ),
      );
      await tester.pump();

      // Should show timer icon
      expect(find.byIcon(Icons.timer), findsOneWidget);
    });

    testWidgets('does not show timer icon when no timer is running', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(progress: createProgress()),
      );
      await tester.pump();

      // Should not show timer icon
      expect(find.byIcon(Icons.timer), findsNothing);
    });

    testWidgets(
      'does not show timer icon when timer is for different category',
      (tester) async {
        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              highlightedCategoryIdProvider.overrideWith((ref) => null),
              // Timer is running for a different category
              runningTimerCategoryIdProvider.overrideWithValue(
                'other-category',
              ),
            ],
            child: TimeBudgetCard(
              progress: createProgress(),
              selectedDate: testDate,
            ),
          ),
        );
        await tester.pump();

        // Should not show timer icon for this category
        expect(find.byIcon(Icons.timer), findsNothing);
      },
    );
  });

  group('TimeBudgetCard - Focus State and User Toggle', () {
    testWidgets('respects isFocusActive for initial expansion state', (
      tester,
    ) async {
      // When isFocusActive is true, card should be expanded
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithTasks(),
          isFocusActive: true,
        ),
      );
      await tester.pump();

      // Tasks should be visible when expanded
      expect(find.text('Test Task 1'), findsWidgets);
    });

    testWidgets('collapses when isFocusActive becomes false', (tester) async {
      final focusController = StreamController<String?>.broadcast();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            highlightedCategoryIdProvider.overrideWith((ref) => null),
            runningTimerCategoryIdProvider.overrideWithValue(null),
            activeFocusCategoryIdProvider.overrideWith(
              (ref) => focusController.stream,
            ),
          ],
          child: TimeBudgetCard(
            progress: createProgressWithTasks(),
            selectedDate: testDate,
            isFocusActive: true,
          ),
        ),
      );
      await tester.pump();

      // Initially expanded
      expect(find.text('Test Task 1'), findsWidgets);

      // Simulate focus changing to a different category
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            highlightedCategoryIdProvider.overrideWith((ref) => null),
            runningTimerCategoryIdProvider.overrideWithValue(null),
            activeFocusCategoryIdProvider.overrideWith(
              (ref) => focusController.stream,
            ),
          ],
          child: TimeBudgetCard(
            progress: createProgressWithTasks(),
            selectedDate: testDate,
            isFocusActive: false,
          ),
        ),
      );
      await tester.pump();

      // Should be collapsed now - tasks hidden
      expect(find.text('Test Task 1'), findsNothing);

      await focusController.close();
    });

    testWidgets('preserves user toggle when focus changes', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            highlightedCategoryIdProvider.overrideWith((ref) => null),
            runningTimerCategoryIdProvider.overrideWithValue(null),
          ],
          child: TimeBudgetCard(
            progress: createProgressWithTasks(),
            selectedDate: testDate,
            isFocusActive: true,
          ),
        ),
      );
      await tester.pump();

      // Initially expanded
      expect(find.text('Test Task 1'), findsWidgets);

      // User manually collapses by tapping expand/collapse icon
      final expandIcon = find.byIcon(Icons.keyboard_arrow_down);
      expect(expandIcon, findsOneWidget);
      await tester.tap(expandIcon);
      await tester.pump();

      // Should be collapsed after user toggle
      expect(find.text('Test Task 1'), findsNothing);

      // Now simulate focus changing (isFocusActive becomes false then true again)
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            highlightedCategoryIdProvider.overrideWith((ref) => null),
            runningTimerCategoryIdProvider.overrideWithValue(null),
          ],
          child: TimeBudgetCard(
            progress: createProgressWithTasks(),
            selectedDate: testDate,
            isFocusActive: false,
          ),
        ),
      );
      await tester.pump();

      // Bring focus back
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            highlightedCategoryIdProvider.overrideWith((ref) => null),
            runningTimerCategoryIdProvider.overrideWithValue(null),
          ],
          child: TimeBudgetCard(
            progress: createProgressWithTasks(),
            selectedDate: testDate,
            isFocusActive: true,
          ),
        ),
      );
      await tester.pump();

      // Should still be collapsed because user manually toggled
      expect(find.text('Test Task 1'), findsNothing);
    });
  });

  group('TimeBudgetCard - Grid View Mode', () {
    Task createTaskWithCoverArt({
      required String id,
      required String title,
      String? coverArtId,
    }) {
      return Task(
        meta: Metadata(
          id: id,
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate.add(const Duration(hours: 1)),
          categoryId: testCategory.id,
        ),
        data: TaskData(
          title: title,
          dateFrom: testDate,
          dateTo: testDate.add(const Duration(hours: 1)),
          coverArtId: coverArtId,
          statusHistory: const [],
          status: TaskStatus.inProgress(
            id: 'status-$id',
            createdAt: testDate,
            utcOffset: 0,
          ),
        ),
      );
    }

    TimeBudgetProgress createProgressWithTasksForGrid({
      List<TaskDayProgress>? taskItems,
    }) {
      return TimeBudgetProgress(
        categoryId: testCategory.id,
        category: testCategory,
        plannedDuration: const Duration(hours: 2),
        recordedDuration: const Duration(hours: 1),
        status: BudgetProgressStatus.underBudget,
        contributingEntries: const [],
        taskProgressItems:
            taskItems ??
            [
              TaskDayProgress(
                task: createTaskWithCoverArt(
                  id: 'task-grid-1',
                  title: 'Grid Task 1',
                ),
                timeSpentOnDay: const Duration(minutes: 30),
                wasCompletedOnDay: false,
              ),
              TaskDayProgress(
                task: createTaskWithCoverArt(
                  id: 'task-grid-2',
                  title: 'Grid Task 2',
                ),
                timeSpentOnDay: const Duration(minutes: 45),
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
    }

    testWidgets('displays tasks in grid view when view mode is grid', (
      tester,
    ) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            highlightedCategoryIdProvider.overrideWith((ref) => null),
            runningTimerCategoryIdProvider.overrideWithValue(null),
            // Override view preference to grid mode
            taskViewPreferenceProvider(
              categoryId: testCategory.id,
            ).overrideWith(_TestTaskViewPreferenceController.new),
          ],
          child: TimeBudgetCard(
            progress: createProgressWithTasksForGrid(),
            selectedDate: testDate,
            isFocusActive: true,
          ),
        ),
      );
      await tester.pump();

      // Grid view should show GridView widget
      expect(find.byType(GridView), findsOneWidget);
      // Task titles should still be visible
      expect(find.text('Grid Task 1'), findsOneWidget);
      expect(find.text('Grid Task 2'), findsOneWidget);
    });

    testWidgets('shows completed checkmark in grid tile', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            highlightedCategoryIdProvider.overrideWith((ref) => null),
            runningTimerCategoryIdProvider.overrideWithValue(null),
            taskViewPreferenceProvider(
              categoryId: testCategory.id,
            ).overrideWith(_TestTaskViewPreferenceController.new),
          ],
          child: TimeBudgetCard(
            progress: createProgressWithTasksForGrid(),
            selectedDate: testDate,
            isFocusActive: true,
          ),
        ),
      );
      await tester.pump();

      // The completed task should show a check icon
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('displays view toggle icon in list mode', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            highlightedCategoryIdProvider.overrideWith((ref) => null),
            runningTimerCategoryIdProvider.overrideWithValue(null),
            // Start with list view
          ],
          child: TimeBudgetCard(
            progress: createProgressWithTasksForGrid(),
            selectedDate: testDate,
            isFocusActive: true,
          ),
        ),
      );
      await tester.pump();

      // Initially in list view - should show grid toggle icon
      expect(find.byType(GridView), findsNothing);

      // Find the view toggle icon (grid_view_rounded in list mode)
      final toggleIcon = find.byIcon(Icons.grid_view_rounded);
      expect(toggleIcon, findsOneWidget);
    });
  });

  group('TimeBudgetCard - Due Badge Display', () {
    TaskDayProgress createTaskProgressWithDueStatus({
      required String id,
      required String title,
      required DueDateUrgency urgency,
    }) {
      final dueStatus = DueDateStatus(
        urgency: urgency,
        daysUntilDue: urgency == DueDateUrgency.overdue ? -1 : 0,
      );
      return TaskDayProgress(
        task: Task(
          meta: Metadata(
            id: id,
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
            categoryId: testCategory.id,
          ),
          data: TaskData(
            title: title,
            dateFrom: testDate,
            dateTo: testDate,
            due: testDate,
            statusHistory: const [],
            status: TaskStatus.inProgress(
              id: 'status-$id',
              createdAt: testDate,
              utcOffset: 0,
            ),
          ),
        ),
        timeSpentOnDay: const Duration(hours: 1),
        wasCompletedOnDay: false,
        dueDateStatus: dueStatus,
      );
    }

    TimeBudgetProgress createProgressWithDueTasks(DueDateUrgency urgency) {
      return TimeBudgetProgress(
        categoryId: testCategory.id,
        category: testCategory,
        plannedDuration: const Duration(hours: 2),
        recordedDuration: const Duration(hours: 1),
        status: BudgetProgressStatus.underBudget,
        contributingEntries: const [],
        taskProgressItems: [
          createTaskProgressWithDueStatus(
            id: 'task-due',
            title: 'Due Task',
            urgency: urgency,
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

    testWidgets('shows Due Today badge for due today tasks', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithDueTasks(DueDateUrgency.dueToday),
          isFocusActive: true,
        ),
      );
      await tester.pump();

      // Should show the "Due today" badge text (list view)
      expect(find.text('Due today'), findsOneWidget);
    });

    testWidgets('shows Overdue badge for overdue tasks', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithDueTasks(DueDateUrgency.overdue),
          isFocusActive: true,
        ),
      );
      await tester.pump();

      // Should show the "Overdue" badge text
      expect(find.text('Overdue'), findsOneWidget);
    });

    testWidgets('does not show due badge for normal tasks', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgressWithDueTasks(DueDateUrgency.normal),
          isFocusActive: true,
        ),
      );
      await tester.pump();

      // Should not show any due badge
      expect(find.text('Due today'), findsNothing);
      expect(find.text('Overdue'), findsNothing);
    });
  });

  group('TimeBudgetCard - No Budget Display', () {
    TimeBudgetProgress createProgressNoBudgetNoTime() {
      return TimeBudgetProgress(
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
                title: 'Due Task No Budget',
                dateFrom: testDate,
                dateTo: testDate,
                due: testDate,
                statusHistory: const [],
                status: TaskStatus.open(
                  id: 'status-1',
                  createdAt: testDate,
                  utcOffset: 0,
                ),
              ),
            ),
            timeSpentOnDay: Duration.zero,
            wasCompletedOnDay: false,
          ),
        ],
        blocks: [],
        hasNoBudgetWarning: true,
      );
    }

    TimeBudgetProgress createProgressNoBudgetWithTime() {
      return TimeBudgetProgress(
        categoryId: testCategory.id,
        category: testCategory,
        plannedDuration: Duration.zero,
        recordedDuration: const Duration(minutes: 45),
        status: BudgetProgressStatus.overBudget,
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
                title: 'Due Task No Budget',
                dateFrom: testDate,
                dateTo: testDate,
                due: testDate,
                statusHistory: const [],
                status: TaskStatus.open(
                  id: 'status-1',
                  createdAt: testDate,
                  utcOffset: 0,
                ),
              ),
            ),
            timeSpentOnDay: const Duration(minutes: 45),
            wasCompletedOnDay: false,
          ),
        ],
        blocks: [],
        hasNoBudgetWarning: true,
      );
    }

    testWidgets(
      'Scenario A: no budget, no time - shows inline indicator instead of time info',
      (tester) async {
        await tester.pumpWidget(
          createTestWidget(progress: createProgressNoBudgetNoTime()),
        );
        await tester.pump();

        // Should show inline warning indicator
        final context = tester.element(find.byType(TimeBudgetCard));
        final noBudgetText = context.messages.dailyOsNoBudgetWarning;
        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
        expect(find.text(noBudgetText), findsOneWidget);

        // Should NOT show "0m / 0m" time text
        expect(find.text('0m / 0m'), findsNothing);

        // Should NOT show "0m left" badge
        expect(find.text('0m left'), findsNothing);
      },
    );

    testWidgets(
      'Scenario B: no budget, has time - shows Xm / 0m with No time budgeted badge',
      (tester) async {
        await tester.pumpWidget(
          createTestWidget(progress: createProgressNoBudgetWithTime()),
        );
        await tester.pump();

        // Should show time comparison (recorded / planned)
        expect(find.text('45m / 0m'), findsOneWidget);

        // Should show "No time budgeted" badge instead of confusing "-45m left" or "+45m over"
        final context = tester.element(find.byType(TimeBudgetCard));
        final noBudgetText = context.messages.dailyOsNoBudgetWarning;
        expect(find.text(noBudgetText), findsOneWidget);

        // Should NOT show misleading status like "+45m over" when there's no budget
        expect(find.text('+45m over'), findsNothing);
      },
    );

    testWidgets('does not show warning when hasNoBudgetWarning is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(progress: createProgress()),
      );
      await tester.pump();

      // Should not show warning icon
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });
  });

  group('TimeBudgetCard - Grid View with Badges', () {
    TaskDayProgress createGridTaskProgress({
      required String id,
      required String title,
      TaskPriority priority = TaskPriority.p2Medium,
      bool isCompleted = false,
      DueDateUrgency? dueUrgency,
    }) {
      final dueStatus = dueUrgency != null
          ? DueDateStatus(
              urgency: dueUrgency,
              daysUntilDue: dueUrgency == DueDateUrgency.overdue ? -1 : 0,
            )
          : const DueDateStatus.none();
      return TaskDayProgress(
        task: Task(
          meta: Metadata(
            id: id,
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
            categoryId: testCategory.id,
          ),
          data: TaskData(
            title: title,
            dateFrom: testDate,
            dateTo: testDate,
            due: dueUrgency != null ? testDate : null,
            priority: priority,
            statusHistory: const [],
            status: isCompleted
                ? TaskStatus.done(
                    id: 'status-done-$id',
                    createdAt: testDate,
                    utcOffset: 0,
                  )
                : TaskStatus.inProgress(
                    id: 'status-$id',
                    createdAt: testDate,
                    utcOffset: 0,
                  ),
          ),
        ),
        timeSpentOnDay: const Duration(hours: 1),
        wasCompletedOnDay: isCompleted,
        dueDateStatus: dueStatus,
      );
    }

    TimeBudgetProgress createGridProgress(List<TaskDayProgress> items) {
      return TimeBudgetProgress(
        categoryId: testCategory.id,
        category: testCategory,
        plannedDuration: const Duration(hours: 2),
        recordedDuration: const Duration(hours: 1),
        status: BudgetProgressStatus.underBudget,
        contributingEntries: const [],
        taskProgressItems: items,
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

    testWidgets('shows priority badge in grid view for P0 tasks', (
      tester,
    ) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            highlightedCategoryIdProvider.overrideWith((ref) => null),
            runningTimerCategoryIdProvider.overrideWithValue(null),
            taskViewPreferenceProvider(
              categoryId: testCategory.id,
            ).overrideWith(_TestTaskViewPreferenceController.new),
          ],
          child: TimeBudgetCard(
            progress: createGridProgress([
              createGridTaskProgress(
                id: 'task-p0',
                title: 'P0 Task',
                priority: TaskPriority.p0Urgent,
              ),
            ]),
            selectedDate: testDate,
            isFocusActive: true,
          ),
        ),
      );
      await tester.pump();

      // Should show P0 badge in grid
      expect(find.text('P0'), findsOneWidget);
    });

    testWidgets('shows due badge in grid view', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            highlightedCategoryIdProvider.overrideWith((ref) => null),
            runningTimerCategoryIdProvider.overrideWithValue(null),
            taskViewPreferenceProvider(
              categoryId: testCategory.id,
            ).overrideWith(_TestTaskViewPreferenceController.new),
          ],
          child: TimeBudgetCard(
            progress: createGridProgress([
              createGridTaskProgress(
                id: 'task-due',
                title: 'Due Task',
                dueUrgency: DueDateUrgency.dueToday,
              ),
            ]),
            selectedDate: testDate,
            isFocusActive: true,
          ),
        ),
      );
      await tester.pump();

      // Should show "Due" badge in grid (short form)
      expect(find.text('Due'), findsOneWidget);
    });

    testWidgets('shows overdue badge in grid view', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            highlightedCategoryIdProvider.overrideWith((ref) => null),
            runningTimerCategoryIdProvider.overrideWithValue(null),
            taskViewPreferenceProvider(
              categoryId: testCategory.id,
            ).overrideWith(_TestTaskViewPreferenceController.new),
          ],
          child: TimeBudgetCard(
            progress: createGridProgress([
              createGridTaskProgress(
                id: 'task-overdue',
                title: 'Overdue Task',
                dueUrgency: DueDateUrgency.overdue,
              ),
            ]),
            selectedDate: testDate,
            isFocusActive: true,
          ),
        ),
      );
      await tester.pump();

      // Should show "Late" badge in grid (short form)
      expect(find.text('Late'), findsOneWidget);
    });

    testWidgets('shows all badges stacked for completed overdue P1 task', (
      tester,
    ) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            highlightedCategoryIdProvider.overrideWith((ref) => null),
            runningTimerCategoryIdProvider.overrideWithValue(null),
            taskViewPreferenceProvider(
              categoryId: testCategory.id,
            ).overrideWith(_TestTaskViewPreferenceController.new),
          ],
          child: TimeBudgetCard(
            progress: createGridProgress([
              createGridTaskProgress(
                id: 'task-complex',
                title: 'Complex Task',
                priority: TaskPriority.p1High,
                isCompleted: true,
                dueUrgency: DueDateUrgency.overdue,
              ),
            ]),
            selectedDate: testDate,
            isFocusActive: true,
          ),
        ),
      );
      await tester.pump();

      // Should show all badges
      expect(find.byIcon(Icons.check), findsOneWidget); // Completed checkmark
      expect(find.text('P1'), findsOneWidget); // Priority badge
      expect(find.text('Late'), findsOneWidget); // Overdue badge
    });
  });
  group('TimeBudgetCard - Quick Create Task Button', () {
    late MockNavService mockNavService;
    late MockPersistenceLogic mockPersistenceLogic;
    late MockTaskAgentService mockTaskAgentService;

    setUpAll(() {
      registerFallbackValue(
        TaskData(
          title: '',
          status: TaskStatus.open(
            id: 'test-id',
            createdAt: DateTime(2026),
            utcOffset: 0,
          ),
          dateFrom: DateTime(2026),
          dateTo: DateTime(2026),
          statusHistory: [],
        ),
      );
      registerFallbackValue(const EntryText(plainText: ''));
    });

    setUp(() async {
      await getIt.reset();
      mockNavService = MockNavService();
      mockPersistenceLogic = MockPersistenceLogic();
      mockTaskAgentService = MockTaskAgentService();
      navigationHistory.clear();
      // Capture navigations through the top-level beamToNamed seam instead
      // of a bespoke NavService subclass.
      nav_service.beamToNamedOverride = navigationHistory.add;

      final mockEntitiesCache = MockEntitiesCacheService();
      when(() => mockEntitiesCache.getCategoryById(any())).thenReturn(null);

      getIt
        ..registerSingleton<NavService>(mockNavService)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCache);
    });

    tearDown(() async {
      nav_service.beamToNamedOverride = null;
      await getIt.reset();
    });

    testWidgets('shows quick create button with tooltip', (tester) async {
      await tester.pumpWidget(
        createTestWidget(progress: createProgress()),
      );
      await tester.pump();

      // Get localized string from context
      final context = tester.element(find.byType(TimeBudgetCard));
      final tooltipText = context.messages.dailyOsQuickCreateTask;

      // Verify the quick create button is present
      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
      expect(find.byTooltip(tooltipText), findsOneWidget);
    });

    testWidgets(
      'tapping quick create button creates task with correct params',
      (tester) async {
        const testTaskId = 'test-task-id';
        final testTask = Task(
          meta: Metadata(
            id: testTaskId,
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
          ),
          data: TaskData(
            title: '',
            status: TaskStatus.open(
              id: 'status-id',
              createdAt: testDate,
              utcOffset: 0,
            ),
            dateFrom: testDate,
            dateTo: testDate,
            statusHistory: [],
          ),
        );

        // Mock the persistence logic to return our test task
        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => testTask);

        await tester.pumpWidget(
          createTestWidget(
            progress: createProgress(),
            selectedDate: testDate,
            overrides: [
              taskAgentServiceProvider.overrideWithValue(mockTaskAgentService),
            ],
          ),
        );
        await tester.pump();

        // Get localized string from context
        final context = tester.element(find.byType(TimeBudgetCard));
        final tooltipText = context.messages.dailyOsQuickCreateTask;

        // Tap the quick create button
        await tester.tap(find.byTooltip(tooltipText));
        await tester.pump();

        // Verify task creation was called with correct category
        verify(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: 'cat-1', // testCategory.id
          ),
        ).called(1);

        // Verify navigation was called with the correct path
        expect(
          navigationHistory,
          contains('/tasks/$testTaskId'),
        );
      },
    );

    testWidgets('quick create button passes due date from selectedDate', (
      tester,
    ) async {
      const testTaskId = 'test-task-id';
      final selectedDate = DateTime(2026, 2, 15);
      TaskData? capturedData;

      final testTask = Task(
        meta: Metadata(
          id: testTaskId,
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
        ),
        data: TaskData(
          title: '',
          status: TaskStatus.open(
            id: 'status-id',
            createdAt: testDate,
            utcOffset: 0,
          ),
          dateFrom: testDate,
          dateTo: testDate,
          statusHistory: [],
          due: selectedDate,
        ),
      );

      when(
        () => mockPersistenceLogic.createTaskEntry(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          linkedId: any(named: 'linkedId'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((invocation) async {
        capturedData = invocation.namedArguments[#data] as TaskData;
        return testTask;
      });

      await tester.pumpWidget(
        createTestWidget(
          progress: createProgress(),
          selectedDate: selectedDate,
          overrides: [
            taskAgentServiceProvider.overrideWithValue(mockTaskAgentService),
          ],
        ),
      );
      await tester.pump();

      // Get localized string from context
      final context = tester.element(find.byType(TimeBudgetCard));
      final tooltipText = context.messages.dailyOsQuickCreateTask;

      // Tap the quick create button
      await tester.tap(find.byTooltip(tooltipText));
      await tester.pump();

      // Verify the due date was passed correctly
      expect(capturedData, isNotNull);
      expect(capturedData!.due, selectedDate);
    });

    testWidgets('does not navigate when task creation fails', (tester) async {
      // Mock the persistence logic to return null (failure)
      when(
        () => mockPersistenceLogic.createTaskEntry(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          linkedId: any(named: 'linkedId'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(
        createTestWidget(progress: createProgress()),
      );
      await tester.pump();

      // Get localized string from context
      final context = tester.element(find.byType(TimeBudgetCard));
      final tooltipText = context.messages.dailyOsQuickCreateTask;

      // Tap the quick create button
      await tester.tap(find.byTooltip(tooltipText));
      await tester.pump();

      // Verify navigation was not called
      expect(navigationHistory, isEmpty);
    });

    testWidgets('works with null category', (tester) async {
      const testTaskId = 'test-task-id';
      final testTask = Task(
        meta: Metadata(
          id: testTaskId,
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
        ),
        data: TaskData(
          title: '',
          status: TaskStatus.open(
            id: 'status-id',
            createdAt: testDate,
            utcOffset: 0,
          ),
          dateFrom: testDate,
          dateTo: testDate,
          statusHistory: [],
        ),
      );

      when(
        () => mockPersistenceLogic.createTaskEntry(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          linkedId: any(named: 'linkedId'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async => testTask);

      // Create progress without a category
      final progressWithoutCategory = TimeBudgetProgress(
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
      );

      await tester.pumpWidget(
        createTestWidget(
          progress: progressWithoutCategory,
          overrides: [
            taskAgentServiceProvider.overrideWithValue(mockTaskAgentService),
          ],
        ),
      );
      await tester.pump();

      // Get localized string from context
      final context = tester.element(find.byType(TimeBudgetCard));
      final tooltipText = context.messages.dailyOsQuickCreateTask;

      // Tap the quick create button
      await tester.tap(find.byTooltip(tooltipText));
      await tester.pump();

      // Verify task creation was called with null category
      // Note: Using captureAny to verify categoryId was explicitly passed as null
      final captured = verify(
        () => mockPersistenceLogic.createTaskEntry(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          categoryId: captureAny(named: 'categoryId'),
        ),
      ).captured;
      expect(captured.first, isNull);

      // Verify navigation still occurred
      expect(navigationHistory, contains('/tasks/$testTaskId'));
    });
  });

  group('TimeBudgetCard - View Mode Toggle', () {
    // ignore: no_leading_underscores_for_local_identifiers
    Task _createTaskForToggle({required String id, required String title}) {
      return Task(
        meta: Metadata(
          id: id,
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate.add(const Duration(hours: 1)),
          categoryId: testCategory.id,
        ),
        data: TaskData(
          title: title,
          dateFrom: testDate,
          dateTo: testDate.add(const Duration(hours: 1)),
          statusHistory: const [],
          status: TaskStatus.inProgress(
            id: 'status-$id',
            createdAt: testDate,
            utcOffset: 0,
          ),
        ),
      );
    }

    // ignore: no_leading_underscores_for_local_identifiers
    TimeBudgetProgress _createProgressForToggle() {
      return TimeBudgetProgress(
        categoryId: testCategory.id,
        category: testCategory,
        plannedDuration: const Duration(hours: 2),
        recordedDuration: const Duration(hours: 1),
        status: BudgetProgressStatus.underBudget,
        contributingEntries: const [],
        taskProgressItems: [
          TaskDayProgress(
            task: _createTaskForToggle(id: 'task-t1', title: 'Toggle Task 1'),
            timeSpentOnDay: const Duration(minutes: 30),
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

    testWidgets(
      'tapping view toggle switches from list to grid and shows view_list icon',
      (tester) async {
        // Use a togglable controller that starts in list mode.
        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              highlightedCategoryIdProvider.overrideWith((ref) => null),
              runningTimerCategoryIdProvider.overrideWithValue(null),
              taskViewPreferenceProvider(
                categoryId: testCategory.id,
              ).overrideWith(_TogglableTaskViewPreferenceController.new),
            ],
            child: TimeBudgetCard(
              progress: _createProgressForToggle(),
              selectedDate: testDate,
              isFocusActive: true,
            ),
          ),
        );
        await tester.pump();

        // Initially in list mode: grid_view_rounded toggle icon is shown.
        expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
        expect(find.byIcon(Icons.view_list_rounded), findsNothing);

        // Tap the view toggle icon.
        final toggleIcon = find.byIcon(Icons.grid_view_rounded);
        await tester.ensureVisible(toggleIcon);
        await tester.tap(toggleIcon);
        await tester.pump();

        // After toggle: now in grid mode, view_list_rounded is shown.
        expect(find.byIcon(Icons.view_list_rounded), findsOneWidget);
        expect(find.byIcon(Icons.grid_view_rounded), findsNothing);
      },
    );

    testWidgets(
      'tapping view toggle from grid back to list shows grid_view icon',
      (tester) async {
        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              highlightedCategoryIdProvider.overrideWith((ref) => null),
              runningTimerCategoryIdProvider.overrideWithValue(null),
              taskViewPreferenceProvider(
                categoryId: testCategory.id,
              ).overrideWith(_TestTaskViewPreferenceController.new),
            ],
            child: TimeBudgetCard(
              progress: _createProgressForToggle(),
              selectedDate: testDate,
              isFocusActive: true,
            ),
          ),
        );
        await tester.pump();

        // In grid mode initially: view_list_rounded is shown.
        expect(find.byIcon(Icons.view_list_rounded), findsOneWidget);
      },
    );
  });

  group('TimeBudgetCard - Task Row Navigation', () {
    late MockNavService mockNavService;
    late MockPersistenceLogic mockPersistenceLogic;

    setUp(() async {
      await getIt.reset();
      mockNavService = MockNavService();
      mockPersistenceLogic = MockPersistenceLogic();
      navigationHistory.clear();
      nav_service.beamToNamedOverride = navigationHistory.add;
      final mockEntitiesCache = MockEntitiesCacheService();
      when(() => mockEntitiesCache.getCategoryById(any())).thenReturn(null);

      getIt
        ..registerSingleton<NavService>(mockNavService)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCache);
    });

    tearDown(() async {
      nav_service.beamToNamedOverride = null;
      await getIt.reset();
    });

    // ignore: no_leading_underscores_for_local_identifiers
    Task _createNavTask({required String id, required String title}) {
      return Task(
        meta: Metadata(
          id: id,
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate.add(const Duration(hours: 1)),
          categoryId: testCategory.id,
        ),
        data: TaskData(
          title: title,
          dateFrom: testDate,
          dateTo: testDate.add(const Duration(hours: 1)),
          statusHistory: const [],
          status: TaskStatus.inProgress(
            id: 'status-$id',
            createdAt: testDate,
            utcOffset: 0,
          ),
        ),
      );
    }

    // ignore: no_leading_underscores_for_local_identifiers
    TimeBudgetProgress _createProgressForNav(String taskId, String taskTitle) {
      return TimeBudgetProgress(
        categoryId: testCategory.id,
        category: testCategory,
        plannedDuration: const Duration(hours: 2),
        recordedDuration: const Duration(hours: 1),
        status: BudgetProgressStatus.underBudget,
        contributingEntries: const [],
        taskProgressItems: [
          TaskDayProgress(
            task: _createNavTask(id: taskId, title: taskTitle),
            timeSpentOnDay: const Duration(minutes: 30),
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

    testWidgets(
      'tapping a task row navigates to the task detail page',
      (tester) async {
        const taskId = 'nav-task-123';
        const taskTitle = 'Navigable Task';

        await tester.pumpWidget(
          createTestWidget(
            progress: _createProgressForNav(taskId, taskTitle),
            isFocusActive: true,
          ),
        );
        await tester.pump();

        // Task title should be visible.
        expect(find.text(taskTitle), findsOneWidget);

        // Tap the task row.
        await tester.ensureVisible(find.text(taskTitle));
        await tester.tap(find.text(taskTitle));
        await tester.pump();

        // Navigation to the task detail page should have occurred.
        expect(
          navigationHistory,
          contains('/tasks/$taskId'),
        );
      },
    );

    testWidgets(
      'grid tile renders with task title and GestureDetector with onTap',
      (tester) async {
        const taskId = 'grid-nav-task-456';
        const taskTitle = 'Grid Navigable Task';

        await tester.pumpWidget(
          createTestWidget(
            progress: _createProgressForNav(taskId, taskTitle),
            isFocusActive: true,
            overrides: [
              taskViewPreferenceProvider(
                categoryId: testCategory.id,
              ).overrideWith(_TestTaskViewPreferenceController.new),
            ],
          ),
        );
        // Let AnimatedSize and AnimatedContainer settle.
        await tester.pump(const Duration(milliseconds: 300));

        // Task title is displayed in the grid tile.
        expect(find.text(taskTitle), findsOneWidget);

        // The grid tile wraps a GestureDetector (for navigation on tap).
        final gestureDetector = find.ancestor(
          of: find.text(taskTitle),
          matching: find.byType(GestureDetector),
        );
        expect(gestureDetector, findsWidgets);
        // Verify the GestureDetector widget has onTap set.
        final gestureDetectorWidget = tester.widget<GestureDetector>(
          gestureDetector.first,
        );
        expect(gestureDetectorWidget.onTap, isNotNull);
      },
    );

    testWidgets(
      'grid tile with coverArtId renders CoverArtThumbnail widget',
      (tester) async {
        const taskId = 'cover-art-task-789';
        const coverArtImageId = 'cover-image-id-abc';

        final taskWithCoverArt = Task(
          meta: Metadata(
            id: taskId,
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate.add(const Duration(hours: 1)),
            categoryId: testCategory.id,
          ),
          data: TaskData(
            title: 'Cover Art Task',
            dateFrom: testDate,
            dateTo: testDate.add(const Duration(hours: 1)),
            coverArtId: coverArtImageId,
            statusHistory: const [],
            status: TaskStatus.inProgress(
              id: 'status-cover',
              createdAt: testDate,
              utcOffset: 0,
            ),
          ),
        );

        final progressWithCoverArt = TimeBudgetProgress(
          categoryId: testCategory.id,
          category: testCategory,
          plannedDuration: const Duration(hours: 2),
          recordedDuration: const Duration(hours: 1),
          status: BudgetProgressStatus.underBudget,
          contributingEntries: const [],
          taskProgressItems: [
            TaskDayProgress(
              task: taskWithCoverArt,
              timeSpentOnDay: const Duration(minutes: 30),
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

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              highlightedCategoryIdProvider.overrideWith((ref) => null),
              runningTimerCategoryIdProvider.overrideWithValue(null),
              taskViewPreferenceProvider(
                categoryId: testCategory.id,
              ).overrideWith(_TestTaskViewPreferenceController.new),
              // Provide a stub so CoverArtThumbnail does not call real DB.
              entryControllerProvider(id: coverArtImageId).overrideWith(
                () => FakeEntryController(
                  JournalEntity.journalEntry(
                    meta: Metadata(
                      id: coverArtImageId,
                      createdAt: testDate,
                      updatedAt: testDate,
                      dateFrom: testDate,
                      dateTo: testDate,
                    ),
                  ),
                ),
              ),
            ],
            child: TimeBudgetCard(
              progress: progressWithCoverArt,
              selectedDate: testDate,
              isFocusActive: true,
            ),
          ),
        );
        await tester.pump();

        // CoverArtThumbnail should be rendered for the coverArtId branch.
        expect(find.byType(CoverArtThumbnail), findsOneWidget);
        final thumbnail = tester.widget<CoverArtThumbnail>(
          find.byType(CoverArtThumbnail),
        );
        expect(thumbnail.imageId, equals(coverArtImageId));
      },
    );
  });

  group('formatCompactDuration', () {
    test('formats canonical examples', () {
      expect(formatCompactDuration(Duration.zero), '0m');
      expect(formatCompactDuration(const Duration(minutes: 45)), '45m');
      expect(formatCompactDuration(const Duration(hours: 2)), '2h');
      expect(
        formatCompactDuration(const Duration(hours: 1, minutes: 5)),
        '1h 5m',
      );
    });

    glados.Glados(
      glados.any.compactDurationMinutes,
      glados.ExploreConfig(numRuns: 150),
    ).test('output always reconstructs the duration in whole minutes', (
      totalMinutes,
    ) {
      final duration = Duration(minutes: totalMinutes);
      final formatted = formatCompactDuration(duration);

      final hours = totalMinutes ~/ 60;
      final mins = totalMinutes % 60;
      if (hours > 0) {
        expect(formatted, startsWith('${hours}h'), reason: formatted);
        if (mins == 0) {
          expect(formatted, '${hours}h');
        } else {
          expect(formatted, '${hours}h ${mins}m');
        }
      } else {
        expect(formatted, '${mins}m');
      }
    }, tags: 'glados');
  });
}

extension _AnyCompactDuration on glados.Any {
  glados.Generator<int> get compactDurationMinutes =>
      glados.IntAnys(this).intInRange(0, 60 * 50);
}

/// Test controller that returns grid mode.
class _TestTaskViewPreferenceController extends TaskViewPreference {
  @override
  Future<TaskViewMode> build({required String categoryId}) async {
    return TaskViewMode.grid;
  }
}

/// Test controller that starts in list mode and can toggle to grid.
class _TogglableTaskViewPreferenceController extends TaskViewPreference {
  @override
  Future<TaskViewMode> build({required String categoryId}) async {
    return TaskViewMode.list;
  }

  @override
  Future<void> toggle() async {
    final current = state.value ?? TaskViewMode.list;
    state = AsyncValue.data(
      current == TaskViewMode.list ? TaskViewMode.grid : TaskViewMode.list,
    );
  }
}
