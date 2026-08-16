import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';
import 'package:lotti/features/projects/ui/widgets/health_panel.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  Widget wrap(Widget child) {
    return makeTestableWidget2(
      Theme(
        data: DesignSystemTheme.dark(),
        child: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(width: 700, child: child),
          ),
        ),
      ),
    );
  }

  group('HealthPanel', () {
    testWidgets('renders the agent-authored health assessment', (tester) async {
      final record = makeTestProjectRecord(
        healthMetrics: makeTestProjectHealthMetrics(
          band: ProjectHealthBand.atRisk,
          rationale: 'The launch dependency is slipping behind plan.',
          confidence: 0.87,
        ),
      );

      await tester.pumpWidget(
        wrap(HealthPanel(record: record)),
      );
      await tester.pump();

      expect(find.text('At Risk'), findsOneWidget);
      expect(
        find.text('The launch dependency is slipping behind plan.'),
        findsOneWidget,
      );
      expect(find.text('87% confidence'), findsOneWidget);
      expect(find.text('Health Score'), findsNothing);
    });

    testWidgets('labels assessment provenance and report freshness', (
      tester,
    ) async {
      final record = makeTestProjectRecord(
        healthMetrics: makeTestProjectHealthMetrics(),
        reportUpdatedAt: DateTime(2026, 8, 16, 8),
      );

      await tester.pumpWidget(
        wrap(
          HealthPanel(
            record: record,
            currentTime: DateTime(2026, 8, 16, 10),
          ),
        ),
      );

      expect(find.text('AI Report · Updated 2h ago'), findsOneWidget);
    });

    testWidgets('renders blocked task count', (tester) async {
      final record = makeTestProjectRecord(
        blockedTaskCount: 3,
        healthMetrics: makeTestProjectHealthMetrics(),
      );

      await tester.pumpWidget(
        wrap(HealthPanel(record: record)),
      );
      await tester.pump();

      // Exact localized strings, so a stray '3' elsewhere can't satisfy
      // the assertion: blocked count appears in the banner and the legend.
      expect(find.text('3 tasks blocked'), findsOneWidget);
      expect(find.text('3 Blocked'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('renders tasks completion progress', (tester) async {
      final record = makeTestProjectRecord(
        completedTaskCount: 4,
        totalTaskCount: 8,
        healthMetrics: makeTestProjectHealthMetrics(),
      );

      await tester.pumpWidget(
        wrap(HealthPanel(record: record)),
      );
      await tester.pump();

      // The progress bar renders the exact completed/total string.
      expect(find.text('4/8 tasks completed'), findsOneWidget);
      expect(find.text('4 Completed'), findsOneWidget);
    });

    testWidgets('describes a zero-task project without implying bad progress', (
      tester,
    ) async {
      final record = makeTestProjectRecord(
        completedTaskCount: 0,
        totalTaskCount: 0,
        blockedTaskCount: 0,
        healthMetrics: makeTestProjectHealthMetrics(),
      );

      await tester.pumpWidget(wrap(HealthPanel(record: record)));
      await tester.pump();

      expect(find.text('No tasks'), findsOneWidget);
      expect(find.text('0/0 tasks completed'), findsNothing);
    });

    testWidgets('renders legend items', (tester) async {
      final record = makeTestProjectRecord(
        completedTaskCount: 2,
        healthMetrics: makeTestProjectHealthMetrics(),
      );

      await tester.pumpWidget(
        wrap(HealthPanel(record: record)),
      );
      await tester.pump();

      expect(find.textContaining('Completed'), findsOneWidget);
      expect(find.textContaining('Blocked'), findsOneWidget);
    });

    testWidgets('only exposes the blocker action when it can do work', (
      tester,
    ) async {
      var taps = 0;
      final clearRecord = makeTestProjectRecord(
        blockedTaskCount: 0,
        healthMetrics: makeTestProjectHealthMetrics(),
      );

      await tester.pumpWidget(
        wrap(
          HealthPanel(
            record: clearRecord,
            onViewBlockerPressed: () => taps++,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('View blocker'), findsNothing);

      final blockedRecord = makeTestProjectRecord(
        blockedTaskCount: 2,
        healthMetrics: makeTestProjectHealthMetrics(
          band: ProjectHealthBand.blocked,
        ),
      );
      await tester.pumpWidget(
        wrap(
          HealthPanel(
            record: blockedRecord,
            onViewBlockerPressed: () => taps++,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('View blocker'), findsOneWidget);
      await tester.tap(find.text('View blocker'));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('ProjectHealthEmptyState', () {
    testWidgets('shows distinct guidance when the project has no agent', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const ProjectHealthEmptyState(
            hasAgent: false,
          ),
        ),
      );

      expect(
        find.text(
          'No project agent has been provisioned for this project yet.',
        ),
        findsOneWidget,
      );
      expect(find.text('Run report'), findsNothing);
    });

    testWidgets('offers agent assignment when provisioning is missing', (
      tester,
    ) async {
      var assignmentRequests = 0;
      await tester.pumpWidget(
        wrap(
          ProjectHealthEmptyState(
            hasAgent: false,
            onAssignAgent: () => assignmentRequests++,
          ),
        ),
      );

      await tester.tap(
        find.widgetWithText(DesignSystemButton, 'Assign an agent'),
      );

      expect(assignmentRequests, 1);
      expect(find.text('Run report'), findsNothing);
    });

    testWidgets(
      'keeps the report action visible but non-interactive while busy',
      (
        tester,
      ) async {
        var taps = 0;
        await tester.pumpWidget(
          wrap(
            ProjectHealthEmptyState(
              onRunReport: () => taps++,
              isRunningReport: true,
            ),
          ),
        );
        await tester.pump();

        final action = tester.widget<DesignSystemButton>(
          find.widgetWithText(DesignSystemButton, 'Run report'),
        );
        expect(action.isLoading, isTrue);
        expect(action.onPressed, isNotNull);
        await tester.tap(find.widgetWithText(DesignSystemButton, 'Run report'));
        await tester.pump();
        expect(taps, 0);
      },
    );
  });
}
