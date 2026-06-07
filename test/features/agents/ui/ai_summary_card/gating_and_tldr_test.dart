import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/ai_summary_card.dart';

import '../../../../test_helper.dart';
import '../../test_data/entity_factories.dart';
import '../../test_data/template_factories.dart';
import 'test_bench.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiSummaryCard – gating and CTA', () {
    testWidgets('shows Assign Agent CTA when no agent is attached', (
      tester,
    ) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: const NoAgentOverrides().build(),
          child: const AiSummaryCard(taskId: 'task-001'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Assign Agent'), findsOneWidget);
      expect(find.text('AI summary'), findsNothing);
    });
  });

  group('AiSummaryCard – subtitle', () {
    testWidgets(
      'uses the template displayName for the subtitle when available',
      (tester) async {
        final bench = AgentTestBench(
          template: makeTestTemplate(displayName: 'Task Laura'),
          report: makeTestReport(tldr: 'Tldr line.'),
        );
        await tester.pumpWidget(bench.build());
        await tester.pumpAndSettle();

        // The bold "AI summary" stays unchanged…
        expect(find.text('AI summary'), findsOneWidget);
        // …and the subtitle below is the template name, not the
        // generic agent kind label.
        expect(find.text('Task Laura'), findsOneWidget);
      },
    );

    testWidgets(
      'falls back to the agent display name when no template is assigned',
      (tester) async {
        final bench = AgentTestBench(
          report: makeTestReport(tldr: 'Tldr line.'),
        );
        await tester.pumpWidget(bench.build());
        await tester.pumpAndSettle();

        // `makeTestIdentity()` defaults to "Test Agent" — the subtitle
        // path should fall through to that when the template provider
        // resolves to null.
        expect(find.text('Test Agent'), findsOneWidget);
      },
    );
  });

  group('AiSummaryCard – TLDR', () {
    testWidgets('renders TLDR and Read more pill when an agent has a report', (
      tester,
    ) async {
      final bench = AgentTestBench(
        report: makeTestReport(
          tldr: 'Card surface is happy.',
          content: '## Goal\nShip the card.\n',
        ),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      expect(find.text('AI summary'), findsOneWidget);
      expect(find.text('Card surface is happy.'), findsOneWidget);
      expect(find.text('Read more'), findsOneWidget);
    });

    testWidgets('Read more toggle expands and collapses the report', (
      tester,
    ) async {
      final bench = AgentTestBench(
        report: makeTestReport(
          tldr: 'Tldr line.',
          content: '## Goal\nShip the card.\n',
        ),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Read more'));
      await tester.pumpAndSettle();
      expect(find.text('Show less'), findsOneWidget);
      expect(find.text('Open agent internals'), findsOneWidget);

      await tester.tap(find.text('Show less'));
      await tester.pumpAndSettle();
      expect(find.text('Read more'), findsOneWidget);
      expect(find.text('Open agent internals'), findsNothing);
    });

    testWidgets('Read more pill is hidden when there is no TLDR or report', (
      tester,
    ) async {
      await tester.pumpWidget(AgentTestBench().build());
      await tester.pumpAndSettle();

      expect(find.text('AI summary'), findsOneWidget);
      expect(find.text('Read more'), findsNothing);
    });
  });

  group('AiSummaryCard – internals navigation', () {
    testWidgets('tapping the agent name pushes the AgentInternalsPanel route', (
      tester,
    ) async {
      // `provideAgentIdentity: true` adds the `agentIdentityProvider`
      // override the pushed `AgentInternalsPanel` reads; the rest of the
      // provider wiring comes straight from `AgentTestBench`.
      final bench = AgentTestBench(
        report: makeTestReport(tldr: 'Tldr.'),
        provideAgentIdentity: true,
      );
      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      // The subtitle falls through to the identity display name (no
      // template), which is what the header renders as the tappable name.
      await tester.tap(find.text(makeTestIdentity().displayName));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Agent internals'), findsOneWidget);
    });

    testWidgets('Open agent internals pill (under expanded report) opens it', (
      tester,
    ) async {
      final bench = AgentTestBench(
        report: makeTestReport(
          tldr: 'Tldr.',
          content: '## Goal\nShip.\n',
        ),
        provideAgentIdentity: true,
      );
      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Read more'));
      await tester.pumpAndSettle();
      expect(find.text('Open agent internals'), findsOneWidget);
      await tester.tap(find.text('Open agent internals'));
      await tester.pumpAndSettle();

      expect(find.text('Agent internals'), findsOneWidget);
    });
  });
}
