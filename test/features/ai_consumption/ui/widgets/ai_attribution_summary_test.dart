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
      costAssessments: [
        AiInteractionCost(
          id: 'cost-1',
          interactionId: 'call-1',
          source: AiCostSource.providerReported,
          assessedAt: DateTime(2026, 3, 15, 12),
          reportingAmountMicros: 25000,
          reportingCurrency: 'USD',
        ),
      ],
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
    expect(find.text('1. gpt-5'), findsOneWidget);
    await tester.tap(find.text('1. gpt-5'));
    await tester.pump(MotionDurations.short2);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('Provider reported'), findsOneWidget);
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
    expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);

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
    expect(find.text('Cost unknown'), findsOneWidget);
  });

  testWidgets('remains readable at 200 percent text scaling', (tester) async {
    final envelope = makeAiTerminalEnvelope();
    final details = AiAttributionDetails(
      attribution: envelope.attribution,
      interactions: const [],
      costTotals: const AiCostTotals(
        reportingMicrosByCurrency: {'USD': 0},
        knownInteractionCount: 1,
        unknownInteractionCount: 0,
      ),
    );
    await tester.pumpWidget(
      makeTestableWidget(
        SizedBox(
          width: 320,
          child: AiAttributionSummary(
            artifact: makeAiArtifact(),
            envelope: envelope,
          ),
        ),
        mediaQueryData: phoneMediaQueryData.copyWith(
          textScaler: const TextScaler.linear(2),
        ),
        overrides: [
          aiAttributionDetailsProvider.overrideWith(
            (ref, id) async => details,
          ),
        ],
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Ada · Manual · Completed'), findsOneWidget);
    expect(find.text(r'$0.00'), findsOneWidget);
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
      links: const [],
    );
    final envelope = base.copyWith(attribution: attribution);
    final details = AiAttributionDetails(
      attribution: attribution,
      interactions: const [],
      costTotals: const AiCostTotals(
        reportingMicrosByCurrency: {'USD': 0},
        knownInteractionCount: 1,
        unknownInteractionCount: 0,
      ),
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
    expect(find.text(r'$0.00'), findsOneWidget);
    await tester.tap(find.byType(InkWell));
    await tester.pump();
    await tester.pump(MotionDurations.long2);
    expect(find.text('Unknown execution device'), findsOneWidget);
    expect(
      find.text('No interaction details are available.'),
      findsNWidgets(2),
    );
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
    expect(find.text('1. legacy-model'), findsOneWidget);
    expect(find.text('2. Unknown model'), findsOneWidget);
    await tester.tap(find.text('1. legacy-model'));
    await tester.pump(MotionDurations.short2);
    expect(find.text('Token usage unknown'), findsOneWidget);
  });

  testWidgets('labels imported records with unknown privacy explicitly', (
    tester,
  ) async {
    final base = makeAiTerminalEnvelope();
    final attribution = base.attribution.copyWith(
      privacyClassification: AiPrivacyClassification.unknown,
    );
    final envelope = base.copyWith(attribution: attribution);

    await pumpSummary(
      tester,
      envelope: envelope,
      details: AiAttributionDetails(
        attribution: attribution,
        interactions: const [],
        costTotals: AiCostTotals.empty,
      ),
    );
    await tester.tap(find.byType(InkWell));
    await tester.pump();
    await tester.pump(MotionDurations.long2);

    expect(find.text('Unknown'), findsOneWidget);
    expect(
      find.text(
        'Request and response content is hidden because this work contains '
        'private data.',
      ),
      findsNothing,
    );
  });

  testWidgets('surfaces provider errors before and inside the details modal', (
    tester,
  ) async {
    final envelope = makeAiTerminalEnvelope();

    await tester.pumpWidget(
      makeTestableWidget(
        AiAttributionSummary(
          artifact: makeAiArtifact(),
          envelope: envelope,
        ),
        overrides: [
          aiAttributionDetailsProvider.overrideWith(
            (ref, id) => Future<AiAttributionDetails?>.error(
              StateError('details unavailable'),
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Ada · Manual · Completed'), findsOneWidget);
    await tester.tap(find.byType(InkWell));
    await tester.pump();
    await tester.pump(MotionDurations.long2);

    expect(find.text('AI attribution is unavailable.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'details expose artifacts, interaction evidence, outcomes, and cost sources',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1400);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final base = makeAiTerminalEnvelope();
      final attribution = base.attribution.copyWith(
        links: [
          AiAttributionLink(
            id: 'output-link',
            attributionId: base.attribution.id,
            role: AiAttributionLinkRole.output,
            artifact: makeAiArtifact(id: 'output-id', subId: 'version-2'),
          ),
          AiAttributionLink(
            id: 'source-link',
            attributionId: base.attribution.id,
            role: AiAttributionLinkRole.source,
            artifact: makeAiArtifact(id: 'source-id'),
          ),
          AiAttributionLink(
            id: 'context-link',
            attributionId: base.attribution.id,
            role: AiAttributionLinkRole.context,
            artifact: makeAiArtifact(id: 'context-id'),
          ),
        ],
      );
      final envelope = base.copyWith(attribution: attribution);
      const statuses = AiInteractionStatus.values;
      const sources = <AiCostSource>[
        AiCostSource.localCompute,
        AiCostSource.locallyEstimated,
        AiCostSource.externallyReconciled,
        AiCostSource.legacyReported,
      ];
      final interactions = <AiConsumptionEvent>[
        for (var index = 0; index < statuses.length; index++)
          AiConsumptionEvent(
            id: 'call-$index',
            createdAt: DateTime(2026, 3, 15, 12, index),
            completedAt: DateTime(2026, 3, 15, 12, index, 1),
            providerType: InferenceProviderType.openAi,
            responseType: AiConsumptionResponseType.promptGeneration,
            vectorClock: null,
            attributionId: attribution.id,
            sequenceIndex: index,
            interactionStatus: statuses[index],
            providerModelId: 'model-$index',
            providerRequestId: index == 0 ? 'provider-request-42' : null,
            durationMs: index == 0 ? 1500 : null,
            totalTokens: index == 0 ? 42 : null,
            payload: index == 0
                ? AiInteractionPayload(
                    id: 'payload-0',
                    interactionId: 'call-0',
                    request: const [],
                    response: const [],
                    parameters: const {},
                    requestDigest: 'request-sha256',
                    responseDigest: 'response-sha256',
                    capturePolicy: AiPayloadCapturePolicy.metadataOnly,
                    privacyClassification: AiPrivacyClassification.standard,
                    createdAt: DateTime(2026, 3, 15, 12),
                  )
                : null,
          ),
      ];
      final costs = <AiInteractionCost>[
        for (var index = 0; index < sources.length; index++)
          AiInteractionCost(
            id: 'cost-$index',
            interactionId: 'call-$index',
            source: sources[index],
            assessedAt: DateTime(2026, 3, 15, 12, index),
            reportingAmountMicros: index,
            reportingCurrency: 'USD',
          ),
        // Invalid concurrent evidence is deliberately displayed as unknown
        // rather than making the audit sheet fail to open.
        AiInteractionCost(
          id: 'duplicate',
          interactionId: 'call-3',
          source: AiCostSource.providerReported,
          assessedAt: DateTime(2026, 3, 15, 13),
        ),
        AiInteractionCost(
          id: 'duplicate',
          interactionId: 'call-3',
          source: AiCostSource.providerReported,
          assessedAt: DateTime(2026, 3, 15, 13, 1),
        ),
      ];
      final details = AiAttributionDetails(
        attribution: attribution,
        interactions: interactions,
        costTotals: const AiCostTotals(
          reportingMicrosByCurrency: {'USD': 6},
          knownInteractionCount: 3,
          unknownInteractionCount: 1,
        ),
        costAssessments: costs,
      );

      await pumpSummary(tester, envelope: envelope, details: details);
      expect(
        find.textContaining('Some calls have unknown cost'),
        findsOneWidget,
      );
      await tester.tap(find.byType(InkWell));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Output'), findsOneWidget);
      expect(find.text('Source'), findsOneWidget);
      expect(find.text('Context'), findsOneWidget);
      expect(find.textContaining('output-id / version-2'), findsOneWidget);

      const expectedStatuses = ['Completed', 'Failed', 'Cancelled', 'Partial'];
      for (var index = 0; index < interactions.length; index++) {
        final tile = find.text('${index + 1}. model-$index');
        await tester.ensureVisible(tile);
        await tester.pump();
        await tester.tap(tile);
        await tester.pump(const Duration(seconds: 1));
        expect(find.text(expectedStatuses[index]), findsWidgets);
      }

      expect(find.text('0:00:01'), findsWidgets);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('request-sha256'), findsOneWidget);
      expect(find.text('response-sha256'), findsOneWidget);
      expect(find.text('provider-request-42'), findsOneWidget);
      expect(find.text('Local compute'), findsOneWidget);
      expect(find.text('Estimated locally'), findsOneWidget);
      expect(find.text('Reconciled externally'), findsOneWidget);
      expect(find.text('Cost unknown'), findsWidgets);
    },
  );
}
