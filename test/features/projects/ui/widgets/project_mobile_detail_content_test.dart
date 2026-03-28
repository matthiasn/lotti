import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';
import 'package:lotti/features/projects/ui/widgets/project_mobile_detail_content.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  Widget wrap(
    Widget child, {
    Size size = const Size(430, 900),
  }) {
    return makeTestableWidget2(
      Theme(
        data: DesignSystemTheme.dark(),
        child: Scaffold(body: child),
      ),
      mediaQueryData: MediaQueryData(
        size: size,
        padding: const EdgeInsets.only(top: 20),
      ),
    );
  }

  group('ProjectMobileDetailContent', () {
    testWidgets('places the risk chip in the metadata row below the title', (
      tester,
    ) async {
      final record = makeTestProjectRecord(
        project: makeTestProject(
          id: 'project-1',
          title: 'Design system',
          categoryId: 'cat-1',
          targetDate: DateTime(2026, 3, 26),
          status: ProjectStatus.active(
            id: 'active',
            createdAt: DateTime(2026, 3, 20),
            utcOffset: 0,
          ),
        ),
        healthMetrics: makeTestProjectHealthMetrics(
          band: ProjectHealthBand.atRisk,
          rationale: 'The critical path is slipping behind plan.',
        ),
      );

      await tester.pumpWidget(
        wrap(
          ProjectMobileDetailContent(
            record: record,
            currentTime: DateTime(2026, 3, 28, 1, 18),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Design system'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('At Risk'), findsOneWidget);
      expect(find.byIcon(Icons.unfold_more_rounded), findsOneWidget);

      final titleTop = tester.getTopLeft(find.text('Design system'));
      final statusTop = tester.getTopLeft(find.text('Active'));
      final categoryTop = tester.getTopLeft(find.text('Work'));
      final riskTop = tester.getTopLeft(find.text('At Risk'));

      expect((statusTop.dy - titleTop.dy).abs(), lessThan(8));
      expect(riskTop.dy, greaterThan(titleTop.dy));
      expect((riskTop.dy - categoryTop.dy).abs(), lessThan(8));
      expect(riskTop.dx, greaterThan(categoryTop.dx));
      expect(statusTop.dx, greaterThan(categoryTop.dx));
    });

    testWidgets(
      'moves the status pill to its own right-aligned line when the title is too wide',
      (
        tester,
      ) async {
        final record = makeTestProjectRecord(
          project: makeTestProject(
            id: 'project-1',
            title:
                'A very long project title that should force the active selector onto a new line',
            categoryId: 'cat-1',
            targetDate: DateTime(2026, 3, 26),
            status: ProjectStatus.active(
              id: 'active',
              createdAt: DateTime(2026, 3, 20),
              utcOffset: 0,
            ),
          ),
        );

        await tester.pumpWidget(
          wrap(
            ProjectMobileDetailContent(
              record: record,
              currentTime: DateTime(2026, 3, 28, 1, 18),
            ),
            size: const Size(320, 900),
          ),
        );
        await tester.pump();

        final titleTop = tester.getTopLeft(
          find.textContaining('A very long project title'),
        );
        final statusTop = tester.getTopLeft(find.text('Active'));

        expect(statusTop.dy, greaterThan(titleTop.dy));
      },
    );

    testWidgets(
      'shows one refresh icon and a countdown pill in the report header',
      (
        tester,
      ) async {
        final record = makeTestProjectRecord(
          reportUpdatedAt: DateTime(2026, 3, 28, 1, 17),
          // Must be in the future relative to DateTime.now() because the
          // widget's _remainingSeconds() computes against the real clock.
          // ignore: avoid_redundant_argument_values
          reportNextWakeAt: DateTime(2099, 1, 1),
        );

        await tester.pumpWidget(
          wrap(
            ProjectMobileDetailContent(
              record: record,
              currentTime: DateTime(2026, 3, 28, 1, 18),
              onRefreshReport: () {},
            ),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
        expect(find.byType(ShowcaseCountdownPill), findsOneWidget);
        expect(find.textContaining('Updated 1m ago'), findsOneWidget);
        expect(find.textContaining('↻'), findsNothing);
      },
    );
  });
}
