import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai_consumption/logic/attribution_cost.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/ai_attribution_summary.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  testWidgets('shows creator, trigger, status, model, calls, and cost', (
    tester,
  ) async {
    final envelope = makeAiTerminalEnvelope();
    final details = AiAttributionDetails(
      attribution: envelope.attribution,
      interactions: [
        AiConsumptionEvent(
          id: 'call-1',
          createdAt: DateTime(2026, 3, 15, 12),
          providerType: InferenceProviderType.openAi,
          responseType: AiConsumptionResponseType.promptGeneration,
          vectorClock: null,
          attributionId: envelope.attribution.id,
          providerModelId: 'gpt-5',
          totalTokens: 120,
        ),
      ],
      costTotals: const AiCostTotals(
        reportingMicrosByCurrency: {'USD': 25000},
        knownInteractionCount: 1,
        unknownInteractionCount: 0,
      ),
    );

    await tester.pumpWidget(
      makeTestableWidget(
        AiAttributionSummary(
          artifact: makeAiArtifact(),
          envelope: envelope,
        ),
        overrides: [
          aiAttributionDetailsProvider.overrideWith(
            (ref, id) async => details,
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.textContaining('Ada · Manual · Completed'), findsOneWidget);
    expect(find.textContaining('gpt-5'), findsOneWidget);
    expect(find.textContaining('1 call'), findsOneWidget);
    expect(find.textContaining(r'$0.03'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AiAttributionSummary),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();
    await tester.pump(MotionDurations.long2);
    expect(find.text('AI attribution'), findsOneWidget);
    expect(find.text('Interactions'), findsOneWidget);
    expect(find.textContaining('Call 1: gpt-5 · 120 tokens'), findsOneWidget);
  });

  testWidgets('does not render when no attribution can be resolved', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidget(
        AiAttributionSummary(artifact: makeAiArtifact()),
        overrides: [
          aiAttributionForArtifactProvider.overrideWith(
            (ref, artifact) async => null,
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(AiAttributionSummary), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AiAttributionSummary),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
    expect(find.text('AI attribution'), findsNothing);
  });
}
