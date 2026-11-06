import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_internals_body.dart';
import 'package:lotti/features/agents/ui/ai_summary_card.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/tldr_section_part.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/state/skill_entity_provider.dart';
import 'package:lotti/features/design_system/components/buttons/ds_ai_disc_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tts/cloud/cloud_speech_synthesizer.dart';
import 'package:lotti/features/tts/ui/widgets/tts_play_button.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../test_helper.dart';
import '../../../tts/test_utils.dart';
import '../../test_data/ai_config_factories.dart';
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

    testWidgets("a profile's cloud voice reads aloud where the on-device "
        "engine cannot, in the task's language", (tester) async {
      final mistral = testInferenceProvider(
        id: 'mistral',
        inferenceProviderType: InferenceProviderType.mistral,
      );
      final voice = testAiModel(
        id: 'voice-row',
        providerModelId: 'voxtral-mini-tts-3-0',
      );
      final cloud = FakeCloudSpeechSynthesizer();
      final bench = AgentTestBench(
        enableSummaryTts: true,
        ttsEngine: FakeTtsEngine(supported: false),
        report: makeTestReport(tldr: 'Zwei offen.'),
        resolvedSetup: ResolvedAgentSetup(
          status: AgentSetupResolutionStatus.resolved,
          profile: ResolvedProfile(
            thinkingModelId: 'thinking',
            thinkingProvider: mistral,
            speechModelId: voice.providerModelId,
            speechProvider: mistral,
            speechModel: voice,
          ),
        ),
        extraOverrides: [
          cloudSpeechSynthesizerProvider.overrideWithValue(cloud),
          skillEntityProvider(AgentTestBench.taskId).overrideWithValue(
            testTask.copyWith(
              data: testTask.data.copyWith(languageCode: 'de-AT'),
            ),
          ),
        ],
      );
      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TtsPlayButton));
      await tester.pump();

      expect(cloud.calls.single.route.model, voice);
      expect(cloud.calls.single.route.provider, mistral);
      expect(cloud.calls.single.route.languageCode, 'de');
    });

    testWidgets('without a cloud voice, a device lacking the on-device '
        'engine shows no read-aloud control', (tester) async {
      await tester.pumpWidget(
        AgentTestBench(
          enableSummaryTts: true,
          ttsEngine: FakeTtsEngine(supported: false),
          report: makeTestReport(tldr: 'Two open.'),
        ).build(),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TtsPlayButton), findsNothing);
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

  group('AiSummaryCard – unmet request', () {
    final raisedAt = DateTime(2024, 3, 15, 9);
    const reason = 'I could log only one of the five time blocks.';
    const calloutKey = ValueKey('taskAgentUnmetRequest');

    AgentStateEntity flagged({DateTime? clearedAt}) => makeTestState(
      unmetRequestAt: raisedAt,
      unmetRequestReason: reason,
      unmetRequestClearedAt: clearedAt,
    );

    testWidgets('a standing flag leads the body, above the summary', (
      tester,
    ) async {
      await tester.pumpWidget(
        AgentTestBench(
          report: makeTestReport(tldr: 'Tldr line.'),
          state: flagged(),
        ).build(),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(calloutKey), findsOneWidget);
      expect(find.text(reason), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(calloutKey)).dy,
        lessThan(tester.getTopLeft(find.text('Tldr line.')).dy),
      );
    });

    testWidgets('shows before the agent has written any report', (
      tester,
    ) async {
      await tester.pumpWidget(AgentTestBench(state: flagged()).build());
      await tester.pumpAndSettle();

      expect(find.byKey(calloutKey), findsOneWidget);
      expect(find.text(reason), findsOneWidget);
    });

    for (final (label, state) in [
      ('no flag', makeTestState()),
      (
        'a flag the user cleared',
        flagged(clearedAt: raisedAt.add(const Duration(minutes: 5))),
      ),
    ]) {
      testWidgets('stays away with $label', (tester) async {
        await tester.pumpWidget(
          AgentTestBench(
            report: makeTestReport(tldr: 'Tldr line.'),
            state: state,
          ).build(),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(calloutKey), findsNothing);
        expect(find.text("I couldn't do what you asked"), findsNothing);
        expect(find.text('Tldr line.'), findsOneWidget);
      });
    }

    testWidgets('a flag raised or cleared under a shown report keeps the '
        'report in place', (tester) async {
      var current = makeTestState();
      await tester.pumpWidget(
        AgentTestBench(
          report: makeTestReport(tldr: 'Tldr line.'),
          stateOverride: (ref, agentId) async => current,
        ).build(),
      );
      await tester.pumpAndSettle();
      final reportBefore = tester.element(find.byType(TldrBody));

      Future<void> deliver(AgentStateEntity next) async {
        current = next;
        ProviderScope.containerOf(
          tester.element(find.byType(AiSummaryCard)),
        ).invalidate(agentStateProvider);
        await tester.pumpAndSettle();
      }

      // A background wake raises the flag: the callout arrives above the
      // report without rebuilding it, so a selection inside it survives.
      await deliver(flagged());
      expect(find.byKey(calloutKey), findsOneWidget);
      expect(tester.element(find.byType(TldrBody)), same(reportBefore));

      // Cleared on another device: the callout leaves, the report stays put.
      await deliver(flagged(clearedAt: raisedAt.add(const Duration(hours: 1))));
      expect(find.byKey(calloutKey), findsNothing);
      expect(tester.element(find.byType(TldrBody)), same(reportBefore));
    });

    testWidgets("Clear clears this agent's flag", (tester) async {
      final agentService = MockAgentService();
      when(
        () => agentService.clearUnmetRequest(any()),
      ).thenAnswer((_) async {});
      await tester.pumpWidget(
        AgentTestBench(
          state: flagged(),
          extraOverrides: [
            agentServiceProvider.overrideWithValue(agentService),
          ],
        ).build(),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('unmet-request-clear')));
      await tester.pump();

      verify(
        () => agentService.clearUnmetRequest(makeTestIdentity().agentId),
      ).called(1);
    });

    testWidgets('a failed clear says so instead of looking ignored', (
      tester,
    ) async {
      final agentService = MockAgentService();
      when(
        () => agentService.clearUnmetRequest(any()),
      ).thenThrow(StateError('write failed'));
      await tester.pumpWidget(
        AgentTestBench(
          state: flagged(),
          extraOverrides: [
            agentServiceProvider.overrideWithValue(agentService),
          ],
        ).build(),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('unmet-request-clear')));
      await tester.pump();

      expect(find.text('Error'), findsOneWidget);
    });

    testWidgets('See observations opens the internals on the observations', (
      tester,
    ) async {
      await tester.pumpWidget(
        AgentTestBench(state: flagged(), provideAgentIdentity: true).build(),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('unmet-request-observations')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Agent internals'), findsOneWidget);
      expect(
        tester
            .widget<AgentInternalsBody>(find.byType(AgentInternalsBody))
            .initialTab,
        AgentInternalsTab.observations,
      );
    });
  });
}
