import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai_consumption/logic/attribution_cost.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/ai_attribution_summary.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  Future<void> pumpSummary(
    WidgetTester tester, {
    required AiTerminalAttributionEnvelope? envelope,
    required AiAttributionDetails? details,
    double width = 800,
    bool compact = false,
    bool includeTopSpacing = true,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: AiAttributionSummary(
              artifact: makeAiArtifact(),
              envelope: envelope,
              compact: compact,
              includeTopSpacing: includeTopSpacing,
            ),
          ),
        ),
        overrides: [
          if (envelope == null)
            aiAttributionForArtifactProvider.overrideWith(
              (ref, artifact) async => details,
            )
          else
            aiAttributionDetailsProvider.overrideWith(
              (ref, id) async => details,
            ),
        ],
      ),
    );
    await tester.pump();
  }

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

    await pumpSummary(tester, envelope: envelope, details: details);

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
    await pumpSummary(tester, envelope: null, details: null);

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

  testWidgets('does not flash unknown details while loading', (tester) async {
    final envelope = makeAiTerminalEnvelope();
    final completer = Completer<AiAttributionDetails?>();
    await tester.pumpWidget(
      makeTestableWidget(
        AiAttributionSummary(
          artifact: makeAiArtifact(),
          envelope: envelope,
        ),
        overrides: [
          aiAttributionDetailsProvider.overrideWith(
            (ref, id) => completer.future,
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('…'), findsNWidgets(2));
    expect(find.textContaining('Unknown model'), findsNothing);
    expect(find.text('Cost unknown'), findsNothing);

    completer.complete(
      AiAttributionDetails(
        attribution: envelope.attribution,
        interactions: const [],
        costTotals: AiCostTotals.empty,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('…'), findsNothing);
    expect(find.textContaining('Unknown model'), findsOneWidget);
    expect(find.text('No charge'), findsOneWidget);
  });

  testWidgets('narrow compact summary exposes zero cost and private details', (
    tester,
  ) async {
    final base = makeAiTerminalEnvelope();
    final attribution = base.attribution.copyWith(
      status: AiWorkStatus.failed,
      initiator: const AiActorSnapshot(
        type: AiActorType.human,
        id: 'human:owner',
        displayName: ' ',
      ),
      trigger: const AiTriggerSnapshot(type: AiTriggerType.scheduled),
      executor: const AiExecutorSnapshot(
        hostId: 'unknown-host',
        displayName: ' ',
      ),
      privacyClassification: AiPrivacyClassification.private,
    );
    final envelope = base.copyWith(attribution: attribution);
    final details = AiAttributionDetails(
      attribution: attribution,
      interactions: const [],
      costTotals: AiCostTotals.empty,
    );

    await pumpSummary(
      tester,
      envelope: envelope,
      details: details,
      width: 320,
      compact: true,
      includeTopSpacing: false,
    );

    expect(find.textContaining('You · Scheduled · Failed'), findsOneWidget);
    expect(find.text('No charge'), findsOneWidget);
    await tester.tap(find.byType(InkWell));
    await tester.pump();
    await tester.pump(MotionDurations.long2);
    expect(find.text('Unknown execution device'), findsOneWidget);
    expect(find.text('No interaction details are available.'), findsOneWidget);
    expect(
      find.text(
        'Request and response content is hidden because this work contains '
        'private data.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders every remaining trigger and terminal status label', (
    tester,
  ) async {
    final base = makeAiTerminalEnvelope();
    final cases = <(AiTriggerType, AiWorkStatus, String)>[
      (
        AiTriggerType.automatic,
        AiWorkStatus.cancelled,
        'Automatic · Cancelled',
      ),
      (AiTriggerType.synced, AiWorkStatus.abandoned, 'From sync · Interrupted'),
      (AiTriggerType.agentTool, AiWorkStatus.partial, 'Agent · Partial'),
      (AiTriggerType.migration, AiWorkStatus.succeeded, 'Imported · Completed'),
    ];

    for (final (trigger, status, expected) in cases) {
      final attribution = base.attribution.copyWith(
        id: '${base.attribution.id}-${trigger.name}',
        status: status,
        initiator: const AiActorSnapshot(
          type: AiActorType.agent,
          id: 'agent-1',
          displayName: '',
        ),
        trigger: AiTriggerSnapshot(type: trigger),
      );
      final envelope = base.copyWith(attribution: attribution);
      final details = AiAttributionDetails(
        attribution: attribution,
        interactions: const [],
        costTotals: const AiCostTotals(
          reportingMicrosByCurrency: {},
          knownInteractionCount: 0,
          unknownInteractionCount: 1,
        ),
      );

      await pumpSummary(tester, envelope: envelope, details: details);

      expect(
        find.textContaining('Unknown creator · $expected'),
        findsOneWidget,
      );
      expect(find.text('Cost unknown'), findsOneWidget);
    }
  });

  testWidgets('details render mixed privacy and multiple currency totals', (
    tester,
  ) async {
    final base = makeAiTerminalEnvelope();
    final attribution = base.attribution.copyWith(
      privacyClassification: AiPrivacyClassification.mixed,
    );
    final envelope = base.copyWith(attribution: attribution);
    final details = AiAttributionDetails(
      attribution: attribution,
      interactions: [
        AiConsumptionEvent(
          id: 'legacy-model-call',
          createdAt: DateTime(2026, 3, 15),
          providerType: InferenceProviderType.openAi,
          responseType: AiConsumptionResponseType.promptGeneration,
          vectorClock: null,
          modelId: 'legacy-model',
        ),
        AiConsumptionEvent(
          id: 'unknown-model-call',
          createdAt: DateTime(2026, 3, 15),
          providerType: InferenceProviderType.openAi,
          responseType: AiConsumptionResponseType.promptGeneration,
          vectorClock: null,
          sequenceIndex: 1,
        ),
      ],
      costTotals: const AiCostTotals(
        reportingMicrosByCurrency: {'USD': 25000, 'EUR': 10000},
        knownInteractionCount: 2,
        unknownInteractionCount: 0,
      ),
    );

    await pumpSummary(tester, envelope: envelope, details: details);
    expect(find.textContaining(' + '), findsOneWidget);
    await tester.tap(find.byType(InkWell));
    await tester.pump();
    await tester.pump(MotionDurations.long2);
    expect(find.text('Mixed'), findsOneWidget);
    expect(
      find.textContaining('Call 1: legacy-model · 0 tokens'),
      findsOneWidget,
    );
    final renderedText = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .whereType<String>();
    expect(renderedText, contains('Call 2: Unknown model · 0 tokens'));
  });
}
