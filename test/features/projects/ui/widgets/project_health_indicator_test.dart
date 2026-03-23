import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';
import 'package:lotti/features/projects/ui/widgets/project_health_indicator.dart';

import '../../../../widget_test_utils.dart';

void main() {
  ProjectHealthMetrics makeMetrics({
    required ProjectHealthBand band,
    required ProjectHealthReasonKind reasonKind,
    int? count,
  }) {
    return ProjectHealthMetrics(
      band: band,
      score: 72,
      reason: ProjectHealthReason(reasonKind, count: count),
      totalTaskCount: 4,
      completedTaskCount: 2,
      stalledTaskCount: 0,
      overdueTaskCount: 0,
      isSummaryOutdated: false,
      targetDatePassed: false,
      hasRecentTaskUpdate: true,
    );
  }

  group('ProjectHealthIndicator', () {
    final cases =
        <
          ({
            ProjectHealthBand band,
            ProjectHealthReasonKind reasonKind,
            int? count,
            String expectedBandLabel,
            String expectedReasonLabel,
          })
        >[
          (
            band: ProjectHealthBand.surviving,
            reasonKind: ProjectHealthReasonKind.noLinkedTasks,
            count: null,
            expectedBandLabel: 'Surviving',
            expectedReasonLabel: 'No linked tasks yet.',
          ),
          (
            band: ProjectHealthBand.surviving,
            reasonKind: ProjectHealthReasonKind.summaryOutdated,
            count: null,
            expectedBandLabel: 'Surviving',
            expectedReasonLabel: 'The project summary is outdated.',
          ),
          (
            band: ProjectHealthBand.onTrack,
            reasonKind: ProjectHealthReasonKind.steadyProgress,
            count: null,
            expectedBandLabel: 'On Track',
            expectedReasonLabel: 'The project is moving steadily.',
          ),
          (
            band: ProjectHealthBand.onTrack,
            reasonKind: ProjectHealthReasonKind.projectCompleted,
            count: null,
            expectedBandLabel: 'On Track',
            expectedReasonLabel: 'The project is complete.',
          ),
          (
            band: ProjectHealthBand.watch,
            reasonKind: ProjectHealthReasonKind.noRecentProgress,
            count: null,
            expectedBandLabel: 'Watch',
            expectedReasonLabel: 'No recent progress.',
          ),
          (
            band: ProjectHealthBand.atRisk,
            reasonKind: ProjectHealthReasonKind.overdueTasks,
            count: 2,
            expectedBandLabel: 'At Risk',
            expectedReasonLabel: '2 tasks are overdue',
          ),
          (
            band: ProjectHealthBand.atRisk,
            reasonKind: ProjectHealthReasonKind.targetDatePassed,
            count: null,
            expectedBandLabel: 'At Risk',
            expectedReasonLabel: 'The target date has passed.',
          ),
          (
            band: ProjectHealthBand.blocked,
            reasonKind: ProjectHealthReasonKind.stalledTasks,
            count: 1,
            expectedBandLabel: 'Blocked',
            expectedReasonLabel: '1 task is stalled',
          ),
          (
            band: ProjectHealthBand.blocked,
            reasonKind: ProjectHealthReasonKind.projectOnHold,
            count: null,
            expectedBandLabel: 'Blocked',
            expectedReasonLabel: 'The project is on hold.',
          ),
        ];

    for (final testCase in cases) {
      testWidgets(
        'renders ${testCase.expectedBandLabel} with ${testCase.reasonKind.name}',
        (tester) async {
          await tester.pumpWidget(
            makeTestableWidgetWithScaffold(
              ProjectHealthIndicator(
                metrics: makeMetrics(
                  band: testCase.band,
                  reasonKind: testCase.reasonKind,
                  count: testCase.count,
                ),
              ),
            ),
          );
          await tester.pump();

          expect(find.text(testCase.expectedBandLabel), findsOneWidget);
          expect(find.text(testCase.expectedReasonLabel), findsOneWidget);
        },
      );
    }

    testWidgets('hides the reason text when requested', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProjectHealthIndicator(
            metrics: makeMetrics(
              band: ProjectHealthBand.blocked,
              reasonKind: ProjectHealthReasonKind.stalledTasks,
              count: 2,
            ),
            showReason: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Blocked'), findsOneWidget);
      expect(find.textContaining('stalled'), findsNothing);
    });
  });
}
