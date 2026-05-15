import 'package:clock/clock.dart';
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
    testWidgets('lazily builds far task rows as the detail page scrolls', (
      tester,
    ) async {
      final record = makeTestProjectRecord(
        highlightedTaskSummaries: List.generate(
          50,
          (index) => makeTestTaskSummary(
            task: makeTestTask(
              id: 'task-$index',
              title: 'Task $index',
            ),
            oneLiner: 'Summary line $index',
          ),
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

      expect(find.text('Task 0'), findsOneWidget);
      expect(find.text('Task 49'), findsNothing);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -8000));
      await tester.pump();

      expect(find.text('Task 49'), findsOneWidget);
    });

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

    testWidgets('uses the heading 3 title size from Figma', (tester) async {
      final record = makeTestProjectRecord(
        project: makeTestProject(
          id: 'project-1',
          title: 'Design system',
          categoryId: 'cat-1',
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

      final title = tester.widget<Text>(find.text('Design system'));

      expect(title.style?.fontSize, 20);
      expect(title.style?.fontWeight, FontWeight.w700);
      expect(title.style?.height, closeTo(1.4, 0.0001));
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
        final now = DateTime(2026, 3, 28, 1, 18);
        await withClock(Clock.fixed(now), () async {
          final record = makeTestProjectRecord(
            reportUpdatedAt: DateTime(2026, 3, 28, 1, 17),
            reportNextWakeAt: now.add(const Duration(seconds: 90)),
          );

          await tester.pumpWidget(
            wrap(
              ProjectMobileDetailContent(
                record: record,
                currentTime: now,
                onRefreshReport: () {},
              ),
            ),
          );
          await tester.pump();

          expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
          expect(find.byType(ShowcaseCountdownPill), findsOneWidget);
          expect(find.textContaining('Updated 1m ago'), findsOneWidget);
          expect(find.textContaining('↻'), findsNothing);
        });
      },
    );

    testWidgets(
      'forwards onCancelScheduledReportWake through to the underlying '
      'ExpandableReportSection so a tap on the report cancel × routes to '
      'the same callback the project details page wires up',
      (tester) async {
        var cancelCount = 0;
        final now = DateTime(2026, 3, 28, 1, 18);
        await withClock(Clock.fixed(now), () async {
          final record = makeTestProjectRecord(
            reportUpdatedAt: DateTime(2026, 3, 28, 1, 17),
            reportNextWakeAt: now.add(const Duration(seconds: 90)),
          );

          await tester.pumpWidget(
            wrap(
              ProjectMobileDetailContent(
                record: record,
                currentTime: now,
                onRefreshReport: () {},
                onCancelScheduledReportWake: () => cancelCount++,
              ),
            ),
          );
          await tester.pump();

          // Verify the prop reached the inner widget (catches a wiring bug
          // earlier than tapping would).
          final report = tester.widget<ExpandableReportSection>(
            find.byType(ExpandableReportSection),
          );
          expect(report.onCancelScheduledWake, isNotNull);

          // Then prove the callback is the same one we passed by invoking
          // it via the inner widget — `find.byIcon(Icons.close_rounded)`
          // would also match the X on individual recommendation tiles, so
          // we drive the report-section callback directly.
          report.onCancelScheduledWake!();
          expect(cancelCount, 1);
        });
      },
    );

    testWidgets(
      'leaves the ExpandableReportSection cancel callback null when the '
      'page does not pass onCancelScheduledReportWake (no agent identity)',
      (tester) async {
        final now = DateTime(2026, 3, 28, 1, 18);
        await withClock(Clock.fixed(now), () async {
          final record = makeTestProjectRecord(
            reportUpdatedAt: DateTime(2026, 3, 28, 1, 17),
            reportNextWakeAt: now.add(const Duration(seconds: 90)),
          );

          await tester.pumpWidget(
            wrap(
              ProjectMobileDetailContent(
                record: record,
                currentTime: now,
                onRefreshReport: () {},
              ),
            ),
          );
          await tester.pump();

          final report = tester.widget<ExpandableReportSection>(
            find.byType(ExpandableReportSection),
          );
          expect(report.onCancelScheduledWake, isNull);
        });
      },
    );
  });
}
