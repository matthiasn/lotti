import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/nudges/model/nudge_banner_entry.dart';
import 'package:lotti/features/nudges/model/nudge_entity_view.dart';
import 'package:lotti/features/nudges/state/nudge_banner_providers.dart';
import 'package:lotti/features/relationships/state/relationship_nudge_providers.dart';
import 'package:lotti/features/relationships/ui/widgets/paused_reminder_callout.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  final at = DateTime(2026, 8, 16, 12);

  PausedRelationshipReminder paused() => (
    entry: (
      nudge: NudgeEntityView.of(
        AgentDomainEntity.relationshipNudge(
          id: 'ad-1',
          agentId: 'agent-1',
          status: NudgeStatus.active,
          brief: const NudgeBrief(
            headline: 'Check in with Pip.',
            tone: NudgeTone.nudge,
            animation: NudgeBannerAnimation.steady,
          ),
          briefDigest: 'd',
          createdAt: at,
          updatedAt: at,
          vectorClock: null,
        ),
      )!,
      subjectTitle: 'Pip',
      kind: NudgeBannerKind.relationship,
      tapRoute: '/people/rel-001',
    ),
    until: DateTime(2026, 8, 16, 15, 40),
  );

  Future<void> pump(
    WidgetTester tester,
    PausedRelationshipReminder? value,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const PausedReminderCallout(relationshipId: 'rel-001', bottomGap: 24),
        overrides: [
          pausedRelationshipReminderProvider(
            'rel-001',
          ).overrideWith((ref) async => value),
          nudgeInteractionsProvider.overrideWithValue(
            MockNudgeInteractions(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('says nothing while no reminder is paused', (tester) async {
    await pump(tester, null);

    expect(find.byKey(const ValueKey('person-reminder-paused')), findsNothing);
  });

  testWidgets('says the tapped reminder is paused and until when', (
    tester,
  ) async {
    await pump(tester, paused());

    expect(
      find.byKey(const ValueKey('person-reminder-paused')),
      findsOneWidget,
    );
    expect(find.textContaining('Reminder paused until'), findsOneWidget);
    // The feature's one timestamp form, not the device's 12/24-hour clock
    // in proportional type: the callout sat one card above a mono 24-hour
    // timestamp, so the page read two clocks.
    expect(find.textContaining('15:40'), findsOneWidget);
    expect(
      find.text('It comes back then, unless you log a check-in first.'),
      findsOneWidget,
    );
  });

  testWidgets('Snooze longer opens the snooze choices', (tester) async {
    await pump(tester, paused());

    await tester.tap(
      find.byKey(const ValueKey('person-reminder-snooze-longer')),
    );
    await tester.pumpAndSettle();

    expect(find.text('When should it come back?'), findsOneWidget);
  });
}
