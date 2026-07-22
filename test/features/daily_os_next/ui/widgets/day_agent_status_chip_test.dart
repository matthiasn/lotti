import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_persona_provider.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_agent_status_chip.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';

import '../../../../widget_test_utils.dart';

void main() {
  final date = DateTime(2026, 7, 23);

  Future<void> pumpChip(
    WidgetTester tester, {
    required DayAgentPersonaState persona,
    int? tokenSpend,
    VoidCallback? onInspectAgent,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        DayAgentStatusChip(
          date: date,
          onInspectAgent: onInspectAgent ?? () {},
        ),
        overrides: [
          dayAgentPersonaStateProvider.overrideWith(
            (ref, d) async => persona,
          ),
          dayAgentTokenSpendProvider.overrideWith(
            (ref, d) async => tokenSpend,
          ),
        ],
      ),
    );
    // Two pumps: one for each async provider (persona, then token spend).
    await tester.pump();
    await tester.pump();
  }

  testWidgets('renders nothing while the agent is idle', (tester) async {
    await pumpChip(tester, persona: DayAgentPersonaState.idle);

    expect(find.byType(DsPill), findsNothing);
  });

  testWidgets('working state shows the planning label and routes taps to '
      'the agent internals', (tester) async {
    var inspected = 0;
    await pumpChip(
      tester,
      persona: DayAgentPersonaState.working,
      onInspectAgent: () => inspected++,
    );

    expect(find.text('Planning…'), findsOneWidget);
    await tester.tap(find.byType(DsPill));
    expect(inspected, 1);
  });

  testWidgets('attention state shows the needs-attention label', (
    tester,
  ) async {
    await pumpChip(tester, persona: DayAgentPersonaState.attention);

    expect(find.text('Needs attention'), findsOneWidget);
  });

  testWidgets('day-closed state includes the per-day token spend in the '
      'tooltip', (tester) async {
    await pumpChip(
      tester,
      persona: DayAgentPersonaState.celebrating,
      tokenSpend: 1850,
    );

    expect(find.text('Day closed'), findsOneWidget);
    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(
      tooltip.message,
      'Day closed — 1850 tokens spent planning this day',
    );
  });

  testWidgets('tooltip is the bare label when no per-day spend exists '
      '(coordinator-owned day)', (tester) async {
    await pumpChip(tester, persona: DayAgentPersonaState.attention);

    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.message, 'Needs attention');
  });
}
