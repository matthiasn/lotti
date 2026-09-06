import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_token_usage.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/agents/ui/widgets/ai_card_chrome.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/model/relationship_health_metrics.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/contact_launcher.dart';
import 'package:lotti/features/relationships/service/pending_interaction_store.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_briefing_card.dart';
import 'package:lotti/features/relationships/util/contact_channel_uri.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/test_data/ai_config_factories.dart';
import '../../../agents/test_data/entity_factories.dart';

class _FakeContactLauncher implements ContactLauncher {
  _FakeContactLauncher({required this.launchable});

  final Set<ContactAction> launchable;
  final List<(ContactChannel, ContactAction)> launched = [];

  @override
  Future<bool> canLaunch(ContactChannel channel, ContactAction action) async =>
      launchable.contains(action) && contactChannelUri(channel, action) != null;

  @override
  Future<bool> launch(ContactChannel channel, ContactAction action) async {
    launched.add((channel, action));
    return true;
  }
}

class _FakePendingInteractionStore implements PendingInteractionStore {
  PendingInteraction? remembered;

  @override
  Future<void> remember({
    required String relationshipId,
    required CheckInInteractionType interactionType,
  }) async {
    remembered = (
      relationshipId: relationshipId,
      interactionType: interactionType,
      startedAt: DateTime(2026, 8, 13, 14),
    );
  }

  @override
  Future<PendingInteraction?> read() async => remembered;

  @override
  Future<void> clear() async => remembered = null;
}

void main() {
  setUpAll(registerAllFallbackValues);

  const relationshipId = 'person-1';
  final agentId = relationshipAgentIdFor(relationshipId);
  // A Thursday afternoon.
  final now = DateTime(2026, 8, 13, 14);
  const mobile = ContactChannel(
    type: ContactChannelType.mobile,
    value: '+15550109999',
  );

  late MockRelationshipAgentService agentService;
  late MockRelationshipRepository repository;
  late _FakePendingInteractionStore store;

  RelationshipEntry relationship({
    bool important = true,
    int? cadenceDays = 7,
    RelationshipStatus? status,
    List<ContactChannel> channels = const [],
  }) => RelationshipEntry(
    meta: Metadata(
      id: relationshipId,
      createdAt: DateTime(2026, 7),
      updatedAt: DateTime(2026, 7),
      dateFrom: DateTime(2026, 7),
      dateTo: DateTime(2026, 7),
    ),
    data: RelationshipData(
      title: 'Commander Pip Frostbeak',
      nickname: 'Pip',
      important: important,
      checkInCadenceDays: cadenceDays,
      contactChannels: channels,
      status:
          status ??
          RelationshipStatus.active(
            id: 'status-1',
            createdAt: DateTime(2026, 7),
            utcOffset: 0,
          ),
    ),
  );

  CheckInEntry checkIn(String id, DateTime at) => CheckInEntry(
    meta: Metadata(
      id: id,
      createdAt: at,
      updatedAt: at,
      dateFrom: at,
      dateTo: at,
    ),
    data: const CheckInData(
      relationshipId: relationshipId,
      interactionType: CheckInInteractionType.call,
    ),
  );

  /// Two check-ins, the latest one yesterday evening: on track, next due
  /// Wed 19 Aug.
  final onTrackCheckIns = [
    checkIn('c2', DateTime(2026, 8, 12, 19, 5)),
    checkIn('c1', DateTime(2026, 8, 5, 9, 30)),
  ];

  /// One check-in twelve days ago: five days over a weekly cadence.
  final lapsedCheckIns = [checkIn('c1', DateTime(2026, 8))];

  AgentReportEntity report({
    String? tldr = 'Pip is in good spirits.',
    String content = 'The **long** version.',
    String? band = 'thriving',
    DateTime? createdAt,
  }) =>
      AgentDomainEntity.agentReport(
            id: 'report-1',
            agentId: agentId,
            scope: AgentReportScopes.current,
            createdAt: createdAt ?? now.subtract(const Duration(hours: 1)),
            vectorClock: null,
            content: content,
            tldr: tldr,
            provenance: {
              RelationshipReportProvenanceKeys.healthBand: ?band,
              RelationshipReportProvenanceKeys.healthRationale:
                  'Two good calls in a row.',
            },
          )
          as AgentReportEntity;

  AgentStateEntity agentState({
    DateTime? lastWakeAt,
    int failures = 0,
    DateTime? staleAt,
    DateTime? freshAt,
  }) => makeTestState(
    agentId: agentId,
    lastWakeAt: lastWakeAt,
    consecutiveFailureCount: failures,
  ).copyWith(reportStaleAt: staleAt, reportFreshAt: freshAt);

  ResolvedAgentSetup resolvedSetup() {
    final model = testAiModel();
    return ResolvedAgentSetup(
      status: AgentSetupResolutionStatus.resolved,
      profile: ResolvedProfile(
        thinkingModelId: model.providerModelId,
        thinkingProvider: testInferenceProvider(),
        thinkingModel: model,
      ),
    );
  }

  setUp(() {
    agentService = MockRelationshipAgentService();
    when(() => agentService.requestBriefing(any())).thenAnswer((_) async {});
    repository = MockRelationshipRepository();
    when(
      () => repository.updateRelationship(any()),
    ).thenAnswer((_) async => true);
    store = _FakePendingInteractionStore();
  });

  Future<_FakeContactLauncher> pump(
    WidgetTester tester, {
    RelationshipEntry? entry,
    List<CheckInEntry> checkIns = const [],
    AgentReportEntity? current,
    AgentStateEntity? state,
    bool running = false,
    bool modelResolved = true,
    int totalTokens = 0,
    String? disclosureProviderName,
    Set<ContactAction> launchable = const {ContactAction.call},
  }) async {
    final launcher = _FakeContactLauncher(launchable: launchable);
    await withClock(Clock.fixed(now), () async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          RelationshipBriefingCard(
            relationship: entry ?? relationship(),
            checkIns: checkIns,
          ),
          overrides: [
            agentReportProvider(agentId).overrideWith((ref) async => current),
            agentStateProvider(agentId).overrideWith((ref) async => state),
            agentIsRunningProvider(
              agentId,
            ).overrideWith((ref) => Stream.value(running)),
            agentIdentityProvider(agentId).overrideWith(
              (ref) async => makeTestIdentity(
                agentId: agentId,
                kind: AgentKinds.relationshipAgent,
                displayName: 'Commander Pip Frostbeak',
              ),
            ),
            taskAgentResolvedSetupProvider(agentId).overrideWith(
              (ref) async => modelResolved
                  ? resolvedSetup()
                  : const ResolvedAgentSetup(
                      status: AgentSetupResolutionStatus.disabled,
                    ),
            ),
            agentTokenUsageSummariesProvider(agentId).overrideWith(
              (ref) async => [
                if (totalTokens > 0)
                  AgentTokenUsageSummary(
                    modelId: 'model-1',
                    inputTokens: totalTokens,
                  ),
              ],
            ),
            taskAgentSetupOptionsProvider.overrideWith(
              (ref) async => const TaskAgentSetupOptions(
                profiles: [],
                models: [],
                providers: [],
              ),
            ),
            relationshipAgentServiceProvider.overrideWithValue(agentService),
            relationshipBriefingDisclosureProvider(
              relationshipId,
            ).overrideWith((ref) async => disclosureProviderName),
            relationshipRepositoryProvider.overrideWithValue(repository),
            contactLauncherProvider.overrideWithValue(launcher),
            pendingInteractionStoreProvider.overrideWithValue(store),
          ],
        ),
      );
      await tester.pumpAndSettle();
    });
    return launcher;
  }

  String statusText(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const ValueKey('relationship-agent-status')))
      .data!;
  final briefMe = find.byKey(const ValueKey('relationship-brief-me'));

  group('relationshipAgentCardStateOf', () {
    final at = DateTime(2026, 8, 13, 13, 41);

    test('not enrolled beats everything', () {
      expect(
        relationshipAgentCardStateOf(
          enrolled: false,
          isRunning: true,
          report: report(),
          state: agentState(failures: 2, lastWakeAt: at),
        ),
        RelationshipAgentCardState.notEnrolled,
      );
    });

    test('running beats a failure and a stale briefing', () {
      expect(
        relationshipAgentCardStateOf(
          enrolled: true,
          isRunning: true,
          report: report(),
          state: agentState(failures: 1, lastWakeAt: at, staleAt: at),
        ),
        RelationshipAgentCardState.running,
      );
    });

    test('a failure counts while nothing newer succeeded', () {
      expect(
        relationshipAgentCardStateOf(
          enrolled: true,
          isRunning: false,
          report: null,
          state: agentState(failures: 1, lastWakeAt: at),
        ),
        RelationshipAgentCardState.failed,
      );
      expect(
        relationshipAgentCardStateOf(
          enrolled: true,
          isRunning: false,
          report: report(createdAt: at.subtract(const Duration(hours: 2))),
          state: agentState(failures: 1, lastWakeAt: at),
        ),
        RelationshipAgentCardState.failed,
      );
    });

    test('a failure older than the briefing is history, not a state', () {
      expect(
        relationshipAgentCardStateOf(
          enrolled: true,
          isRunning: false,
          report: report(createdAt: at.add(const Duration(hours: 1))),
          state: agentState(failures: 3, lastWakeAt: at),
        ),
        RelationshipAgentCardState.current,
      );
    });

    test('no briefing, out of date, current', () {
      expect(
        relationshipAgentCardStateOf(
          enrolled: true,
          isRunning: false,
          report: null,
          state: null,
        ),
        RelationshipAgentCardState.noBriefing,
      );
      expect(
        relationshipAgentCardStateOf(
          enrolled: true,
          isRunning: false,
          report: report(),
          state: agentState(staleAt: at),
        ),
        RelationshipAgentCardState.outOfDate,
      );
      expect(
        relationshipAgentCardStateOf(
          enrolled: true,
          isRunning: false,
          report: report(),
          state: agentState(
            staleAt: at,
            freshAt: at.add(const Duration(minutes: 1)),
          ),
        ),
        RelationshipAgentCardState.current,
      );
    });

    glados.Glados3<bool, bool, int>(
      glados.any.bool,
      glados.any.bool,
      glados.any.intInRange(0, 4),
    ).test('enrolment and running are decided before anything else, and a '
        'briefing is a precondition of current and out of date', (
      enrolled,
      running,
      failures,
    ) {
      for (final hasReport in [true, false]) {
        final state = relationshipAgentCardStateOf(
          enrolled: enrolled,
          isRunning: running,
          report: hasReport ? report() : null,
          state: agentState(failures: failures, lastWakeAt: now),
        );
        expect(state == RelationshipAgentCardState.notEnrolled, !enrolled);
        if (enrolled) {
          expect(state == RelationshipAgentCardState.running, running);
        }
        if (state == RelationshipAgentCardState.current ||
            state == RelationshipAgentCardState.outOfDate) {
          expect(hasReport, isTrue);
        }
        if (enrolled && !running && failures > 0) {
          // The wake is newer than any report here, so it is the state.
          expect(state, RelationshipAgentCardState.failed);
        }
      }
    }, tags: 'glados');
  });

  group('not enrolled', () {
    testWidgets('is a plain section card, no AI chrome, saying what '
        'important turns on', (tester) async {
      await pump(tester, entry: relationship(important: false));

      expect(find.byType(AgentSummaryCardSurface), findsNothing);
      expect(find.byType(DesignSystemSectionCard), findsOneWidget);
      expect(find.text('Briefing'), findsOneWidget);
      expect(find.text('no agent for this person'), findsOneWidget);
      expect(
        tester
            .widget<DsPill>(
              find.byKey(const ValueKey('relationship-agent-pill-status')),
            )
            .label,
        'Not enrolled',
      );
      expect(
        find.textContaining('Mark Pip as important to get a briefing'),
        findsOneWidget,
      );
      expect(statusText(tester), 'Not enrolled');
      expect(find.text('Mark important'), findsOneWidget);
    });

    testWidgets('Mark important switches the person on through the '
        'repository', (tester) async {
      await pump(tester, entry: relationship(important: false));

      await tester.tap(
        find.byKey(const ValueKey('relationship-agent-mark-important')),
      );
      await tester.pumpAndSettle();

      final saved =
          verify(
                () => repository.updateRelationship(captureAny()),
              ).captured.single
              as RelationshipEntry;
      expect(saved.data.important, isTrue);
      expect(saved.meta.id, relationshipId);
    });

    testWidgets('Mark important also mints the agent, the way the edit form '
        'does — otherwise nothing proactive ever starts', (tester) async {
      when(
        () => agentService.ensureAgentForRelationship(any()),
      ).thenAnswer((_) async => makeTestIdentity(agentId: agentId));
      await pump(tester, entry: relationship(important: false));

      await tester.tap(
        find.byKey(const ValueKey('relationship-agent-mark-important')),
      );
      await tester.pumpAndSettle();

      final ensured =
          verify(
                () => agentService.ensureAgentForRelationship(captureAny()),
              ).captured.single
              as RelationshipEntry;
      expect(ensured.data.important, isTrue);
    });

    testWidgets('a failed agent creation never fails the save the user '
        'watched succeed', (tester) async {
      when(
        () => agentService.ensureAgentForRelationship(any()),
      ).thenThrow(StateError('agent db closed'));
      await pump(tester, entry: relationship(important: false));

      await tester.tap(
        find.byKey(const ValueKey('relationship-agent-mark-important')),
      );
      await tester.pumpAndSettle();

      verify(() => repository.updateRelationship(any())).called(1);
      expect(
        find.text('Could not save the changes. Please try again.'),
        findsNothing,
      );
    });

    testWidgets('a rejected save says so', (tester) async {
      when(
        () => repository.updateRelationship(any()),
      ).thenAnswer((_) async => false);
      await pump(tester, entry: relationship(important: false));

      await tester.tap(
        find.byKey(const ValueKey('relationship-agent-mark-important')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Could not save the changes. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('a throwing save says so too', (tester) async {
      when(
        () => repository.updateRelationship(any()),
      ).thenThrow(StateError('db closed'));
      await pump(tester, entry: relationship(important: false));

      await tester.tap(
        find.byKey(const ValueKey('relationship-agent-mark-important')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Could not save the changes. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('an important but dormant person is paused, with the status '
        'as the footer and no switch to press', (tester) async {
      await pump(
        tester,
        entry: relationship(
          status: RelationshipStatus.dormant(
            id: 's',
            createdAt: now,
            utcOffset: 0,
          ),
        ),
      );

      expect(
        find.text('Briefings pause while this person is dormant or archived.'),
        findsOneWidget,
      );
      expect(statusText(tester), 'Dormant');
      expect(find.text('Mark important'), findsNothing);
    });
  });

  group('enrolled, no briefing', () {
    testWidgets('wears the AI chrome, names the watching agent, counts the '
        'check-ins it would read, and offers Brief now next to the next '
        'look', (tester) async {
      await pump(tester, checkIns: onTrackCheckIns);

      final card = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byKey(const ValueKey('relationship-briefing-card')),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final context = tester.element(find.byType(RelationshipBriefingCard));
      expect(card.decoration, aiCardDecoration(context));
      expect(find.text('agent watching · no run yet'), findsOneWidget);
      expect(
        find.text(
          'No briefing yet. Brief now writes one from your 2 check-ins; it '
          'never sees the phone number or email.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<DsPill>(
              find.byKey(const ValueKey('relationship-agent-pill-cadence')),
            )
            .label,
        'On track · Weekly',
      );
      expect(statusText(tester), 'Next look Wed 19 Aug');
      expect(find.text('Brief now'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('relationship-chat-button')),
        findsNothing,
      );
    });

    testWidgets('with no check-in yet the body says what to do first and the '
        'next look is still known from the tracking start', (tester) async {
      await pump(tester);

      expect(
        find.textContaining('writes one once you have logged a check-in'),
        findsOneWidget,
      );
      expect(statusText(tester), startsWith('Next look'));
    });

    testWidgets('Brief now on a LOCAL route requests without any dialog', (
      tester,
    ) async {
      await pump(tester, checkIns: onTrackCheckIns);

      await tester.tap(briefMe);
      await tester.pumpAndSettle();

      verify(() => agentService.requestBriefing(any())).called(1);
      expect(
        find.text('Briefing requested — it will appear here shortly.'),
        findsOneWidget,
      );
    });

    testWidgets('Brief now on a CLOUD route names the provider first and '
        'only proceeds on consent', (tester) async {
      await pump(
        tester,
        checkIns: onTrackCheckIns,
        disclosureProviderName: 'Mission Control Cloud',
      );

      await tester.tap(briefMe);
      await tester.pumpAndSettle();
      expect(find.text('Send to Mission Control Cloud?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      verifyNever(() => agentService.requestBriefing(any()));

      await tester.tap(briefMe);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      verify(() => agentService.requestBriefing(any())).called(1);
    });

    testWidgets('a failed request surfaces the error toast', (tester) async {
      when(
        () => agentService.requestBriefing(any()),
      ).thenThrow(StateError('no model'));
      await pump(tester, checkIns: onTrackCheckIns);

      await tester.tap(briefMe);
      await tester.pumpAndSettle();

      expect(find.text('Could not request the briefing.'), findsOneWidget);
    });
  });

  group('running', () {
    testWidgets('says the agent is writing, what it is reading, and since '
        'when — with nothing to press', (tester) async {
      await pump(
        tester,
        checkIns: onTrackCheckIns,
        running: true,
        state: agentState(lastWakeAt: DateTime(2026, 8, 13, 13, 41)),
      );

      expect(find.text('writing the briefing…'), findsOneWidget);
      expect(find.text('Reading 2 check-ins…'), findsOneWidget);
      expect(statusText(tester), 'Running · started 13:41');
      expect(briefMe, findsNothing);
      expect(find.byType(DesignSystemButton), findsNothing);
    });

    testWidgets('keeps the band and the briefing pills while a refresh runs', (
      tester,
    ) async {
      await pump(
        tester,
        checkIns: onTrackCheckIns,
        current: report(),
        running: true,
      );

      expect(find.text('Thriving'), findsOneWidget);
      expect(statusText(tester), 'Running');
    });
  });

  group('failed', () {
    final failedAt = DateTime(2026, 8, 13, 13, 41);

    testWidgets('with no model set up, the reason is the fix: Choose a model', (
      tester,
    ) async {
      await pump(
        tester,
        checkIns: onTrackCheckIns,
        modelResolved: false,
        state: agentState(failures: 1, lastWakeAt: failedAt),
      );

      expect(find.text('last run failed · 13:41'), findsOneWidget);
      expect(
        find.textContaining('No model is set up for briefings.'),
        findsOneWidget,
      );
      expect(statusText(tester), 'Failed · 13:41');
      expect(find.text('Choose a model'), findsOneWidget);
      expect(briefMe, findsNothing);
    });

    testWidgets('Choose a model opens the agent setup sheet', (tester) async {
      await pump(
        tester,
        checkIns: onTrackCheckIns,
        modelResolved: false,
        state: agentState(failures: 1, lastWakeAt: failedAt),
      );

      await tester.tap(
        find.byKey(const ValueKey('relationship-agent-choose-model')),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(RelationshipBriefingCard));
      expect(find.text(context.messages.taskAgentSetupTitle), findsOneWidget);
    });

    testWidgets('with a model, the action is Try again, which requests a '
        'briefing', (tester) async {
      await pump(
        tester,
        checkIns: onTrackCheckIns,
        state: agentState(failures: 2, lastWakeAt: failedAt),
      );

      expect(
        find.text(
          'The last briefing run failed. Details are in the Activity tab.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      verify(() => agentService.requestBriefing(any())).called(1);
    });
  });

  group('current', () {
    testWidgets('meta line says when and what it cost; the band is tinted; '
        'Up to date sits beside Update now', (tester) async {
      await pump(
        tester,
        checkIns: onTrackCheckIns,
        current: report(),
        state: agentState(lastWakeAt: now.subtract(const Duration(hours: 1))),
        totalTokens: 38200,
      );

      expect(find.text('as of 1 h ago · 38.2K tokens'), findsOneWidget);
      final chip = tester.widget<DsPill>(
        find.byKey(const ValueKey('relationship-health-chip')),
      );
      final tokens = tester
          .element(find.byType(RelationshipBriefingCard))
          .designTokens;
      expect(chip.label, 'Thriving');
      expect(chip.variant, DsPillVariant.tinted);
      expect(
        chip.color,
        relationshipHealthBandColor(tokens, RelationshipHealthBand.thriving),
      );
      expect(statusText(tester), 'Up to date');
      final update = tester.widget<DesignSystemButton>(briefMe);
      expect(update.label, 'Update now');
      expect(update.variant, DesignSystemButtonVariant.secondary);
    });

    testWidgets('the "as of" line moves on its own once the displayed bucket '
        'changes — a briefing is not "just now" for hours', (tester) async {
      var current = now;
      final written = now.subtract(const Duration(seconds: 58));
      await withClock(Clock(() => current), () async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            RelationshipBriefingCard(
              relationship: relationship(),
              checkIns: onTrackCheckIns,
            ),
            overrides: [
              agentReportProvider(agentId).overrideWith(
                (ref) async => report(createdAt: written),
              ),
              agentStateProvider(agentId).overrideWith((ref) async => null),
              agentIsRunningProvider(
                agentId,
              ).overrideWith((ref) => Stream.value(false)),
              agentIdentityProvider(agentId).overrideWith((ref) async => null),
              taskAgentResolvedSetupProvider(
                agentId,
              ).overrideWith((ref) async => resolvedSetup()),
              agentTokenUsageSummariesProvider(
                agentId,
              ).overrideWith((ref) async => const []),
              relationshipAgentServiceProvider.overrideWithValue(agentService),
              relationshipBriefingDisclosureProvider(
                relationshipId,
              ).overrideWith((ref) async => null),
              relationshipRepositoryProvider.overrideWithValue(repository),
              contactLauncherProvider.overrideWithValue(
                _FakeContactLauncher(launchable: const {}),
              ),
              pendingInteractionStoreProvider.overrideWithValue(store),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('as of just now'), findsOneWidget);

        // Nobody rebuilds the card; the clock crosses the minute.
        current = now.add(const Duration(seconds: 5));
        await tester.pump(const Duration(seconds: 5));

        expect(find.text('as of 1 min ago'), findsOneWidget);
      });
    });

    testWidgets('no cost pill without usage', (tester) async {
      await pump(tester, checkIns: onTrackCheckIns, current: report());

      expect(find.text('as of 1 h ago'), findsOneWidget);
    });

    testWidgets('Update now requests a briefing', (tester) async {
      await pump(tester, checkIns: onTrackCheckIns, current: report());

      await tester.tap(briefMe);
      await tester.pumpAndSettle();

      verify(() => agentService.requestBriefing(any())).called(1);
    });

    testWidgets('renders the briefing as Markdown, and Read more reveals the '
        'full report', (tester) async {
      await pump(tester, checkIns: onTrackCheckIns, current: report());

      expect(find.byType(AgentMarkdownView), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('relationship-briefing-expand')),
      );
      await tester.pumpAndSettle();

      final views = tester
          .widgetList<AgentMarkdownView>(find.byType(AgentMarkdownView))
          .map((v) => v.text)
          .toList();
      expect(views, ['Pip is in good spirits.', 'The **long** version.']);
      expect(find.text('Show less'), findsOneWidget);
    });

    testWidgets('a report with no parseable band shows no chip', (
      tester,
    ) async {
      await pump(
        tester,
        checkIns: onTrackCheckIns,
        current: report(band: null),
      );

      expect(
        find.byKey(const ValueKey('relationship-health-chip')),
        findsNothing,
      );
    });

    testWidgets('tapping the identity opens the internals panel', (
      tester,
    ) async {
      await pump(tester, checkIns: onTrackCheckIns, current: report());

      await tester.tap(find.text('Briefing'));
      await tester.pumpAndSettle();

      expect(find.byType(AgentInternalsPanel), findsOneWidget);
    });
  });

  group('out of date', () {
    testWidgets('names the new check-in in warning tone and offers Update '
        'now as the primary', (tester) async {
      await pump(
        tester,
        checkIns: onTrackCheckIns,
        current: report(),
        state: agentState(staleAt: DateTime(2026, 8, 12, 19, 6)),
      );

      expect(statusText(tester), 'Out of date · new check-in Wed 12 Aug');
      final tokens = tester
          .element(find.byType(RelationshipBriefingCard))
          .designTokens;
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('relationship-agent-status')),
            )
            .style
            ?.color,
        tokens.colors.alert.warning.defaultColor,
      );
      final update = tester.widget<DesignSystemButton>(briefMe);
      expect(update.label, 'Update now');
      expect(update.variant, DesignSystemButtonVariant.primary);
    });
  });

  group('due', () {
    testWidgets('the cadence pill turns warning and the footer offers Log '
        'check-in and Call', (tester) async {
      final launcher = await pump(
        tester,
        entry: relationship(channels: const [mobile]),
        checkIns: lapsedCheckIns,
        current: report(),
      );

      final due = tester.widget<DsPill>(
        find.byKey(const ValueKey('relationship-agent-pill-due')),
      );
      expect(due.label, 'Due since Sat · 5 days over');
      final quiet = tester.widget<DesignSystemButton>(
        find.byKey(const ValueKey('relationship-agent-log-check-in')),
      );
      expect(quiet.label, 'Log check-in');
      expect(quiet.variant, DesignSystemButtonVariant.tertiary);
      expect(find.text('Call Pip'), findsOneWidget);
      expect(briefMe, findsNothing);
      expect(
        find.byKey(const ValueKey('relationship-agent-status')),
        findsNothing,
        reason: 'the due footer is two actions, not a status and an action',
      );

      await tester.tap(find.byKey(const ValueKey('relationship-agent-call')));
      await tester.pumpAndSettle();

      expect(launcher.launched, [(mobile, ContactAction.call)]);
      expect(store.remembered?.relationshipId, relationshipId);
    });

    testWidgets('Log check-in opens the capture sheet for this person', (
      tester,
    ) async {
      setTestSurfaceSize(tester, const Size(1000, 1400));
      await pump(
        tester,
        entry: relationship(channels: const [mobile]),
        checkIns: lapsedCheckIns,
        current: report(),
      );

      await tester.tap(
        find.byKey(const ValueKey('relationship-agent-log-check-in')),
      );
      await tester.pumpAndSettle();

      expect(find.text('How did you connect?'), findsOneWidget);
    });

    testWidgets('without a launchable channel, Log check-in is the primary', (
      tester,
    ) async {
      await pump(tester, checkIns: lapsedCheckIns, current: report());

      expect(find.text('Call Pip'), findsNothing);
      expect(
        find.byKey(const ValueKey('relationship-agent-log-check-in-primary')),
        findsOneWidget,
      );
    });
  });
}
