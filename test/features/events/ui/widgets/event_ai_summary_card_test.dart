import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/state/event_agent_providers.dart';
import 'package:lotti/features/events/ui/widgets/event_ai_summary_card.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/test_utils.dart';

void main() {
  const eventId = 'event-1';
  const agentId = 'agent-1';

  final agentIdentity = makeTestIdentity(
    id: agentId,
    agentId: agentId,
    kind: 'event_agent',
  );

  Widget buildCard({
    String? fallbackSummary,
    AgentDomainEntity? agent,
    AgentDomainEntity? report,
    MockEventAgentService? service,
  }) {
    return makeTestableWidgetWithScaffold(
      EventAiSummaryCard(eventId: eventId, fallbackSummary: fallbackSummary),
      overrides: <Override>[
        eventAgentProvider(eventId).overrideWith((ref) async => agent),
        agentReportProvider(agentId).overrideWith((ref) async => report),
        if (service != null)
          eventAgentServiceProvider.overrideWithValue(service),
      ],
    );
  }

  group('no event agent', () {
    testWidgets('renders the fallback summary without a refresh control', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildCard(fallbackSummary: 'A passive summary from a linked note.'),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('A passive summary from a linked note.'),
        findsOneWidget,
      );
      // No agent → no re-wake affordance.
      expect(find.byIcon(Icons.refresh), findsNothing);
    });

    testWidgets('renders nothing when there is no fallback', (tester) async {
      await tester.pumpWidget(buildCard());
      await tester.pumpAndSettle();

      expect(find.text('Summary'), findsNothing);
      expect(find.byIcon(Icons.auto_awesome), findsNothing);
    });
  });

  group('with an event agent', () {
    testWidgets('shows the report tldr and a refresh control', (tester) async {
      await tester.pumpWidget(
        buildCard(
          agent: agentIdentity,
          report: makeTestReport(
            tldr: 'A warm rooftop birthday. 🎂',
            content: '# The night\nlong markdown body',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The punchy tldr is shown, not the raw markdown body.
      expect(find.text('A warm rooftop birthday. 🎂'), findsOneWidget);
      expect(find.textContaining('# The night'), findsNothing);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('falls back to the report body when there is no tldr', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildCard(
          agent: agentIdentity,
          report: makeTestReport(content: 'Just a body recap.'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Just a body recap.'), findsOneWidget);
    });

    testWidgets('shows the awaiting-content hint when no report exists yet', (
      tester,
    ) async {
      await tester.pumpWidget(buildCard(agent: agentIdentity));
      await tester.pumpAndSettle();

      expect(
        find.text('Add a photo or note and the recap will appear here.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('refresh re-wakes the agent via triggerReanalysis', (
      tester,
    ) async {
      final service = MockEventAgentService();
      when(() => service.triggerReanalysis(any<String>())).thenReturn(null);

      await tester.pumpWidget(
        buildCard(
          agent: agentIdentity,
          report: makeTestReport(tldr: 'recap'),
          service: service,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      verify(() => service.triggerReanalysis(agentId)).called(1);
    });
  });
}
