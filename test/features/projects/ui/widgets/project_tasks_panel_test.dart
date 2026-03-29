import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/projects/ui/widgets/project_tasks_panel.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
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

  group('ProjectTasksPanel', () {
    testWidgets('renders panel header with title and badge', (tester) async {
      final record = makeTestProjectRecord(
        highlightedTaskSummaries: [
          makeTestTaskSummary(),
          makeTestTaskSummary(
            task: makeTestTask(id: 'task-2', title: 'Second Task'),
          ),
        ],
        highlightedTasksTotalDuration: const Duration(minutes: 11, seconds: 38),
      );

      await tester.pumpWidget(wrap(ProjectTasksPanel(record: record)));
      await tester.pump();

      expect(find.text('Project Tasks'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // count badge
      expect(find.text('11m 38s'), findsOneWidget); // total duration
    });

    testWidgets('renders each task summary row', (tester) async {
      final record = makeTestProjectRecord(
        highlightedTaskSummaries: [
          makeTestTaskSummary(
            task: makeTestTask(id: 'task-a', title: 'Implement sync'),
            estimatedDuration: const Duration(hours: 2, minutes: 30),
          ),
          makeTestTaskSummary(
            task: makeTestTask(id: 'task-b', title: 'Offline cache'),
            estimatedDuration: const Duration(hours: 1, minutes: 10),
          ),
        ],
      );

      await tester.pumpWidget(wrap(ProjectTasksPanel(record: record)));
      await tester.pump();

      expect(find.text('Implement sync'), findsOneWidget);
      expect(find.text('Offline cache'), findsOneWidget);
      expect(find.text('2h 30m'), findsOneWidget);
      expect(find.text('1h 10m'), findsOneWidget);
    });

    testWidgets('renders empty when no task summaries', (tester) async {
      final record = makeTestProjectRecord();

      await tester.pumpWidget(wrap(ProjectTasksPanel(record: record)));
      await tester.pump();

      expect(find.text('Project Tasks'), findsOneWidget);
      expect(find.text('0'), findsOneWidget); // count badge
    });
  });

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
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsNothing);
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

      final icon = tester.widget<Icon>(find.byIcon(Icons.timer_outlined));
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
          ProjectTasksPanel(
            record: makeTestProjectRecord(
              highlightedTaskSummaries: [
                summary,
                makeTestTaskSummary(
                  task: makeTestTask(id: 't2', title: 'Second task'),
                ),
              ],
            ),
            onTaskTap: (_) {},
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
}
