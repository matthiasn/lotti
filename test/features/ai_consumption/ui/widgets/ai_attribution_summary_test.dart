import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/ai_attribution_summary.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  Future<void> pumpSummary(
    WidgetTester tester, {
    required AiAttributionDetails? details,
    bool includeCarrier = true,
    AiWorkAttribution? carrier,
    Future<AiAttributionDetails?> Function()? loadDetails,
    bool asPill = false,
  }) async {
    final attribution = carrier ?? makeAiWorkAttribution();
    await tester.pumpWidget(
      makeTestableWidget(
        AiAttributionSummary(
          artifact: makeAiArtifact(),
          attribution: includeCarrier ? attribution : null,
          asPill: asPill,
        ),
        overrides: [
          aiAttributionDetailsProvider.overrideWith(
            (ref, id) => loadDetails?.call() ?? Future.value(details),
          ),
          aiAttributionForArtifactProvider.overrideWith(
            (ref, artifact) async => details,
          ),
        ],
      ),
    );
    await tester.pump();
  }

  testWidgets('shows creator, model, call count, and actual Melious cost', (
    tester,
  ) async {
    final attribution = makeAiWorkAttribution();
    final details = AiAttributionDetails(
      attribution: attribution,
      interactions: [
        makeConsumptionEvent(
          attributionId: attribution.id,
          providerModelId: 'gpt-5',
          credits: 0.25,
          costCreditsDecimal: '0.25',
        ),
      ],
    );

    await pumpSummary(tester, details: details);

    expect(find.textContaining('Ada'), findsOneWidget);
    expect(find.textContaining('gpt-5'), findsOneWidget);
    expect(find.textContaining('1 call'), findsOneWidget);
    expect(find.textContaining('€0.25'), findsOneWidget);
  });

  testWidgets('details expose token usage and request/response digests', (
    tester,
  ) async {
    final attribution = makeAiWorkAttribution();
    final details = AiAttributionDetails(
      attribution: attribution,
      interactions: [
        makeConsumptionEvent(
          attributionId: attribution.id,
          requestDigest: 'request-sha',
          responseDigest: 'response-sha',
        ),
      ],
    );
    await pumpSummary(tester, details: details);

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ExpansionTile));
    await tester.pump();

    expect(find.text('1,500'), findsOneWidget);
    expect(find.text('request-sha'), findsOneWidget);
    expect(find.text('response-sha'), findsOneWidget);
    expect(
      find.text('Input: 1,000 · Output: 500 · Cached: — · Reasoning: —'),
      findsOneWidget,
    );
    expect(
      find.text('Impact: <1 Wh · 0.1 g CO₂e · 10 mL water'),
      findsOneWidget,
    );
  });

  testWidgets('pill presents entry attribution and opens the details modal', (
    tester,
  ) async {
    final attribution = makeAiWorkAttribution();
    final details = AiAttributionDetails(
      attribution: attribution,
      interactions: [
        makeConsumptionEvent(
          attributionId: attribution.id,
          providerModelId: 'voxtral-small',
          credits: 0.0042,
          costCreditsDecimal: '0.0042',
        ),
      ],
    );

    await pumpSummary(tester, details: details, asPill: true);

    expect(find.byType(DsPill), findsOneWidget);
    expect(
      find.text('voxtral-small · <€0.01 · <1 Wh · 0.1 g'),
      findsOneWidget,
    );

    await tester.tap(find.byType(DsPill));
    await tester.pumpAndSettle();

    expect(find.text('AI attribution'), findsOneWidget);
    expect(find.text('<€0.01'), findsWidgets);
  });

  testWidgets(
    'group pill aggregates transcript cost and impact into one entry control',
    (tester) async {
      final first = makeAiWorkAttribution();
      final second = makeAiWorkAttribution(attributionId: 'attribution-2');
      final detailsById = {
        first.id: AiAttributionDetails(
          attribution: first,
          interactions: [
            makeConsumptionEvent(
              attributionId: first.id,
              credits: 0.1,
              energyKwh: 0.002,
              carbonGCo2: 0.5,
            ),
          ],
        ),
        second.id: AiAttributionDetails(
          attribution: second,
          interactions: [
            makeConsumptionEvent(
              attributionId: second.id,
              credits: 0.2,
              energyKwh: 0.01,
              carbonGCo2: 2.5,
              waterLiters: 0.02,
            ),
          ],
        ),
      };

      await tester.pumpWidget(
        makeTestableWidget(
          AiAttributionSummaryGroup(
            label: 'Transcription',
            attributions: [first, second],
          ),
          overrides: [
            aiAttributionDetailsProvider.overrideWith(
              (ref, id) async => detailsById[id],
            ),
          ],
        ),
      );
      await tester.pump();

      expect(
        find.text('Transcription · €0.30 · 12 Wh · 3.0 g'),
        findsOneWidget,
      );

      await tester.tap(find.byType(DsPill));
      await tester.pumpAndSettle();
      expect(find.text('AI attribution'), findsOneWidget);
    },
  );

  testWidgets('renders nothing when neither carrier nor projection exists', (
    tester,
  ) async {
    await pumpSummary(tester, details: null, includeCarrier: false);

    expect(find.byType(AiAttributionSummary), findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('detail sheet explains missing projected details', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSummary(tester, details: null);
    await tester.pump();

    await tester.tap(find.byType(InkWell));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Loading AI attribution…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('detail sheet reports an unavailable projection', (
    tester,
  ) async {
    await pumpSummary(
      tester,
      details: null,
      loadDetails: () => Future.error(StateError('unavailable')),
    );
    await tester.pump();

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(find.text('AI attribution is unavailable.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('details explain an attribution with no provider calls', (
    tester,
  ) async {
    final attribution = makeAiWorkAttribution().copyWith(
      initiator: const AiActorSnapshot(
        type: AiActorType.human,
        id: 'human-1',
        displayName: '   ',
      ),
      trigger: const AiTriggerSnapshot(type: AiTriggerType.automatic),
      status: AiWorkStatus.failed,
      completedAt: DateTime(2026, 3, 15, 12, 0, 0, 250),
    );
    await pumpSummary(
      tester,
      details: AiAttributionDetails(
        attribution: attribution,
        interactions: const [],
      ),
      carrier: attribution,
    );

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(find.text('You'), findsOneWidget);
    expect(find.text('Automatic'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('0:00:00.250000'), findsOneWidget);
    expect(
      find.text('No interaction details are available.'),
      findsOneWidget,
    );
  });

  testWidgets('interaction cards cover unknown values and every status', (
    tester,
  ) async {
    final attribution = makeAiWorkAttribution();
    final interactions = [
      for (final status in AiInteractionStatus.values)
        makeConsumptionEvent(
          id: 'event-${status.name}',
          attributionId: attribution.id,
          interactionStatus: status,
          modelId: null,
          durationMs: status == AiInteractionStatus.partial ? 500 : null,
          totalTokens: null,
          credits: null,
          costCreditsDecimal: null,
        ),
    ];
    await pumpSummary(
      tester,
      details: AiAttributionDetails(
        attribution: attribution,
        interactions: interactions,
      ),
      carrier: attribution,
    );

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pump();

    expect(find.text('Unknown model'), findsNWidgets(interactions.length));
    expect(
      find.text('Token usage unknown'),
      findsOneWidget,
    );
    expect(find.text('Cost unknown'), findsWidgets);
    for (final label in const ['Completed', 'Failed', 'Cancelled', 'Partial']) {
      expect(find.textContaining(label), findsWidgets);
    }
  });

  final triggerCases = [
    (AiTriggerType.manual, 'Manual'),
    (AiTriggerType.automatic, 'Automatic'),
    (AiTriggerType.scheduled, 'Scheduled'),
    (AiTriggerType.synced, 'From sync'),
    (AiTriggerType.agentTool, 'Agent'),
    (AiTriggerType.migration, 'Imported'),
  ];
  for (var index = 0; index < triggerCases.length; index++) {
    final triggerCase = triggerCases[index];
    final status = AiWorkStatus.values[index % AiWorkStatus.values.length];
    testWidgets(
      'details label ${triggerCase.$1.name} trigger and ${status.name} work',
      (tester) async {
        final attribution = makeAiWorkAttribution().copyWith(
          initiator: AiActorSnapshot(
            type: index.isEven ? AiActorType.agent : AiActorType.human,
            id: 'actor-$index',
            displayName: '',
          ),
          trigger: AiTriggerSnapshot(type: triggerCase.$1),
          status: status,
        );
        await pumpSummary(
          tester,
          details: AiAttributionDetails(
            attribution: attribution,
            interactions: const [],
          ),
          carrier: attribution,
        );

        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();

        expect(find.text(triggerCase.$2), findsOneWidget);
        expect(
          find.text(index.isEven ? 'Unknown creator' : 'You'),
          findsOneWidget,
        );
      },
    );
  }
}
