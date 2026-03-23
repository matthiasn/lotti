import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';
import 'package:lotti/features/projects/ui/widgets/project_health_indicator.dart';

import '../../../../widget_test_utils.dart';

void main() {
  ProjectHealthMetrics makeMetrics({
    required ProjectHealthBand band,
    required String rationale,
  }) {
    return ProjectHealthMetrics(
      band: band,
      rationale: rationale,
    );
  }

  group('ProjectHealthIndicator', () {
    final cases =
        <
          ({
            ProjectHealthBand band,
            String rationale,
            String expectedBandLabel,
          })
        >[
          (
            band: ProjectHealthBand.surviving,
            rationale: 'This project exists, but it still needs structure.',
            expectedBandLabel: 'Surviving',
          ),
          (
            band: ProjectHealthBand.onTrack,
            rationale: 'Recent work is landing and the scope is stable.',
            expectedBandLabel: 'On Track',
          ),
          (
            band: ProjectHealthBand.watch,
            rationale: 'There is movement, but momentum is fragile.',
            expectedBandLabel: 'Watch',
          ),
          (
            band: ProjectHealthBand.atRisk,
            rationale: 'The critical path is slipping behind plan.',
            expectedBandLabel: 'At Risk',
          ),
          (
            band: ProjectHealthBand.blocked,
            rationale: 'An external dependency is preventing further work.',
            expectedBandLabel: 'Blocked',
          ),
        ];

    for (final testCase in cases) {
      testWidgets(
        'renders ${testCase.expectedBandLabel} with the provided rationale',
        (tester) async {
          await tester.pumpWidget(
            makeTestableWidgetWithScaffold(
              ProjectHealthIndicator(
                metrics: makeMetrics(
                  band: testCase.band,
                  rationale: testCase.rationale,
                ),
              ),
            ),
          );
          await tester.pump();

          expect(find.text(testCase.expectedBandLabel), findsOneWidget);
          expect(find.text(testCase.rationale), findsOneWidget);
        },
      );
    }

    testWidgets('hides the reason text when requested', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProjectHealthIndicator(
            metrics: makeMetrics(
              band: ProjectHealthBand.blocked,
              rationale: 'A dependency is still blocking the next step.',
            ),
            showReason: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Blocked'), findsOneWidget);
      expect(find.textContaining('blocking the next step'), findsNothing);
    });
  });
}
