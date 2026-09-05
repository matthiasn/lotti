import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart';
import 'package:lotti/features/daily_os_next/state/planner_knowledge_provider.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/knowledge_nudge.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/knowledge_panel.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  PlannerKnowledgeEntity proposal(String id) {
    return AgentDomainEntity.plannerKnowledge(
          id: id,
          agentId: 'daily_os_planner',
          key: 'key-$id',
          hook: 'hook',
          statementText: 'You plan better before 10am',
          source: KnowledgeSource.agentInferred,
          status: KnowledgeStatus.proposed,
          createdAt: DateTime(2026, 5, 20),
          updatedAt: DateTime(2026, 5, 20),
          vectorClock: null,
        )
        as PlannerKnowledgeEntity;
  }

  Widget nudge(PlannerKnowledgeView view) => makeTestableWidget(
    const KnowledgeNudge(),
    overrides: [
      plannerKnowledgeProvider.overrideWith((ref) async => view),
      // The panel the nudge opens resolves this; the nudge itself never does.
      dayAgentKnowledgeServiceProvider.overrideWithValue(
        MockDayAgentKnowledgeService(),
      ),
    ],
  );

  testWidgets('renders nothing while no proposal awaits confirmation', (
    tester,
  ) async {
    // The Day page stays calm by default — this is the widget's whole reason
    // for existing, so it is the first thing worth pinning.
    await tester.pumpWidget(
      nudge(
        PlannerKnowledgeView(confirmed: [proposal('c1')], proposed: const []),
      ),
    );
    await tester.pump();

    expect(find.byKey(KnowledgeNudge.nudgeKey), findsNothing);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('renders nothing while the provider is still loading', (
    tester,
  ) async {
    // `?? 0` on an unresolved AsyncValue: the nudge must not flash in and out
    // as the day loads.
    await tester.pumpWidget(
      nudge(
        const PlannerKnowledgeView(
          confirmed: [],
          proposed: [],
        ),
      ),
    );
    // deliberately not settled

    expect(find.byKey(KnowledgeNudge.nudgeKey), findsNothing);
  });

  testWidgets('surfaces proposals with the AI mark and an opening chevron', (
    tester,
  ) async {
    await tester.pumpWidget(
      nudge(
        PlannerKnowledgeView(
          confirmed: const [],
          proposed: [proposal('p1'), proposal('p2')],
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(KnowledgeNudge.nudgeKey), findsOneWidget);
    // The sparkle marks this as agent-authored, and the chevron says the row
    // opens something — together they are what make a quiet line read as
    // tappable without a button.
    expect(find.byIcon(LottiIcons.aiSpark), findsOneWidget);
    expect(find.byIcon(LottiIcons.chevronRight), findsOneWidget);
  });

  testWidgets('names how many proposals are waiting', (tester) async {
    // The count is the entire payload of the line; a nudge that said only
    // "review" would not be worth the row it costs.
    await tester.pumpWidget(
      nudge(
        PlannerKnowledgeView(
          confirmed: const [],
          proposed: [proposal('p1'), proposal('p2'), proposal('p3')],
        ),
      ),
    );
    await tester.pump();

    final text = tester.widget<Text>(
      find.descendant(
        of: find.byKey(KnowledgeNudge.nudgeKey),
        matching: find.byType(Text),
      ),
    );
    expect(text.data, contains('3'));
    expect(text.maxLines, 1, reason: 'the nudge is one quiet line, never two');
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('the whole line is one tap target, not just the glyph', (
    tester,
  ) async {
    await tester.pumpWidget(
      nudge(
        PlannerKnowledgeView(confirmed: const [], proposed: [proposal('p1')]),
      ),
    );
    await tester.pump();

    // A 14pt sparkle is not a tap target. The InkWell has to span the chip, so
    // this measures the actual hit area rather than asserting one exists.
    final size = tester.getSize(find.byKey(KnowledgeNudge.nudgeKey));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('tapping it opens the knowledge panel', (tester) async {
    await tester.pumpWidget(
      nudge(
        PlannerKnowledgeView(confirmed: const [], proposed: [proposal('p1')]),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(KnowledgeNudge.nudgeKey));
    await tester.pumpAndSettle();

    // The nudge's only job is to be the way in.
    expect(find.byType(KnowledgePanel), findsOneWidget);
  });
}
