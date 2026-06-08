import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart';
import 'package:lotti/features/daily_os_next/state/planner_knowledge_provider.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/knowledge_panel.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
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
    List<String> tags = const [],
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
          tags: tags,
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

  testWidgets('renders tags as chips, and none when an entry has no tags', (
    tester,
  ) async {
    final view = PlannerKnowledgeView(
      confirmed: [
        entry(
          id: 'c',
          key: 'deep-work',
          statement: 'No deep work before 10.',
          tags: const ['mornings', 'deep-work'],
        ),
        entry(id: 'u', key: 'untagged', statement: 'No chips here.'),
      ],
      proposed: const [],
    );

    await tester.pumpWidget(panel(view, MockDayAgentKnowledgeService()));
    await tester.pump();

    // Two chips for the tagged entry; the untagged entry adds none.
    expect(find.byType(DsPill), findsNWidgets(2));
    expect(find.text('mornings'), findsOneWidget);
    expect(find.text('deep-work'), findsOneWidget);
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

  testWidgets('flags only past-review entries for re-confirmation', (
    tester,
  ) async {
    final view = PlannerKnowledgeView(
      confirmed: [
        entry(
          id: 'stale',
          key: 'k1',
          statement: 'An old preference.',
          reviewAfter: DateTime(2020),
        ),
        // A future review date must NOT surface the badge — otherwise a
        // regression that always rendered it would slip through.
        entry(
          id: 'fresh',
          key: 'k2',
          statement: 'A current preference.',
          reviewAfter: DateTime(2099),
        ),
      ],
      proposed: const [],
    );

    await tester.pumpWidget(panel(view, MockDayAgentKnowledgeService()));
    await tester.pump();

    // Exactly one badge — for the stale entry only.
    expect(find.text('Still true?'), findsOneWidget);
    expect(find.text('An old preference.'), findsOneWidget);
    expect(find.text('A current preference.'), findsOneWidget);
  });

  testWidgets('editing a confirmed entry saves the new hook and statement', (
    tester,
  ) async {
    final service = MockDayAgentKnowledgeService();
    when(
      () => service.editStatement(
        'c',
        hook: any(named: 'hook'),
        statement: any(named: 'statement'),
      ),
    ).thenAnswer((_) async => null);
    final view = PlannerKnowledgeView(
      confirmed: [entry(id: 'c', key: 'k', statement: 'old statement')],
      proposed: const [],
    );

    await tester.pumpWidget(panel(view, service));
    await tester.pump();

    // Open the edit dialog from the row action.
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // Two fields: hook then statement. Rewrite both.
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), 'new hook');
    await tester.enterText(fields.at(1), 'new statement');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    verify(
      () => service.editStatement(
        'c',
        hook: 'new hook',
        statement: 'new statement',
      ),
    ).called(1);
  });

  testWidgets('cancelling the edit dialog does not call the service', (
    tester,
  ) async {
    final service = MockDayAgentKnowledgeService();
    final view = PlannerKnowledgeView(
      confirmed: [entry(id: 'c', key: 'k', statement: 'keep me')],
      proposed: const [],
    );

    await tester.pumpWidget(panel(view, service));
    await tester.pump();

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(
      () => service.editStatement(
        any(),
        hook: any(named: 'hook'),
        statement: any(named: 'statement'),
      ),
    );
  });

  testWidgets('renders nothing while the view is still loading (no flash)', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidget(
        const KnowledgePanel(),
        overrides: [
          // A provider that never resolves: .value stays null → SizedBox.shrink
          // rather than a flash of an empty panel.
          plannerKnowledgeProvider.overrideWith(
            (ref) => Completer<PlannerKnowledgeView>().future,
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(KnowledgePanel), findsOneWidget);
    expect(find.text("What I've learned"), findsNothing);
  });
}
