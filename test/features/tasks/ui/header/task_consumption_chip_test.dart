import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/ai_consumption/logic/consumption_formatting.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/tasks/ui/header/task_consumption_chip.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../ai_consumption/test_utils.dart';

void main() {
  const taskId = 'task-1';

  late MockConsumptionRepository repository;

  setUp(() {
    repository = MockConsumptionRepository();
  });

  Future<void> pumpChip(WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidget(
        // Deliberately non-const so the constructor executes at runtime and
        // shows up in coverage.
        // ignore: prefer_const_constructors
        TaskConsumptionChip(taskId: taskId),
        overrides: [
          consumptionRepositoryProvider.overrideWithValue(repository),
          consumptionRefetchThrottleProvider.overrideWithValue(null),
          maybeUpdateNotificationsProvider.overrideWith((ref) => null),
        ],
      ),
    );
    // Let the totals stream deliver its first (and only) fetch.
    await tester.pump();
  }

  void stubTotals(ConsumptionTotals totals) {
    when(
      () => repository.totalsForTask(taskId),
    ).thenAnswer((_) async => totals);
  }

  /// A task with measured Melious impact: 3 calls, 2 of them with impact.
  ConsumptionTotals impactTotals() => makeConsumptionTotals(
    callCount: 3,
    impactCallCount: 2,
    inputTokens: 1200,
    outputTokens: 800,
    totalTokens: 2000,
    credits: 0.42,
    energyKwh: 0.012,
    carbonGCo2: 3.4,
    waterLiters: 0.012,
  );

  testWidgets('renders nothing while loading and for tasks without AI '
      'calls', (tester) async {
    final completer = Completer<ConsumptionTotals>();
    when(
      () => repository.totalsForTask(taskId),
    ).thenAnswer((_) => completer.future);
    await pumpChip(tester);

    // Still loading: no pill, no tooltip — non-AI tasks carry zero chrome.
    expect(find.byType(DsPill), findsNothing);
    expect(find.byType(Tooltip), findsNothing);

    completer.complete(makeConsumptionTotals());
    await tester.pump();

    // Zero recorded calls looks identical to loading, by design.
    expect(find.byType(DsPill), findsNothing);
    expect(find.byType(Tooltip), findsNothing);
  });

  testWidgets('shows the cost/energy/carbon triple when impact was '
      'measured', (tester) async {
    stubTotals(impactTotals());
    await pumpChip(tester);

    final label =
        '${formatCredits(0.42)} · '
        '${formatEnergyKwh(0.012)} · '
        '${formatCarbonGrams(3.4)}';
    // Guard the fixture against silent formatter drift.
    expect(label, '€0.42 · 12 Wh · 3.4 g');
    expect(find.byType(DsPill), findsOneWidget);
    expect(find.text(label), findsOneWidget);
    expect(find.byIcon(Icons.eco_outlined), findsOneWidget);
  });

  testWidgets('falls back to the token count when no call has measured '
      'impact', (tester) async {
    stubTotals(
      makeConsumptionTotals(
        callCount: 2,
        inputTokens: 9000,
        outputTokens: 3300,
        totalTokens: 12300,
      ),
    );
    await pumpChip(tester);

    expect(find.text('${formatTokenCount(12300)} tokens'), findsOneWidget);
    expect(find.text('12.3K tokens'), findsOneWidget);

    // The tooltip carries only the calls and token lines — no impact/cost.
    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(
      tooltip.message,
      'AI calls: 2 · impact measured for 0\n'
      'Tokens: ${formatTokenCount(9000)} in · ${formatTokenCount(3300)} out',
    );
  });

  testWidgets('tooltip carries the full breakdown when impact was '
      'measured', (tester) async {
    stubTotals(impactTotals());
    await pumpChip(tester);

    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(
      tooltip.message,
      'AI calls: 3 · impact measured for 2\n'
      'Tokens: ${formatTokenCount(1200)} in · ${formatTokenCount(800)} out\n'
      'Impact: ${formatEnergyKwh(0.012)} · ${formatCarbonGrams(3.4)} CO₂e · '
      '${formatWaterLiters(0.012)} water\n'
      'Cost: ${formatCredits(0.42)}',
    );
  });
}
