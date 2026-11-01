import 'dart:async';

import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/event_agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/ui/agent_automation_row.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/tldr_section_part.dart';
import 'package:lotti/features/agents/ui/widgets/ai_card_chrome.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/events/ui/widgets/event_ai_summary_card.dart';
import 'package:lotti/features/events/ui/widgets/event_passive_summary_card.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/test_utils.dart';

void main() {
  const eventId = 'event-1';
  const agentId = 'agent-1';
  const awaitingHint = 'Add a photo or note and the recap will appear here.';

  final agentIdentity = makeTestIdentity(
    id: agentId,
    agentId: agentId,
    kind: 'event_agent',
    displayName: 'Event Agent',
  );

  /// A model the agent can run on, so Update now is live.
  final resolvedSetup = ResolvedAgentSetup(
    status: AgentSetupResolutionStatus.resolved,
    profile: ResolvedProfile(
      thinkingModelId: 'test-model',
      thinkingProvider: testInferenceProvider(),
      thinkingModel: testAiModel(),
    ),
    source: AgentSetupResolutionSource.baseProfile,
  );

  /// The providers the agent card reads beside the report, settled so a test
  /// only states what it is about.
  List<Override> agentOverrides({
    AgentDomainEntity? agent,
    FutureOr<AgentDomainEntity?> Function()? report,
    bool inferenceDisabled = false,
    MockEventAgentService? service,
  }) => <Override>[
    // Resolved synchronously, so a data-state test does not transit a
    // loading frame (the loading and error states have their own tests).
    eventAgentProvider(eventId).overrideWith((ref) => agent),
    agentReportProvider(agentId).overrideWith((ref) => report?.call()),
    agentIsRunningProvider(agentId).overrideWith((ref) => Stream.value(false)),
    agentStateProvider(agentId).overrideWith((ref) => null),
    taskAgentResolvedSetupProvider(agentId).overrideWith(
      (ref) => inferenceDisabled
          ? const ResolvedAgentSetup(
              status: AgentSetupResolutionStatus.disabled,
            )
          : resolvedSetup,
    ),
    templateForAgentProvider(agentId).overrideWith((ref) => null),
    // The internals panel resolves the agent through these.
    agentIdentityProvider(agentId).overrideWith((ref) => agent),
    taskAgentSetupOptionsProvider.overrideWith(
      (ref) => const TaskAgentSetupOptions(
        profiles: [],
        models: [],
        providers: [],
      ),
    ),
    if (service != null) eventAgentServiceProvider.overrideWithValue(service),
  ];

  Future<void> pumpCard(
    WidgetTester tester, {
    required List<Override> overrides,
    String? fallbackSummary,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        EventAiSummaryCard(eventId: eventId, fallbackSummary: fallbackSummary),
        overrides: overrides,
      ),
    );
    await tester.pump();
  }

  group('no event agent', () {
    testWidgets('the passive summary sits on the plain section card, not the '
        'AI surface', (tester) async {
      await pumpCard(
        tester,
        overrides: agentOverrides(),
        fallbackSummary: 'A passive summary from a linked note.',
      );

      expect(find.byType(EventPassiveSummaryCard), findsOneWidget);
      expect(find.byType(DesignSystemSectionCard), findsOneWidget);
      expect(find.byType(AgentSummaryCardSurface), findsNothing);
      expect(
        find.text('A passive summary from a linked note.'),
        findsOneWidget,
      );
      // The report header in its plain form: no AI accent for text no agent
      // wrote, and no trigger for an agent that is not there.
      expect(tester.widget<TldrHeader>(find.byType(TldrHeader)).plain, isTrue);
      expect(find.byType(AgentAutomationRow), findsNothing);
    });

    testWidgets('renders nothing when there is no fallback', (tester) async {
      await pumpCard(tester, overrides: agentOverrides(), fallbackSummary: ' ');

      expect(find.byType(EventPassiveSummaryCard), findsNothing);
      expect(find.byType(TldrHeader), findsNothing);
    });
  });

  group('with an event agent', () {
    testWidgets("wears the task agent's card: shared surface, report header, "
        'TLDR body and freshness strip', (tester) async {
      await pumpCard(
        tester,
        overrides: agentOverrides(
          agent: agentIdentity,
          report: () => makeTestReport(
            agentId: agentId,
            tldr: 'A warm rooftop birthday.',
            content: '# The night\nThe long recap, behind Read more.',
          ),
        ),
      );

      expect(find.byType(AgentSummaryCardSurface), findsOneWidget);
      // The shared surface casts no shadow — the slab under the old card is
      // what this card replaced.
      final surface = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(AgentSummaryCardSurface),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((surface.decoration as BoxDecoration).boxShadow, isNull);

      final header = tester.widget<TldrHeader>(find.byType(TldrHeader));
      expect(header.plain, isFalse);
      expect(header.agentName, 'Event Agent');

      final body = tester.widget<TldrBody>(find.byType(TldrBody));
      expect(body.tldr, 'A warm rooftop birthday.');
      expect(body.expanded, isFalse);
      expect(body.additionalReport, contains('The long recap'));
      expect(find.byType(AgentAutomationRow), findsOneWidget);

      // Read more opens the full recap in place.
      await tester.tap(
        find.byKey(const ValueKey('eventAgentReportDisclosure')),
      );
      await tester.pump();
      expect(tester.widget<TldrBody>(find.byType(TldrBody)).expanded, isTrue);
    });

    testWidgets('a report without a TLDR reads its body as the summary', (
      tester,
    ) async {
      await pumpCard(
        tester,
        overrides: agentOverrides(
          agent: agentIdentity,
          report: () =>
              makeTestReport(agentId: agentId, content: 'Just a body recap.'),
        ),
      );

      final body = tester.widget<TldrBody>(find.byType(TldrBody));
      expect(body.tldr, 'Just a body recap.');
      expect(body.additionalReport, isNull);
    });

    testWidgets('before the first recap the body is the awaiting hint', (
      tester,
    ) async {
      await pumpCard(tester, overrides: agentOverrides(agent: agentIdentity));

      expect(find.text(awaitingHint), findsOneWidget);
      expect(find.byType(TldrBody), findsNothing);
      // The agent can still be asked to try.
      expect(find.text('Update now'), findsOneWidget);
    });

    testWidgets('a first load in flight shows neither hint', (tester) async {
      final pending = Completer<AgentDomainEntity?>();
      addTearDown(() => pending.complete(null));

      await pumpCard(
        tester,
        overrides: agentOverrides(
          agent: agentIdentity,
          report: () => pending.future,
        ),
      );

      expect(find.byType(TldrHeader), findsOneWidget);
      expect(find.text(awaitingHint), findsNothing);
      expect(find.text("Couldn't load the recap."), findsNothing);
    });

    testWidgets('a report that fails to load says so, not the hint', (
      tester,
    ) async {
      await pumpCard(
        tester,
        overrides: agentOverrides(
          agent: agentIdentity,
          report: () => throw StateError('db down'),
        ),
      );

      expect(find.text("Couldn't load the recap."), findsOneWidget);
      expect(find.text(awaitingHint), findsNothing);
    });

    testWidgets('Update now re-wakes the event agent', (tester) async {
      final service = MockEventAgentService();
      when(() => service.triggerReanalysis(any<String>())).thenReturn(null);

      await pumpCard(
        tester,
        overrides: agentOverrides(
          agent: agentIdentity,
          report: () => makeTestReport(agentId: agentId, tldr: 'recap'),
          service: service,
        ),
      );

      await tester.tap(find.text('Update now'));
      await tester.pump();

      verify(() => service.triggerReanalysis(agentId)).called(1);
    });

    testWidgets('with its model switched off the agent cannot be woken', (
      tester,
    ) async {
      await pumpCard(
        tester,
        overrides: agentOverrides(
          agent: agentIdentity,
          report: () => makeTestReport(agentId: agentId, tldr: 'recap'),
          inferenceDisabled: true,
        ),
      );

      final strip = tester.widget<AgentAutomationRow>(
        find.byType(AgentAutomationRow),
      );
      expect(strip.inferenceAvailable, isFalse);
      expect(strip.onRunNow, isNull);
    });

    testWidgets("the agent's name opens this agent's internals", (
      tester,
    ) async {
      await pumpCard(
        tester,
        overrides: agentOverrides(
          agent: agentIdentity,
          report: () => makeTestReport(agentId: agentId, tldr: 'recap'),
        ),
      );

      tester.widget<TldrHeader>(find.byType(TldrHeader)).onAgentTap!();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final panel = tester.widget<AgentInternalsPanel>(
        find.byType(AgentInternalsPanel),
      );
      expect(panel.agentId, agentId);
      expect(panel.agentName, 'Event Agent');
      // No maintenance scope: the event agent's schedule is not the task's.
      expect(panel.maintenance, isNull);
    });
  });
}
