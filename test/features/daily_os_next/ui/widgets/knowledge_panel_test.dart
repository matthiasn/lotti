import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart';
import 'package:lotti/features/daily_os_next/state/planner_knowledge_provider.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/knowledge_panel.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  PlannerKnowledgeEntity entry({
    required String id,
    required String key,
    required String statement,
    KnowledgeStatus status = KnowledgeStatus.confirmed,
    DateTime? reviewAfter,
  }) {
    return AgentDomainEntity.plannerKnowledge(
          id: id,
          agentId: 'daily_os_planner',
          key: key,
          hook: 'hook',
          statementText: statement,
          source: KnowledgeSource.userStated,
          status: status,
          createdAt: DateTime(2026, 5, 20),
          updatedAt: DateTime(2026, 5, 20),
          vectorClock: null,
          reviewAfter: reviewAfter,
        )
        as PlannerKnowledgeEntity;
  }

  Widget panel(
    PlannerKnowledgeView view,
    MockDayAgentKnowledgeService service,
  ) {
    return makeTestableWidget(
      const SingleChildScrollView(child: KnowledgePanel()),
      overrides: [
        plannerKnowledgeProvider.overrideWith((ref) async => view),
        dayAgentKnowledgeServiceProvider.overrideWithValue(service),
      ],
    );
  }

  testWidgets('renders the empty state when there is no knowledge', (
    tester,
  ) async {
    await tester.pumpWidget(
      panel(const PlannerKnowledgeView.empty(), MockDayAgentKnowledgeService()),
    );
    await tester.pump();

    expect(find.text("What I've learned"), findsOneWidget);
    expect(
      find.text("Nothing yet — I'll remember what you tell me."),
      findsOneWidget,
    );
  });

  testWidgets('lists confirmed and proposed entries under their headers', (
    tester,
  ) async {
    final view = PlannerKnowledgeView(
      confirmed: [
        entry(id: 'c', key: 'deep-work', statement: 'No deep work before 10.'),
      ],
      proposed: [
        entry(
          id: 'p',
          key: 'gym',
          statement: 'You seem to work out on Tuesdays.',
          status: KnowledgeStatus.proposed,
        ),
      ],
    );

    await tester.pumpWidget(panel(view, MockDayAgentKnowledgeService()));
    await tester.pump();

    expect(find.text('No deep work before 10.'), findsOneWidget);
    expect(find.text('You seem to work out on Tuesdays.'), findsOneWidget);
    expect(find.text('Confirmed'.toUpperCase()), findsOneWidget);
    expect(
      find.text('Awaiting your confirmation'.toUpperCase()),
      findsOneWidget,
    );
  });

  testWidgets('confirming a proposal calls the service', (tester) async {
    final service = MockDayAgentKnowledgeService();
    when(() => service.confirm('p')).thenAnswer((_) async => null);
    final view = PlannerKnowledgeView(
      confirmed: const [],
      proposed: [
        entry(
          id: 'p',
          key: 'gym',
          statement: 'Tuesdays workout.',
          status: KnowledgeStatus.proposed,
        ),
      ],
    );

    await tester.pumpWidget(panel(view, service));
    await tester.pump();

    await tester.tap(find.text('Confirm'));
    await tester.pump();

    verify(() => service.confirm('p')).called(1);
  });

  testWidgets('forgetting a confirmed entry calls retract', (tester) async {
    final service = MockDayAgentKnowledgeService();
    when(() => service.retract('c')).thenAnswer((_) async => null);
    final view = PlannerKnowledgeView(
      confirmed: [entry(id: 'c', key: 'k', statement: 'A preference.')],
      proposed: const [],
    );

    await tester.pumpWidget(panel(view, service));
    await tester.pump();

    await tester.tap(find.text('Forget'));
    await tester.pump();

    verify(() => service.retract('c')).called(1);
  });

  testWidgets('flags a stale entry for re-confirmation', (tester) async {
    final view = PlannerKnowledgeView(
      confirmed: [
        entry(
          id: 'c',
          key: 'k',
          statement: 'An old preference.',
          reviewAfter: DateTime(2020),
        ),
      ],
      proposed: const [],
    );

    await tester.pumpWidget(panel(view, MockDayAgentKnowledgeService()));
    await tester.pump();

    expect(find.text('Still true?'), findsOneWidget);
  });
}
