import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/ai_attribution_summary.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/generated/design_tokens.g.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/modal/sized_wolt_side_sheet_type.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  Future<void> pumpSummary(
    WidgetTester tester, {
    required AiAttributionDetails? details,
    bool includeCarrier = true,
    AiWorkAttribution? carrier,
    Future<AiAttributionDetails?> Function()? loadDetails,
    bool asCaption = false,
    String? unrecordedModel,
    String? taskTitle,
  }) async {
    final attribution = carrier ?? makeAiWorkAttribution();
    await tester.pumpWidget(
      makeTestableWidget(
        AiAttributionSummary(
          artifact: makeAiArtifact(),
          attribution: includeCarrier ? attribution : null,
          asCaption: asCaption,
          unrecordedModel: unrecordedModel,
        ),
        overrides: [
          aiAttributionTaskTitleProvider.overrideWith(
            (ref, taskId) async => taskTitle,
          ),
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

  testWidgets(
    'a single reported token or impact metric still earns its breakdown row, '
    'with the unreported ones shown as dashes',
    (tester) async {
      final attribution = makeAiWorkAttribution();
      await pumpSummary(
        tester,
        details: AiAttributionDetails(
          attribution: attribution,
          interactions: [
            makeConsumptionEvent(
              attributionId: attribution.id,
              inputTokens: null,
              outputTokens: null,
              thoughtsTokens: 64,
              totalTokens: 64,
              energyKwh: null,
              carbonGCo2: null,
            ),
          ],
        ),
      );

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ExpansionTile));
      await tester.pump();

      expect(
        find.text('Input: — · Output: — · Cached: — · Reasoning: 64'),
        findsOneWidget,
      );
      expect(find.text('Impact: — · — CO₂e · 10 mL water'), findsOneWidget);
    },
  );

  testWidgets(
    'caption presents entry attribution and opens the details modal',
    (
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

      await pumpSummary(tester, details: details, asCaption: true);

      // Quiet provenance: one line of small low-emphasis text, not a pill.
      final caption = find.text('voxtral-small · <€0.01 · <1 Wh · 0.1 g');
      expect(caption, findsOneWidget);
      expect(find.byType(DsPill), findsNothing);
      final style = tester.widget<Text>(caption).style!;
      expect(
        style.fontSize,
        dsTokensLight.typography.styles.others.caption.fontSize,
      );
      expect(style.color, dsTokensLight.colors.text.lowEmphasis);

      await tester.tap(caption);
      await tester.pumpAndSettle();

      expect(find.text('AI attribution'), findsOneWidget);
      expect(find.text('<€0.01'), findsWidgets);
    },
  );

  testWidgets(
    'a caption whose calls reported no cost still names its model, without a '
    'cost, and opens the details',
    (tester) async {
      final attribution = makeAiWorkAttribution();
      await pumpSummary(
        tester,
        asCaption: true,
        details: AiAttributionDetails(
          attribution: attribution,
          interactions: [
            makeConsumptionEvent(
              attributionId: attribution.id,
              providerModelId: 'whisper-large-v3',
              credits: null,
              costCreditsDecimal: null,
              energyKwh: null,
              carbonGCo2: null,
            ),
          ],
        ),
      );

      // The label is the model alone: an unreported cost is not spelled out
      // in the caption.
      expect(find.text('whisper-large-v3'), findsOneWidget);
      expect(find.text('Cost unknown'), findsNothing);

      await tester.tap(find.text('whisper-large-v3'));
      await tester.pumpAndSettle();

      expect(find.text('AI attribution'), findsOneWidget);
      // The sheet still says the cost is unknown.
      expect(find.text('Cost unknown'), findsOneWidget);
    },
  );

  testWidgets(
    'an output without any attribution names the model it recorded and says '
    'nothing more was recorded',
    (tester) async {
      await pumpSummary(
        tester,
        asCaption: true,
        details: null,
        includeCarrier: false,
        unrecordedModel: 'mistral-small-latest',
      );

      expect(
        find.text('mistral-small-latest · Provenance not recorded'),
        findsOneWidget,
      );

      // There is no record to open.
      await tester.tap(
        find.text('mistral-small-latest · Provenance not recorded'),
      );
      await tester.pumpAndSettle();
      expect(find.text('AI attribution'), findsNothing);
    },
  );

  for (final (label, load) in [
    ('not synced yet', Future<AiAttributionDetails?>.value),
    (
      'failing',
      () => Future<AiAttributionDetails?>.error(StateError('unavailable')),
    ),
  ]) {
    testWidgets('a caption whose details are $label stays', (tester) async {
      await pumpSummary(
        tester,
        asCaption: true,
        details: null,
        loadDetails: load,
      );
      await tester.pump();

      expect(find.text('Unknown model'), findsOneWidget);
    });
  }

  testWidgets(
    'a group with an attribution not yet synced keeps its caption',
    (tester) async {
      final transcription = makeAiWorkAttribution();
      final unsynced = makeAiWorkAttribution(attributionId: 'attribution-2');

      await tester.pumpWidget(
        makeTestableWidget(
          AiAttributionSummaryGroup(
            label: 'Transcription',
            attributions: [transcription, unsynced],
          ),
          overrides: [
            aiAttributionDetailsProvider.overrideWith(
              (ref, id) async => id == transcription.id
                  ? AiAttributionDetails(
                      attribution: transcription,
                      interactions: [
                        makeConsumptionEvent(
                          attributionId: transcription.id,
                          credits: null,
                          costCreditsDecimal: null,
                          energyKwh: null,
                          carbonGCo2: null,
                        ),
                      ],
                    )
                  : null,
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Transcription'), findsOneWidget);
    },
  );

  testWidgets(
    'a group whose calls reported no cost still shows, with its gap above',
    (tester) async {
      final transcription = makeAiWorkAttribution();
      final correction = makeAiWorkAttribution(attributionId: 'attribution-2');
      final detailsById = {
        for (final attribution in [transcription, correction])
          attribution.id: AiAttributionDetails(
            attribution: attribution,
            interactions: [
              makeConsumptionEvent(
                attributionId: attribution.id,
                credits: null,
                costCreditsDecimal: null,
              ),
            ],
          ),
      };

      await tester.pumpWidget(
        makeTestableWidget(
          AiAttributionSummaryGroup(
            label: 'Transcription',
            attributions: [transcription, correction],
            topSpacing: 12,
          ),
          overrides: [
            aiAttributionDetailsProvider.overrideWith(
              (ref, id) async => detailsById[id],
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Transcription · <1 Wh · 0.2 g'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Transcription · <1 Wh · 0.2 g')).dy -
            tester.getTopLeft(find.byType(AiAttributionSummaryGroup)).dy,
        12,
      );
    },
  );

  testWidgets(
    'a group sums the calls that reported a cost and keeps its gap above',
    (tester) async {
      final transcription = makeAiWorkAttribution();
      final correction = makeAiWorkAttribution(attributionId: 'attribution-2');
      final detailsById = {
        transcription.id: AiAttributionDetails(
          attribution: transcription,
          interactions: [
            makeConsumptionEvent(
              attributionId: transcription.id,
              credits: null,
              costCreditsDecimal: null,
              energyKwh: null,
              carbonGCo2: null,
            ),
          ],
        ),
        correction.id: AiAttributionDetails(
          attribution: correction,
          interactions: [
            makeConsumptionEvent(
              attributionId: correction.id,
              credits: 0.4,
              energyKwh: null,
              carbonGCo2: null,
            ),
          ],
        ),
      };

      await tester.pumpWidget(
        makeTestableWidget(
          AiAttributionSummaryGroup(
            label: 'Transcription',
            attributions: [transcription, correction],
            topSpacing: 12,
          ),
          overrides: [
            aiAttributionDetailsProvider.overrideWith(
              (ref, id) async => detailsById[id],
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Transcription · €0.40'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Transcription · €0.40')).dy -
            tester.getTopLeft(find.byType(AiAttributionSummaryGroup)).dy,
        12,
      );
    },
  );

  for (final layout in [
    (name: 'desktop', size: const Size(1024, 768), bottomSheet: false),
    (name: 'phone', size: const Size(390, 844), bottomSheet: true),
  ]) {
    testWidgets(
      'group caption aggregates transcript cost and impact into one entry '
      'control (${layout.name})',
      (tester) async {
        await tester.binding.setSurfaceSize(layout.size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
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

        await tester.tap(find.text('Transcription · €0.30 · 12 Wh · 3.0 g'));
        await tester.pumpAndSettle();
        expect(find.text('AI attribution'), findsOneWidget);

        // Phones get a bottom sheet; wider layouts a side sheet.
        final sheet = find.byWidgetPredicate((w) => w is WoltModalSheet);
        final modalType = tester
            .widget<WoltModalSheet<dynamic>>(sheet)
            .modalTypeBuilder!(tester.element(sheet));
        expect(
          modalType,
          layout.bottomSheet
              ? isA<WoltBottomSheetType>()
              : isA<SizedWoltSideSheetType>(),
        );
      },
    );
  }

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

  group('source section', () {
    AiWorkAttribution attributionWith(
      AiTriggerSnapshot trigger, {
      String? taskId,
    }) => makeAiWorkAttribution().copyWith(trigger: trigger, taskId: taskId);

    Future<void> openSheet(
      WidgetTester tester,
      AiWorkAttribution attribution, {
      String? taskTitle,
    }) async {
      await pumpSummary(
        tester,
        carrier: attribution,
        taskTitle: taskTitle,
        details: AiAttributionDetails(
          attribution: attribution,
          interactions: const [],
        ),
      );
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
    }

    const fullTrigger = AiTriggerSnapshot(
      type: AiTriggerType.automatic,
      skillId: 'skill-1',
      skillName: 'Image analysis',
      profileId: 'profile-1',
      profileName: 'Penguin vision',
      agentId: 'agent-1',
      agentName: 'Waddle planner',
    );

    testWidgets('names the agent, profile, skill and task that did the work', (
      tester,
    ) async {
      await openSheet(
        tester,
        attributionWith(fullTrigger, taskId: 'task-1'),
        taskTitle: 'Count the colony',
      );

      expect(find.text('Source'), findsOneWidget);
      expect(find.text('Waddle planner'), findsOneWidget);
      expect(find.text('Penguin vision'), findsOneWidget);
      expect(find.text('Image analysis'), findsOneWidget);
      expect(find.text('Count the colony'), findsOneWidget);
    });

    for (final (row, route) in [
      ('ai-attribution-source-agent', '/settings/agents/instances/agent-1'),
      ('ai-attribution-source-profile', '/settings/ai/profile/profile-1'),
      ('ai-attribution-source-task', '/tasks/task-1'),
    ]) {
      testWidgets('$row closes the sheet and opens $route', (tester) async {
        final beamed = <String>[];
        beamToNamedOverride = beamed.add;
        addTearDown(() => beamToNamedOverride = null);

        await openSheet(tester, attributionWith(fullTrigger, taskId: 'task-1'));
        await tester.ensureVisible(find.byKey(ValueKey(row)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey(row)));
        await tester.pumpAndSettle();

        expect(beamed, [route]);
        expect(find.text('AI attribution'), findsNothing);
      });
    }

    testWidgets('a screen reader can follow a link through its semantics', (
      tester,
    ) async {
      final beamed = <String>[];
      beamToNamedOverride = beamed.add;
      addTearDown(() => beamToNamedOverride = null);
      final handle = tester.ensureSemantics();

      await openSheet(
        tester,
        attributionWith(fullTrigger, taskId: 'task-1'),
        taskTitle: 'Count the colony',
      );
      final link = find.bySemanticsLabel('Task: Count the colony');
      expect(
        tester.getSemantics(link),
        matchesSemantics(
          label: 'Task: Count the colony',
          isLink: true,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(find.semantics.byLabel('Task: Count the colony'));
      await tester.pumpAndSettle();

      expect(beamed, ['/tasks/task-1']);
      expect(find.text('AI attribution'), findsNothing);
      handle.dispose();
    });

    testWidgets(
      'falls back to ids and the generic task link when no name was recorded',
      (tester) async {
        await openSheet(
          tester,
          attributionWith(
            const AiTriggerSnapshot(
              type: AiTriggerType.automatic,
              profileId: 'profile-1',
              agentId: 'agent-1',
            ),
            taskId: 'task-1',
          ),
        );

        expect(find.text('agent-1'), findsOneWidget);
        expect(find.text('profile-1'), findsOneWidget);
        expect(find.text('Open task'), findsOneWidget);
        expect(find.text('Skill'), findsNothing);
      },
    );

    testWidgets('is left out when the attribution names no source', (
      tester,
    ) async {
      await openSheet(tester, makeAiWorkAttribution());

      expect(find.text('AI attribution'), findsOneWidget);
      expect(find.text('Source'), findsNothing);
    });
  });
}
