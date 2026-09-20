import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/ui/ai_summary_card.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/tldr_section_part.dart';
import 'package:lotti/features/design_system/components/buttons/ds_ai_disc_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tts/ui/widgets/tts_play_button.dart';

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

    testWidgets('Chat is a disc leading the header rail, left of the '
        'read-aloud disc, and opens the task chat', (tester) async {
      final bench = AgentTestBench(
        enableSummaryTts: true,
        report: makeTestReport(
          tldr: 'Card surface is happy.',
          content: '## Goal\nShip the card.\n',
        ),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      // No pill beside Read more any more: the disc is glyph-only.
      expect(find.text('Chat'), findsNothing);
      final chat = find.byWidgetPredicate(
        (w) => w is DsAiDiscButton && w.icon == LottiIcons.chat,
      );
      expect(chat, findsOneWidget);
      expect(
        find.ancestor(of: chat, matching: find.byType(TldrHeader)),
        findsOneWidget,
      );
      expect(
        find.ancestor(of: chat, matching: find.byType(TldrBody)),
        findsNothing,
      );

      final chatRect = tester.getRect(chat);
      final ttsRect = tester.getRect(find.byType(TtsPlayButton));
      expect(chatRect.size, ttsRect.size);
      expect(chatRect.center.dy, moreOrLessEquals(ttsRect.center.dy));
      expect(chatRect.right, lessThanOrEqualTo(ttsRect.left));
      // The rail stays flush to the card's trailing edge.
      final header = tester.getRect(find.byType(TldrHeader));
      expect(ttsRect.right, greaterThan(header.center.dx));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AiSummaryCard)),
      );
      const scope = QueryScope(
        kind: QueryScopeKind.task,
        id: AgentTestBench.taskId,
      );
      expect(container.read(queryPaneOpenProvider(scope)), isFalse);
      await tester.tap(chat);
      expect(container.read(queryPaneOpenProvider(scope)), isTrue);
    });

    testWidgets('without read-aloud, the Chat disc holds the trailing edge '
        'alone, even before there is a summary', (tester) async {
      await tester.pumpWidget(AgentTestBench().build());
      await tester.pumpAndSettle();

      expect(find.byType(TtsPlayButton), findsNothing);
      final chat = find.byWidgetPredicate(
        (w) => w is DsAiDiscButton && w.icon == LottiIcons.chat,
      );
      expect(
        find.ancestor(of: chat, matching: find.byType(TldrHeader)),
        findsOneWidget,
      );
      final header = tester.getRect(find.byType(TldrHeader));
      expect(tester.getRect(chat).center.dx, greaterThan(header.center.dx));
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

      // The internals link rides the same row in both states: it is the only
      // door to the agent's schedule and AI setup, so collapsing the report
      // must not take it away.
      expect(find.text('Open agent internals'), findsOneWidget);

      await tester.tap(find.text('Read more'));
      await tester.pumpAndSettle();
      expect(find.text('Show less'), findsOneWidget);
      expect(find.text('Open agent internals'), findsOneWidget);

      await tester.tap(find.text('Show less'));
      await tester.pumpAndSettle();
      expect(find.text('Read more'), findsOneWidget);
      expect(find.text('Open agent internals'), findsOneWidget);
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
      await tester.pumpAndSettle();

      expect(find.text('Agent internals'), findsOneWidget);
      // The panel is where the card's maintenance band went: the switch,
      // the schedule and the model identity are all behind this tap.
      expect(find.text('Automatic updates'), findsOneWidget);
      // The tiered caption paints a measured candidate per width tier, so
      // the route string legitimately matches more than one text node.
      expect(find.text('test-model · via Test Provider'), findsWidgets);
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
      expect(find.text('Automatic updates'), findsOneWidget);
    });
  });
}
