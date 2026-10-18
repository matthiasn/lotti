import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/day_agent_identity.dart';
import 'package:lotti/features/agents/knowledge/agent_knowledge_providers.dart';
import 'package:lotti/features/agents/ui/knowledge/agent_knowledge_panel.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:material_ui/material_ui.dart';
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
    AgentKnowledgeView view,
    MockAgentKnowledgeService service,
  ) {
    return makeTestableWidget(
      const SingleChildScrollView(
        child: AgentKnowledgePanel(agentId: dailyOsPlannerAgentId),
      ),
      overrides: [
        agentKnowledgeProvider(
          dailyOsPlannerAgentId,
        ).overrideWith((ref) async => view),
        agentKnowledgeServiceProvider.overrideWithValue(service),
      ],
    );
  }

  Future<void> openMenu(WidgetTester tester, String id) async {
    await tester.tap(find.byKey(ValueKey('agent-knowledge-menu-$id')));
    await tester.pumpAndSettle();
  }

  testWidgets('renders the empty state when there is no knowledge', (
    tester,
  ) async {
    await tester.pumpWidget(
      panel(
        const AgentKnowledgeView(confirmed: [], proposed: []),
        MockAgentKnowledgeService(),
      ),
    );
    await tester.pump();

    expect(find.text("What I've learned"), findsOneWidget);
    expect(
      find.text("Nothing yet — I'll remember what you tell me."),
      findsOneWidget,
    );
  });

  testWidgets('asks about proposals and lists confirmed facts plainly', (
    tester,
  ) async {
    final view = AgentKnowledgeView(
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

    await tester.pumpWidget(panel(view, MockAgentKnowledgeService()));
    await tester.pump();

    expect(find.text('No deep work before 10.'), findsOneWidget);
    expect(find.text('You seem to work out on Tuesdays.'), findsOneWidget);
    // Only proposals carry a label — the agent's question; what is settled
    // needs none.
    expect(find.text('Did I get this right?'), findsOneWidget);
    expect(find.text('Confirmed'), findsNothing);
    // The proposal asks inside its own callout; the settled fact keeps its
    // Edit and Forget behind a menu, so only the proposal shows buttons.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('agent-knowledge-proposal-p')),
        matching: find.text('You seem to work out on Tuesdays.'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('agent-knowledge-menu-c')), findsOne);
    expect(find.byKey(const ValueKey('agent-knowledge-menu-p')), findsNothing);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Forget'), findsOneWidget);
  });

  testWidgets('renders tags as chips, and none when an entry has no tags', (
    tester,
  ) async {
    final view = AgentKnowledgeView(
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

    await tester.pumpWidget(panel(view, MockAgentKnowledgeService()));
    await tester.pump();

    // Two chips for the tagged entry; the untagged entry adds none.
    expect(find.byType(DsPill), findsNWidgets(2));
    expect(
      tester.widgetList<DsPill>(find.byType(DsPill)).map((pill) => pill.shape),
      everyElement(DsPillShape.tag),
    );
    expect(find.text('mornings'), findsOneWidget);
    expect(find.text('deep-work'), findsOneWidget);
  });

  testWidgets('confirming a proposal calls the service', (tester) async {
    final service = MockAgentKnowledgeService();
    when(() => service.confirm('p')).thenAnswer((_) async => null);
    final view = AgentKnowledgeView(
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
    final service = MockAgentKnowledgeService();
    when(() => service.retract('c')).thenAnswer((_) async => null);
    final view = AgentKnowledgeView(
      confirmed: [entry(id: 'c', key: 'k', statement: 'A preference.')],
      proposed: const [],
    );

    await tester.pumpWidget(panel(view, service));
    await tester.pump();

    await openMenu(tester, 'c');
    await tester.tap(find.text('Forget'));
    await tester.pumpAndSettle();

    verify(() => service.retract('c')).called(1);
  });

  testWidgets('a one-line fact gives its menu the full tap target', (
    tester,
  ) async {
    final view = AgentKnowledgeView(
      confirmed: [entry(id: 'c', key: 'k', statement: 'Short.')],
      proposed: const [],
    );

    await tester.pumpWidget(panel(view, MockAgentKnowledgeService()));
    await tester.pump();

    // Tap near the bottom edge of the 48-high target, below the one text
    // line: a slot only a line high would drop this tap.
    final menu = find.byKey(const ValueKey('agent-knowledge-menu-c'));
    expect(tester.getSize(menu).height, greaterThanOrEqualTo(48));
    await tester.tapAt(tester.getCenter(menu) + const Offset(0, 18));
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Forget'), findsOneWidget);
  });

  testWidgets('forgetting a proposal retracts it without confirming it', (
    tester,
  ) async {
    final service = MockAgentKnowledgeService();
    when(() => service.retract('p')).thenAnswer((_) async => null);
    final view = AgentKnowledgeView(
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

    await tester.tap(find.text('Forget'));
    await tester.pump();

    verify(() => service.retract('p')).called(1);
    verifyNever(() => service.confirm(any()));
  });

  testWidgets('flags only past-review entries for re-confirmation', (
    tester,
  ) async {
    final view = AgentKnowledgeView(
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

    await tester.pumpWidget(panel(view, MockAgentKnowledgeService()));
    await tester.pump();

    // Exactly one badge — for the stale entry only, with its answer.
    expect(find.text('Still true?'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('agent-knowledge-reconfirm-stale')),
      findsOne,
    );
    expect(
      find.byKey(const ValueKey('agent-knowledge-reconfirm-fresh')),
      findsNothing,
    );
    expect(find.text('An old preference.'), findsOneWidget);
    expect(find.text('A current preference.'), findsOneWidget);
  });

  testWidgets('answering "Still true?" re-confirms the fact', (tester) async {
    final service = MockAgentKnowledgeService();
    when(() => service.confirm('stale')).thenAnswer((_) async => null);
    final view = AgentKnowledgeView(
      confirmed: [
        entry(
          id: 'stale',
          key: 'k1',
          statement: 'An old preference.',
          reviewAfter: DateTime(2020),
        ),
      ],
      proposed: const [],
    );

    await tester.pumpWidget(panel(view, service));
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('agent-knowledge-reconfirm-stale')),
    );
    await tester.pump();

    verify(() => service.confirm('stale')).called(1);
  });

  testWidgets('editing a confirmed entry saves the new hook and statement', (
    tester,
  ) async {
    final service = MockAgentKnowledgeService();
    when(
      () => service.editStatement(
        'c',
        hook: any(named: 'hook'),
        statement: any(named: 'statement'),
      ),
    ).thenAnswer((_) async => null);
    final view = AgentKnowledgeView(
      confirmed: [entry(id: 'c', key: 'k', statement: 'old statement')],
      proposed: const [],
    );

    await tester.pumpWidget(panel(view, service));
    await tester.pump();

    // Open the edit dialog from the row action.
    await openMenu(tester, 'c');
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

  testWidgets('save stays disabled while either field is empty', (
    tester,
  ) async {
    final service = MockAgentKnowledgeService();
    final view = AgentKnowledgeView(
      confirmed: [entry(id: 'c', key: 'k', statement: 'keep me')],
      proposed: const [],
    );

    await tester.pumpWidget(panel(view, service));
    await tester.pump();
    await openMenu(tester, 'c');
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    DesignSystemButton save() => tester.widget<DesignSystemButton>(
      find.byKey(const ValueKey('agent-knowledge-edit-save')),
    );
    expect(save().onPressed, isNotNull);

    await tester.enterText(find.byType(TextField).at(1), '   ');
    await tester.pump();
    expect(save().onPressed, isNull);

    await tester.enterText(find.byType(TextField).at(1), 'back again');
    await tester.enterText(find.byType(TextField).at(0), '');
    await tester.pump();
    expect(save().onPressed, isNull);

    verifyNever(
      () => service.editStatement(
        any(),
        hook: any(named: 'hook'),
        statement: any(named: 'statement'),
      ),
    );
  });

  testWidgets('cancelling the edit dialog does not call the service', (
    tester,
  ) async {
    final service = MockAgentKnowledgeService();
    final view = AgentKnowledgeView(
      confirmed: [entry(id: 'c', key: 'k', statement: 'keep me')],
      proposed: const [],
    );

    await tester.pumpWidget(panel(view, service));
    await tester.pump();

    await openMenu(tester, 'c');
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
        const AgentKnowledgePanel(agentId: dailyOsPlannerAgentId),
        overrides: [
          // A provider that never resolves: .value stays null → SizedBox.shrink
          // rather than a flash of an empty panel.
          agentKnowledgeProvider(dailyOsPlannerAgentId).overrideWith(
            (ref) => Completer<AgentKnowledgeView>().future,
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(AgentKnowledgePanel), findsOneWidget);
    expect(find.text("What I've learned"), findsNothing);
  });
}
