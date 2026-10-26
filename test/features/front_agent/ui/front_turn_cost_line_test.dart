import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/consumption_summary_pill.dart';
import 'package:lotti/features/front_agent/ui/front_turn_cost_line.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';
import '../../ai_consumption/test_utils.dart';

void main() {
  late List<({String agentId, String runKey})> asked;

  setUp(() => asked = []);

  Future<void> pump(
    WidgetTester tester, {
    required Stream<ConsumptionTotals> Function() totals,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        const FrontTurnCostLine(runKey: 'run-7'),
        overrides: [
          agentRunConsumptionTotalsProvider.overrideWith((ref, run) {
            asked.add(run);
            return totals();
          }),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets("reads the front agent's totals for that wake and shows the "
      'shared cost label', (tester) async {
    final totals = makeConsumptionTotals(
      callCount: 2,
      totalTokens: 900,
      credits: 0.01,
      energyKwh: 0.002,
      carbonGCo2: 0.5,
    );
    await pump(tester, totals: () => Stream.value(totals));

    expect(asked, [(agentId: 'front_agent', runKey: 'run-7')]);
    final line = find.byKey(const ValueKey('front-turn-cost-run-7'));
    expect(line, findsOneWidget);
    final context = tester.element(line);
    expect(
      tester.widget<Text>(line).data,
      ' · ${consumptionSummaryLabel(context, totals)}',
    );
    expect(
      tester.widget<Tooltip>(find.byType(Tooltip)).message,
      consumptionSummaryTooltip(context, totals),
    );
  });

  testWidgets('shows nothing while the totals are unknown, and nothing for '
      'a wake that recorded no call', (tester) async {
    await pump(
      tester,
      totals: () => Completer<ConsumptionTotals>().future.asStream(),
    );
    expect(find.byType(Text), findsNothing);

    await pump(tester, totals: () => Stream.value(ConsumptionTotals.empty));
    expect(find.byType(Text), findsNothing);
    expect(find.byType(Tooltip), findsNothing);
  });
}
