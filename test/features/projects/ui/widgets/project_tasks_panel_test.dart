import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/features/projects/ui/model/project_task_list_options.dart';
import 'package:lotti/features/projects/ui/widgets/project_tasks_panel.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  final now = DateTime(2026, 9, 5, 12);

  Widget wrap(Widget child) {
    return makeTestableWidget2(
      Theme(
        data: DesignSystemTheme.dark(),
        child: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(width: 400, child: child),
          ),
        ),
      ),
    );
  }

  group('TaskSummaryRow', () {
    testWidgets('renders task title, one-liner, and estimated duration', (
      tester,
    ) async {
      final summary = makeTestTaskSummary(
        task: makeTestTask(id: 't1', title: 'Build feature'),
        oneLiner: 'Implementation phase done, release next',
        estimatedDuration: const Duration(minutes: 45),
      );

      await tester.pumpWidget(
        wrap(TaskSummaryRow(summary: summary)),
      );
      await tester.pump();

      expect(find.text('Build feature'), findsOneWidget);
      expect(
        find.text('Implementation phase done, release next'),
        findsOneWidget,
      );
      expect(find.text('45m'), findsOneWidget);
      expect(find.byIcon(LottiIcons.timer), findsOneWidget);
      expect(find.byIcon(LottiIcons.chevronRight), findsNothing);
    });

    testWidgets('calls onTap when the row is tapped', (tester) async {
      final summary = makeTestTaskSummary(
        task: makeTestTask(id: 't1', title: 'Build feature'),
      );
      Object? tappedSummary;

      await tester.pumpWidget(
        wrap(
          TaskSummaryRow(
            summary: summary,
            onTap: (value) => tappedSummary = value,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Build feature'));
      await tester.pump();

      expect(tappedSummary, same(summary));
    });

    testWidgets('uses the lighter Figma body-small task title style', (
      tester,
    ) async {
      final summary = makeTestTaskSummary(
        task: makeTestTask(id: 't1', title: 'Build feature'),
      );

      await tester.pumpWidget(
        wrap(TaskSummaryRow(summary: summary)),
      );
      await tester.pump();

      final title = tester.widget<Text>(find.text('Build feature'));

      expect(title.style?.fontSize, 14);
      expect(title.style?.fontWeight, FontWeight.w400);
      expect(title.style?.height, closeTo(1.4286, 0.0001));
    });

    testWidgets(
      'uses the Figma subtitle style for the one-liner',
      (tester) async {
        final summary = makeTestTaskSummary(
          task: makeTestTask(id: 't1', title: 'Build feature'),
          oneLiner: 'Implementation phase done, release next',
        );

        await tester.pumpWidget(
          wrap(TaskSummaryRow(summary: summary)),
        );
        await tester.pump();

        final subtitle = tester.widget<Text>(
          find.text('Implementation phase done, release next'),
        );

        expect(subtitle.style?.fontSize, 12);
        expect(subtitle.style?.fontWeight, FontWeight.w400);
        expect(subtitle.style?.height, closeTo(1.3333, 0.0001));
        expect(subtitle.style?.letterSpacing, 0.25);
        expect(subtitle.maxLines, 3);
      },
    );

    testWidgets(
      'uses the same body-small typography for duration and task status',
      (tester) async {
        final summary = makeTestTaskSummary(
          task: makeTestTask(id: 't1', title: 'Build feature'),
          estimatedDuration: const Duration(minutes: 45),
        );

        await tester.pumpWidget(
          wrap(TaskSummaryRow(summary: summary)),
        );
        await tester.pump();

        final duration = tester.widget<Text>(find.text('45m'));
        final status = tester.widget<Text>(find.text('Open'));

        expect(duration.style?.fontSize, 14);
        expect(duration.style?.fontWeight, FontWeight.w400);
        expect(duration.style?.height, closeTo(1.4286, 0.0001));
        expect(status.style?.fontSize, duration.style?.fontSize);
        expect(status.style?.fontWeight, duration.style?.fontWeight);
        expect(status.style?.height, duration.style?.height);
      },
    );

    testWidgets('uses a 16px timer icon in the metadata row', (tester) async {
      final summary = makeTestTaskSummary(
        task: makeTestTask(id: 't1', title: 'Build feature'),
        estimatedDuration: const Duration(minutes: 45),
      );

      await tester.pumpWidget(
        wrap(TaskSummaryRow(summary: summary)),
      );
      await tester.pump();

      final icon = tester.widget<Icon>(find.byIcon(LottiIcons.timer));
      expect(icon.size, 16);
    });

    testWidgets('omits the subtitle when the task has no one-liner', (
      tester,
    ) async {
      final summary = makeTestTaskSummary(
        task: makeTestTask(id: 't1', title: 'Build feature'),
        estimatedDuration: const Duration(minutes: 45),
      );

      await tester.pumpWidget(
        wrap(TaskSummaryRow(summary: summary)),
      );
      await tester.pump();

      final titleRect = tester.getRect(find.text('Build feature'));
      final statusRect = tester.getRect(find.text('Open'));

      expect(
        find.text('Implementation phase done, release next'),
        findsNothing,
      );
      expect(statusRect.top, greaterThan(titleRect.bottom - 1));
    });

    testWidgets(
      'lets the title and one-liner wrap while keeping metadata below them',
      (tester) async {
        const longTitle =
            'Sync database optimization and recovery tooling for long-running '
            'offline reconciliation';
        const longOneLiner =
            'Implementation phase is done, but release validation, rollout '
            'notes, and post-release monitoring still need to be completed.';

        final summary = makeTestTaskSummary(
          task: makeTestTask(id: 't1', title: longTitle),
          oneLiner: longOneLiner,
          estimatedDuration: const Duration(hours: 2, minutes: 30),
        );

        await tester.pumpWidget(
          wrap(
            SizedBox(
              width: 260,
              child: TaskSummaryRow(summary: summary),
            ),
          ),
        );
        await tester.pump();

        final titleFinder = find.text(longTitle);
        final subtitleFinder = find.text(longOneLiner);
        final statusFinder = find.text('Open');
        final titleRect = tester.getRect(titleFinder);
        final subtitleRect = tester.getRect(subtitleFinder);
        final statusRect = tester.getRect(statusFinder);

        expect(tester.getSize(titleFinder).height, greaterThan(20));
        expect(tester.getSize(subtitleFinder).height, greaterThan(16));
        expect(subtitleRect.top, greaterThan(titleRect.bottom - 1));
        expect(statusRect.top, greaterThan(subtitleRect.bottom - 1));
      },
    );

    testWidgets('extends hover fill to the full task row segment', (
      tester,
    ) async {
      final summary = makeTestTaskSummary(
        task: makeTestTask(id: 't1', title: 'Build feature'),
      );

      await tester.pumpWidget(
        wrap(
          SizedBox(
            height: 600,
            child: CustomScrollView(
              slivers: [
                ProjectTasksSliverPanel(
                  record: makeTestProjectRecord(
                    highlightedTaskSummaries: [
                      summary,
                      makeTestTaskSummary(
                        task: makeTestTask(id: 't2', title: 'Second task'),
                      ),
                    ],
                  ),
                  now: now,
                  options: const ProjectTaskListOptions(
                    groupBy: ProjectTaskGroupBy.none,
                  ),
                  onTaskTap: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final rowFinder = find.text('Build feature');
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer();
      await gesture.moveTo(tester.getCenter(rowFinder));
      await tester.pump();

      final backgroundFinder = find.byKey(
        const ValueKey('task-summary-row-background-t1'),
      );
      final backgroundRect = tester.getRect(backgroundFinder);
      final rowRect = tester.getRect(find.byType(TaskSummaryRow).first);

      expect(backgroundRect.left, rowRect.left);
      expect(backgroundRect.right, rowRect.right);
      expect(backgroundRect.top, lessThan(rowRect.top));
      expect(backgroundRect.bottom, greaterThan(rowRect.bottom));
    });
  });

  group('ProjectTasksSliverPanel', () {
    Widget wrapSliver(
      Widget sliver, {
      double width = 400,
      double textScale = 1,
    }) {
      return makeTestableWidget2(
        Theme(
          data: DesignSystemTheme.dark(),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: CustomScrollView(slivers: [sliver]),
              ),
            ),
          ),
        ),
        mediaQueryData: MediaQueryData(
          size: Size(width, 900),
          textScaler: TextScaler.linear(textScale),
        ),
      );
    }

    TaskSummary summary(
      String id,
      String title, {
      required DateTime createdAt,
      bool done = false,
      Duration estimate = const Duration(hours: 1),
    }) {
      final task = makeTestTask(id: id, title: title, createdAt: createdAt);
      return makeTestTaskSummary(
        task: done
            ? task.copyWith(
                data: task.data.copyWith(
                  status: TaskStatus.done(
                    id: 'done-$id',
                    createdAt: createdAt,
                    utcOffset: 0,
                  ),
                ),
              )
            : task,
        estimatedDuration: estimate,
      );
    }

    final record = makeTestProjectRecord(
      highlightedTaskSummaries: [
        summary('a', 'Implement sync', createdAt: DateTime(2026, 8, 3)),
        summary(
          'b',
          'Offline cache',
          createdAt: DateTime(2026, 9, 2),
          estimate: const Duration(hours: 2, minutes: 30),
        ),
        summary(
          'c',
          'Ship it',
          createdAt: DateTime(2026, 8, 20),
          done: true,
          estimate: const Duration(minutes: 10),
        ),
      ],
      highlightedTasksTotalDuration: const Duration(hours: 3, minutes: 40),
    );

    testWidgets('renders the header with count and total estimate', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapSliver(
          ProjectTasksSliverPanel(record: record, now: now),
          width: 900,
        ),
      );
      await tester.pump();

      expect(find.text('Project Tasks'), findsOneWidget);
      expect(find.text('3'), findsOneWidget, reason: 'count badge');
      expect(find.text('3h 40m'), findsOneWidget, reason: 'total estimate');
    });

    testWidgets(
      'groups by creation month, newest first, and folds done tasks',
      (tester) async {
        await tester.pumpWidget(
          wrapSliver(ProjectTasksSliverPanel(record: record, now: now)),
        );
        await tester.pump();

        expect(find.text('September 2026'), findsOneWidget);
        expect(find.text('August 2026'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
        expect(find.text('· 1 task'), findsNWidgets(3));
        expect(find.text('· 2h 30m'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('September 2026')).dy,
          lessThan(tester.getTopLeft(find.text('August 2026')).dy),
        );
        expect(find.text('Offline cache'), findsOneWidget);
        expect(find.text('Implement sync'), findsOneWidget);
        expect(
          find.text('Ship it'),
          findsNothing,
          reason: 'The Done group starts folded.',
        );

        await tester.tap(find.text('Done'));
        await tester.pump();
        expect(find.text('Ship it'), findsOneWidget);

        await tester.tap(find.text('September 2026'));
        await tester.pump();
        expect(find.text('Offline cache'), findsNothing);
        expect(find.text('Implement sync'), findsOneWidget);
      },
    );

    testWidgets('an ungrouped list shows rows without headers', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapSliver(
          ProjectTasksSliverPanel(
            record: record,
            now: now,
            options: const ProjectTaskListOptions(
              groupBy: ProjectTaskGroupBy.none,
              keepDoneInGroups: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('September 2026'), findsNothing);
      expect(
        find.byKey(const ValueKey('project-task-group-done')),
        findsNothing,
      );
      expect(find.text('Ship it'), findsOneWidget);
      expect(find.text('Offline cache'), findsOneWidget);
    });

    testWidgets('renders only the header for a project without tasks', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapSliver(
          ProjectTasksSliverPanel(
            record: makeTestProjectRecord(),
            now: now,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Project Tasks'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.textContaining('2026'), findsNothing);
    });

    testWidgets('the sort-and-group control reports the current options', (
      tester,
    ) async {
      const options = ProjectTaskListOptions(
        groupBy: ProjectTaskGroupBy.status,
        sortBy: ProjectTaskSortBy.title,
      );
      ProjectTaskListOptions? reported;
      await tester.pumpWidget(
        wrapSliver(
          ProjectTasksSliverPanel(
            record: record,
            now: now,
            options: options,
            onOptionsChanged: (value) => reported = value,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Sort and group'));
      expect(reported, options);

      await tester.pumpWidget(
        wrapSliver(ProjectTasksSliverPanel(record: record, now: now)),
      );
      await tester.pump();
      expect(
        find.byTooltip('Sort and group'),
        findsNothing,
        reason: 'A read-only showcase wires no control.',
      );
    });

    testWidgets('Add task is labelled when wide and a glyph when compact', (
      tester,
    ) async {
      var requests = 0;
      Widget panel({bool adding = false, bool enabled = true}) =>
          ProjectTasksSliverPanel(
            record: record,
            now: now,
            onAddTask: () => requests++,
            isAddingTask: adding,
            isAddTaskEnabled: enabled,
          );

      await tester.pumpWidget(wrapSliver(panel(), width: 900));
      await tester.pump();
      expect(find.text('Add task'), findsOneWidget);
      await tester.tap(find.text('Add task'));
      expect(requests, 1);
      expect(find.text('3h 40m'), findsOneWidget);

      await tester.pumpWidget(wrapSliver(panel()));
      await tester.pump();
      expect(find.text('Add task'), findsNothing);
      await tester.tap(find.byTooltip('Add task'));
      expect(requests, 2);
      expect(
        find.text('3h 40m'),
        findsNothing,
        reason: 'The compact header leaves estimates to the group headers.',
      );
      expect(find.text('Project Tasks'), findsOneWidget);

      await tester.pumpWidget(wrapSliver(panel(), width: 900, textScale: 1.3));
      await tester.pump();
      expect(find.text('3h 40m'), findsNothing, reason: 'Large text compacts.');
      expect(find.text('Add task'), findsNothing);
      expect(find.byTooltip('Add task'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(wrapSliver(panel(adding: true), width: 900));
      await tester.pump();
      final button = tester.widget<DesignSystemButton>(
        find.byType(DesignSystemButton),
      );
      expect(button.isLoading, isTrue);
      expect(button.onPressed, isNull);

      await tester.pumpWidget(wrapSliver(panel(enabled: false)));
      await tester.pump();
      final glyph = tester.widget<DesignSystemIconAction>(
        find.byWidgetPredicate(
          (w) => w is DesignSystemIconAction && w.tooltip == 'Add task',
        ),
      );
      expect(glyph.onPressed, isNull);

      await tester.pumpWidget(
        wrapSliver(ProjectTasksSliverPanel(record: record, now: now)),
      );
      await tester.pump();
      expect(find.byTooltip('Add task'), findsNothing);
      expect(find.text('Add task'), findsNothing);
    });

    testWidgets('due-window groups move on at local midnight', (
      tester,
    ) async {
      final task = makeTestTask(
        id: 'due',
        title: 'Feed the penguins',
        createdAt: DateTime(2026, 9),
      );
      final dueToday = makeTestTaskSummary(
        task: task.copyWith(
          data: task.data.copyWith(due: DateTime(2026, 9, 5, 8)),
        ),
      );
      final beforeMidnight = DateTime(2026, 9, 5, 23, 59);
      await withClock(Clock.fixed(DateTime(2026, 9, 6, 0, 1)), () async {
        await tester.pumpWidget(
          wrapSliver(
            ProjectTasksSliverPanel(
              record: makeTestProjectRecord(
                highlightedTaskSummaries: [dueToday],
              ),
              now: beforeMidnight,
              options: const ProjectTaskListOptions(
                groupBy: ProjectTaskGroupBy.dueWindow,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('This week'), findsOneWidget);
        expect(find.text('Overdue'), findsNothing);

        await tester.pump(const Duration(minutes: 1, seconds: 2));

        expect(find.text('Overdue'), findsOneWidget);
        expect(find.text('This week'), findsNothing);
      });
    });

    testWidgets('forwards row taps to onTaskTap with the tapped summary', (
      tester,
    ) async {
      final tapped = summary('t', 'Tap me', createdAt: DateTime(2026, 9));
      TaskSummary? received;
      await tester.pumpWidget(
        wrapSliver(
          ProjectTasksSliverPanel(
            record: makeTestProjectRecord(highlightedTaskSummaries: [tapped]),
            now: now,
            onTaskTap: (s) => received = s,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Tap me'));
      await tester.pump();

      expect(received, same(tapped));
    });
  });
}
