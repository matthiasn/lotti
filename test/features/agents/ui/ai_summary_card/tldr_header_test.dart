import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_data/entity_factories.dart';
import 'test_bench.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiSummaryCard – TLDR header', () {
    testWidgets(
      'shows a spinner instead of the refresh affordance while the agent is running',
      (tester) async {
        final bench = AgentTestBench(
          isRunning: true,
          report: makeTestReport(tldr: 'Tldr line.'),
        );

        await tester.pumpWidget(bench.build());
        // The spinner animates indefinitely, so pumpAndSettle would
        // time out. Pump until the async providers (taskAgent, report)
        // have all resolved and the header has rebuilt with isRunning.
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byIcon(Icons.refresh_rounded), findsNothing);
      },
    );

    testWidgets(
      'stacks controls under the title block on narrow viewports (Wrap layout)',
      (tester) async {
        final bench = AgentTestBench(
          report: makeTestReport(tldr: 'Tldr line.'),
          // Narrower than the 360px stacked-header threshold so the
          // LayoutBuilder picks the Column-with-Wrap branch.
          mediaQueryData: const MediaQueryData(size: Size(320, 800)),
        );

        await tester.pumpWidget(bench.build());
        await tester.pumpAndSettle();

        // The narrow branch wraps the wake / read-more controls in a Wrap
        // run below the title block.
        expect(find.byType(Wrap), findsOneWidget);
        // Title and agent name should still be visible.
        expect(find.text('AI summary'), findsOneWidget);
        expect(find.text('Test Agent'), findsOneWidget);
      },
    );

    testWidgets(
      'countdown pill expiry collapses the wake cluster back to refresh',
      (tester) async {
        final start = DateTime(2026, 5, 4, 12);
        var now = start;
        final nextWakeAt = start.add(const Duration(seconds: 2));

        await withClock(Clock(() => now), () async {
          final bench = AgentTestBench(
            state: makeTestState(nextWakeAt: nextWakeAt),
            report: makeTestReport(tldr: 'Tldr line.'),
          );

          await tester.pumpWidget(bench.build());
          await tester.pumpAndSettle();

          // Initial: countdown pill visible, no refresh affordance.
          expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
          expect(find.byIcon(Icons.close_rounded), findsOneWidget);
          expect(find.byIcon(Icons.refresh_rounded), findsNothing);

          // Advance wall-clock past nextWakeAt and let the periodic
          // timer fire; the mixin should call onCountdownExpired which
          // forwards to the parent's setState callback.
          now = start.add(const Duration(seconds: 3));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump();

          // Wake cluster gone, refresh affordance back.
          expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
          expect(find.byIcon(Icons.close_rounded), findsNothing);
          expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
        });
      },
    );
  });
}
