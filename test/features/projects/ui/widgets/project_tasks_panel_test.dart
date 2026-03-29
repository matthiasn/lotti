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
    testWidgets('renders task title and estimated duration', (tester) async {
      final summary = makeTestTaskSummary(
        task: makeTestTask(id: 't1', title: 'Build feature'),
        estimatedDuration: const Duration(minutes: 45),
      );

      await tester.pumpWidget(
        wrap(TaskSummaryRow(summary: summary)),
      );
      await tester.pump();

      expect(find.text('Build feature'), findsOneWidget);
      expect(find.text('45m'), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
      expect(
        find.byIcon(Icons.arrow_forward_ios_rounded),
        findsOneWidget,
      );
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
      'uses the same caption-sized typography for duration and task status',
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

        expect(duration.style?.fontSize, 12);
        expect(duration.style?.fontWeight, FontWeight.w400);
        expect(status.style?.fontSize, duration.style?.fontSize);
        expect(status.style?.fontWeight, duration.style?.fontWeight);
      },
    );

    testWidgets(
      'allows long titles to wrap and keeps status metadata below the title',
      (tester) async {
        const longTitle =
            'Sync database optimization and recovery tooling for long-running '
            'offline reconciliation';
        final summary = makeTestTaskSummary(
          task: makeTestTask(id: 't1', title: longTitle),
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
        final statusFinder = find.text('Open');
        final titleRect = tester.getRect(titleFinder);
        final statusRect = tester.getRect(statusFinder);

        expect(tester.getSize(titleFinder).height, greaterThan(20));
        expect(statusRect.top, greaterThan(titleRect.bottom - 1));
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
