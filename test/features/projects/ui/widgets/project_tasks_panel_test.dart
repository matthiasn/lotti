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
  });
}
