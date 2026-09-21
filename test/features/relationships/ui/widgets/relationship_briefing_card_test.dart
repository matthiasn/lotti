import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_token_usage.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/agents/ui/task_agent_identity_region.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/agents/ui/widgets/ai_card_chrome.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/model/relationship_health_metrics.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/runtime/relationship_agent_phase_a.dart';
import 'package:lotti/features/relationships/service/contact_launcher.dart';
import 'package:lotti/features/relationships/service/pending_interaction_store.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/features/relationships/state/relationship_proposal_providers.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_briefing_card.dart';
import 'package:lotti/features/relationships/util/contact_channel_uri.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/test_data/ai_config_factories.dart';
import '../../../agents/test_data/change_set_factories.dart';
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
    ValueNotifier<RelationshipEntry>? entryNotifier,
    List<CheckInEntry> checkIns = const [],
    AgentReportEntity? current,
    AgentStateEntity? state,
    bool running = false,
    bool modelResolved = true,
    int totalTokens = 0,
    TextScaler textScaler = TextScaler.noScaling,
    List<Override> additionalOverrides = const [],
    TaskAgentSetupOptions setupOptions = const TaskAgentSetupOptions(
      profiles: [],
      models: [],
      providers: [],
    ),
    Set<ContactAction> launchable = const {ContactAction.call},
  }) async {
    final launcher = _FakeContactLauncher(launchable: launchable);
    await withClock(Clock.fixed(now), () async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          mediaQueryData: MediaQueryData(textScaler: textScaler),
          entryNotifier == null
              ? RelationshipBriefingCard(
                  relationship: entry ?? relationship(),
                  checkIns: checkIns,
                )
              : ValueListenableBuilder<RelationshipEntry>(
                  valueListenable: entryNotifier,
                  builder: (context, value, child) => RelationshipBriefingCard(
                    relationship: value,
                    checkIns: checkIns,
                  ),
                ),
          overrides: [
            agentReportProvider.overrideWith((ref, id) async => current),
            agentStateProvider.overrideWith((ref, id) async => state),
            agentIsRunningProvider.overrideWith(
              (ref, id) => Stream.value(running),
            ),
            agentIdentityProvider.overrideWith(
              (ref, id) async => makeTestIdentity(
                agentId: id,
                kind: AgentKinds.relationshipAgent,
                displayName: 'Commander Pip Frostbeak',
              ),
            ),
            taskAgentResolvedSetupProvider.overrideWith(
              (ref, id) async => modelResolved
                  ? resolvedSetup()
                  : const ResolvedAgentSetup(
                      status: AgentSetupResolutionStatus.disabled,
                    ),
            ),
            agentTokenUsageSummariesProvider.overrideWith(
              (ref, id) async => [
                if (totalTokens > 0)
                  AgentTokenUsageSummary(
                    modelId: 'model-1',
                    inputTokens: totalTokens,
                  ),
              ],
            ),
            taskAgentSetupOptionsProvider.overrideWith(
              (ref) async => setupOptions,
            ),
            relationshipAgentServiceProvider.overrideWithValue(agentService),
            relationshipRepositoryProvider.overrideWithValue(repository),
            contactLauncherProvider.overrideWithValue(launcher),
            pendingInteractionStoreProvider.overrideWithValue(store),
            ...additionalOverrides,
          ],
        ),
      );
      if (running) {
        // The running face wears a spinner, so nothing ever "settles".
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      } else {
        await tester.pumpAndSettle();
      }
    });
    return launcher;
  }

  Text statusWidget(WidgetTester tester) => tester.widget<Text>(
    find.byKey(const ValueKey('relationship-agent-status')),
  );
  // A two-ink status renders as rich text; either way, the words.
  String statusText(WidgetTester tester) {
    final text = statusWidget(tester);
    return text.data ?? text.textSpan!.toPlainText();
  }

  SemanticsNode statusNode(WidgetTester tester) => tester.getSemantics(
    find.byKey(const ValueKey('relationship-agent-status')),
  );
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
      // The band's and the pill's own words for this state, not a second
      // name ("No agent for this person") for the same fact.
      expect(statusText(tester), 'No reminders');
      // The only pills are the interval choice: the status pills live in
      // the header above the card.
      expect(
        tester.widgetList<DsPill>(find.byType(DsPill)).map((p) => p.label),
        ['Weekly', 'Every two weeks', 'Monthly', 'Quarterly'],
      );
      expect(
        find.textContaining('Turn on reminders for Pip'),
        findsOneWidget,
      );
      // Prose in the prose ink, like the enrolled faces.
      final tokens = tester
          .element(find.byType(RelationshipBriefingCard))
          .designTokens;
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('relationship-agent-body')))
            .style
            ?.color,
        tokens.colors.text.highEmphasis,
      );
      // Nothing under the action row: the footer closes symmetric.
      expect(
        tester
            .widget<Container>(
              find.byKey(const ValueKey('relationship-agent-footer')),
            )
            .padding!
            .resolve(TextDirection.ltr)
            .bottom,
        tokens.spacing.step4,
      );
      // One noun for the enrolment axis: the band, the pill and the
      // summary all say *enrolled*, so the control that ends "Not enrolled"
      // says it too rather than naming a second concept ("important") the
      // user has to connect to the first.
      expect(find.text('Remind me about Pip'), findsOneWidget);
      expect(find.text('Mark important'), findsNothing);

      // No privacy caption. It read "Only what you start yourself uses AI"
      // and sat beside the control that starts an agent which wakes on a
      // cadence — an unexplained disclaimer in the one place it is about
      // to stop being true.
      expect(
        find.byKey(const ValueKey('relationship-agent-meta')),
        findsNothing,
      );
      expect(find.textContaining('uses AI'), findsNothing);
    });

    // Codex review on #4346: Brief now starts without asking because this
    // row names the provider (ADR 0061), so no width or text size may shed
    // the provider from it.
    testWidgets('a narrow card at large text still names the provider', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(320, 4000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(
        tester,
        checkIns: onTrackCheckIns,
        current: report(),
        textScaler: const TextScaler.linear(2.5),
      );

      final identity = find.descendant(
        of: find.byType(TaskAgentIdentityRegion),
        matching: find.byType(Text),
      );
      expect(
        tester
            .widgetList<Text>(identity)
            .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
            .first,
        startsWith('Gemini · '),
        reason: 'the narrowest tier leads with the provider',
      );
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

    testWidgets('the one-tap enrol stores the interval the card showed: the '
        'default, preselected, when nothing was picked', (tester) async {
      await pump(
        tester,
        entry: relationship(important: false, cadenceDays: null),
      );

      expect(find.text('How often?'), findsOneWidget);
      expect(
        tester
            .widgetList<DsPill>(find.byType(DsPill))
            .where((pill) => pill.selected)
            .map((pill) => pill.label),
        ['Monthly'],
      );

      await tester.tap(
        find.byKey(const ValueKey('relationship-agent-mark-important')),
      );
      await tester.pumpAndSettle();

      final saved =
          verify(
                () => repository.updateRelationship(captureAny()),
              ).captured.single
              as RelationshipEntry;
      // Stored, not left null for the runtime to substitute unseen.
      expect(saved.data.checkInCadenceDays, relationshipDefaultCadenceDays);
    });

    testWidgets('an interval picked on the card is the one the enrol stores', (
      tester,
    ) async {
      // Opens on the interval this person already had stored.
      await pump(tester, entry: relationship(important: false));
      List<String?> selected() => tester
          .widgetList<DsPill>(find.byType(DsPill))
          .where((pill) => pill.selected)
          .map((pill) => pill.label)
          .toList();
      expect(selected(), ['Weekly']);

      await tester.tap(find.widgetWithText(DsPill, 'Quarterly'));
      await tester.pump();
      expect(selected(), ['Quarterly']);

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
      expect(saved.data.checkInCadenceDays, 90);
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
      // Nothing to turn on, so no interval to choose for it.
      expect(find.text('How often?'), findsNothing);
      expect(find.byType(DsPill), findsNothing);
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
      expect(statusText(tester), 'Agent watching · next look Wed 19 Aug');
      expect(
        find.text(
          'No briefing yet. Brief now writes one from your 2 check-ins; it '
          'never sees the phone number or email.',
        ),
        findsOneWidget,
      );
      expect(find.byType(DsPill), findsNothing);
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
      expect(statusText(tester), startsWith('Agent watching · next look'));
    });

    // Sending to the configured provider is what the app is for; the card's
    // model row already names it. No confirmation, and no toast — the
    // running face's spinner is the acknowledgement.
    testWidgets('Brief now requests at once — no dialog, no toast', (
      tester,
    ) async {
      await pump(tester, checkIns: onTrackCheckIns);

      await tester.tap(briefMe);
      await tester.pumpAndSettle();

      verify(
        () => agentService.requestBriefing(relationship()),
      ).called(1);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      expect(find.textContaining('Briefing requested'), findsNothing);
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
    testWidgets('a first briefing shows only the writing status — with the '
        'activity log to open', (tester) async {
      await pump(
        tester,
        checkIns: onTrackCheckIns,
        running: true,
        state: agentState(lastWakeAt: DateTime(2026, 8, 13, 13, 41)),
      );

      expect(statusText(tester), 'Writing the briefing…');
      // The spinner says it is running; no body guesses how long.
      expect(find.textContaining('Usually under a minute'), findsNothing);
      expect(
        find.byKey(const ValueKey('relationship-agent-body')),
        findsNothing,
      );
      expect(briefMe, findsNothing);
      // The quiet door stays open while the agent writes; nothing primary.
      expect(find.byType(DesignSystemButton), findsOneWidget);
      expect(
        find.byKey(const ValueKey('relationship-agent-see-activity')),
        findsOneWidget,
      );
      // With no primary, the footer still washes the whole card.
      expect(
        tester
            .getSize(find.byKey(const ValueKey('relationship-agent-footer')))
            .width,
        tester
            .getSize(find.byKey(const ValueKey('relationship-briefing-card')))
            .width,
      );
    });

    // An update must not blank the card: the briefing being replaced stays
    // readable under the spinner until the new one lands.
    testWidgets('a refresh keeps the briefing on file in view while it '
        'writes', (tester) async {
      await pump(
        tester,
        checkIns: onTrackCheckIns,
        current: report(),
        running: true,
      );

      expect(statusText(tester), 'Writing the briefing…');
      expect(
        find.byKey(const ValueKey('relationship-briefing-body')),
        findsOneWidget,
      );
      expect(find.textContaining('Pip is in good spirits.'), findsOneWidget);
      expect(find.textContaining('Usually under a minute'), findsNothing);
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

      // A past event in the "as of" grammar: how long ago, not a clock
      // time that reads as an appointment — and the alert ink is the
      // state's alone: the age reads in the meta ink.
      expect(statusText(tester), 'Last run failed · 19 min ago');
      final tokens = tester
          .element(find.byType(RelationshipBriefingCard))
          .designTokens;
      final spans = (statusWidget(tester).textSpan! as TextSpan).children!;
      expect((spans.first as TextSpan).text, 'Last run failed');
      expect((spans.last as TextSpan).text, ' · 19 min ago');
      expect(
        (spans.last as TextSpan).style?.color,
        tokens.colors.aiCard.metaText,
      );
      // Announced as the state, not the age.
      expect(statusNode(tester).flagsCollection.isLiveRegion, isTrue);
      expect(statusNode(tester).label, 'Last run failed');
      expect(
        find.textContaining('No model is set up for briefings.'),
        findsOneWidget,
      );
      expect(find.text('Choose a model'), findsOneWidget);
      expect(find.text('See activity'), findsOneWidget);
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

    testWidgets('a failure with no wake time yet reads plainly', (
      tester,
    ) async {
      await pump(
        tester,
        checkIns: onTrackCheckIns,
        state: agentState(failures: 1),
      );

      expect(
        find.text(
          'The provider returned an error before the briefing was written. '
          'Your check-ins are unchanged.',
        ),
        findsOneWidget,
      );
      expect(statusText(tester), 'Last run failed');
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('See activity opens the internals panel', (tester) async {
      await pump(
        tester,
        checkIns: onTrackCheckIns,
        state: agentState(failures: 1, lastWakeAt: failedAt),
      );

      await tester.tap(
        find.byKey(const ValueKey('relationship-agent-see-activity')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AgentInternalsPanel), findsOneWidget);
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
          'The provider returned an error before the briefing was written. '
          'Your check-ins are unchanged.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      verify(() => agentService.requestBriefing(any())).called(1);
    });
  });

  group('current', () {
    testWidgets('the status line says when and which band; the cost rides '
        'the model row; the sources line closes the card; Log check-in '
        'sits beside a quiet Update now, with no doing verbs', (tester) async {
      await pump(
        tester,
        checkIns: onTrackCheckIns,
        current: report(),
        state: agentState(lastWakeAt: now.subtract(const Duration(hours: 1))),
        totalTokens: 38200,
      );

      expect(statusText(tester), 'Thriving · as of 1 h ago');
      expect(find.byType(DsPill), findsNothing);
      expect(find.textContaining('· 38.2K tokens'), findsOneWidget);
      // Provenance waits behind Read more: collapsed, the summary outweighs
      // its sources. Under the fixed clock: a rebuild on the real one would
      // find the fixture overdue and swap the footer to Call.
      expect(find.textContaining('Sources:'), findsNothing);
      await withClock(Clock.fixed(now), () async {
        await tester.tap(
          find.byKey(const ValueKey('relationship-briefing-expand')),
        );
        await tester.pumpAndSettle();
      });
      expect(
        find.text('Sources: 2 check-ins · contact channels never sent'),
        findsOneWidget,
      );
      // The footer carries the agent's verbs and only those. Logging a
      // check-in is the page's verb and lives on the sticky action bar, so
      // offering it here too put the same action on screen twice — loud in
      // one place, quiet in the other, primary in neither.
      final quiet = tester.widget<DesignSystemButton>(
        find.byKey(const ValueKey('relationship-agent-see-activity')),
      );
      expect(quiet.label, 'See activity');
      expect(quiet.variant, DesignSystemButtonVariant.tertiary);
      // …and it is the card's one worded door to the agent's internals:
      // "Open agent internals" beside Read more was a third way to the
      // same place, collapsed or expanded.
      expect(find.text('Open agent internals'), findsNothing);
      expect(
        find.byKey(const ValueKey('relationship-agent-log-check-in')),
        findsNothing,
      );
      final update = tester.widget<DesignSystemButton>(briefMe);
      expect(update.label, 'Update now');
      // Tertiary on a current briefing: the card's offer is the reading,
      // not the rewrite. Accent is reserved for the faces that actually
      // need regenerating (out of date, failed).
      expect(update.variant, DesignSystemButtonVariant.tertiary);
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
              relationshipRepositoryProvider.overrideWithValue(repository),
              contactLauncherProvider.overrideWithValue(
                _FakeContactLauncher(launchable: const {}),
              ),
              pendingInteractionStoreProvider.overrideWithValue(store),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(statusText(tester), 'Thriving · as of just now');
        // A resting age is not news: the line is not a live region here.
        expect(statusNode(tester).flagsCollection.isLiveRegion, isFalse);

        // Nobody rebuilds the card; the clock crosses the minute.
        current = now.add(const Duration(seconds: 5));
        await tester.pump(const Duration(seconds: 5));

        expect(statusText(tester), 'Thriving · as of 1 min ago');
      });
    });

    // The age tick is armed from `build`, and this card's build watches six
    // providers — an agent tick, a token-usage update, an identity arriving
    // all re-arm it. The churn has to stop before the boundary for this to
    // test anything: while the card is rebuilding, the line is re-read from
    // the clock on every build and would look right even with a dead timer.
    // So it rebuilds, then goes quiet, and the boundary is crossed with
    // nothing but the timer left to move it.
    testWidgets('a card that has been rebuilding still ages once it goes '
        'quiet', (tester) async {
      var current = now;
      final written = now.subtract(const Duration(seconds: 30));
      final entry = ValueNotifier<RelationshipEntry>(relationship());
      addTearDown(entry.dispose);
      await withClock(Clock(() => current), () async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ValueListenableBuilder<RelationshipEntry>(
              valueListenable: entry,
              builder: (context, value, child) => RelationshipBriefingCard(
                relationship: value,
                checkIns: onTrackCheckIns,
              ),
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
              relationshipRepositoryProvider.overrideWithValue(repository),
              contactLauncherProvider.overrideWithValue(
                _FakeContactLauncher(launchable: const {}),
              ),
              pendingInteractionStoreProvider.overrideWithValue(store),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(statusText(tester), 'Thriving · as of just now');

        // Five rebuilds, each one passing through the arming code.
        for (var second = 1; second <= 5; second++) {
          current = now.add(Duration(seconds: second));
          entry.value = relationship(cadenceDays: 7 + second);
          await tester.pump(const Duration(seconds: 1));
        }
        expect(statusText(tester), 'Thriving · as of just now');

        // Now nothing rebuilds it, and the age crosses a minute. Only the
        // armed timer can move the line.
        current = now.add(const Duration(seconds: 31));
        await tester.pump(const Duration(seconds: 26));

        expect(
          statusText(tester),
          'Thriving · as of 1 min ago',
          reason:
              'the tick a rebuilding card armed still fires on the '
              'boundary, rather than being pushed a whole bucket out',
        );
      });
    });

    testWidgets('a briefing finishing is announced as it arrives, and the '
        'age ticking afterwards is not', (tester) async {
      var current = now;
      final running = StreamController<bool>();
      addTearDown(running.close);
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
              ).overrideWith((ref) => running.stream),
              agentIdentityProvider(agentId).overrideWith((ref) async => null),
              taskAgentResolvedSetupProvider(
                agentId,
              ).overrideWith((ref) async => resolvedSetup()),
              agentTokenUsageSummariesProvider(
                agentId,
              ).overrideWith((ref) async => const []),
              relationshipAgentServiceProvider.overrideWithValue(agentService),
              relationshipRepositoryProvider.overrideWithValue(repository),
              contactLauncherProvider.overrideWithValue(
                _FakeContactLauncher(launchable: const {}),
              ),
              pendingInteractionStoreProvider.overrideWithValue(store),
            ],
          ),
        );
        running.add(true);
        await tester.pump();
        await tester.pump();
        expect(statusText(tester), 'Writing the briefing…');
        expect(statusNode(tester).flagsCollection.isLiveRegion, isTrue);

        // The run finishes: the current face arrives, and that is news.
        running.add(false);
        await tester.pump();
        await tester.pump();
        expect(statusText(tester), 'Thriving · as of just now');
        expect(statusNode(tester).flagsCollection.isLiveRegion, isTrue);

        // The age ticks over on its own: the same face, not news.
        current = now.add(const Duration(seconds: 5));
        await tester.pump(const Duration(seconds: 5));
        expect(statusText(tester), 'Thriving · as of 1 min ago');
        expect(statusNode(tester).flagsCollection.isLiveRegion, isFalse);
      });
    });

    testWidgets('the failed face ages from its last wake, not from a '
        'briefing it does not have', (tester) async {
      var current = now;
      final failedAt = now.subtract(const Duration(seconds: 58));
      await withClock(Clock(() => current), () async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            RelationshipBriefingCard(
              relationship: relationship(),
              checkIns: onTrackCheckIns,
            ),
            overrides: [
              agentReportProvider(agentId).overrideWith((ref) async => null),
              agentStateProvider(agentId).overrideWith(
                (ref) async => agentState(failures: 1, lastWakeAt: failedAt),
              ),
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
              relationshipRepositoryProvider.overrideWithValue(repository),
              contactLauncherProvider.overrideWithValue(
                _FakeContactLauncher(launchable: const {}),
              ),
              pendingInteractionStoreProvider.overrideWithValue(store),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(statusText(tester), 'Last run failed · just now');

        current = now.add(const Duration(seconds: 5));
        await tester.pump(const Duration(seconds: 5));
        expect(statusText(tester), 'Last run failed · 1 min ago');
      });
    });

    testWidgets('the footer keeps a designed gap between its actions and the '
        'model row, at every text size', (tester) async {
      for (final scale in [1.0, 1.6]) {
        await pump(
          tester,
          checkIns: onTrackCheckIns,
          current: report(),
          textScaler: TextScaler.linear(scale),
        );
        final tokens = tester
            .element(find.byType(RelationshipBriefingCard))
            .designTokens;
        final action = tester.getRect(briefMe);
        final identity = tester.getRect(find.byType(TaskAgentIdentityRegion));
        expect(
          identity.top - action.bottom,
          greaterThanOrEqualTo(tokens.spacing.step3),
          reason: 'scale $scale: the primary must not touch the model row',
        );
      }
    });

    // The contract requires a rationale, the workflow stores it, and
    // nothing rendered it: the verdict on a person was unfalsifiable by
    // inspection. "Why does it say that about her?" is the question a
    // briefing has to be able to answer.
    testWidgets('the band says why, in the words the briefing wrote', (
      tester,
    ) async {
      await pump(tester, checkIns: onTrackCheckIns, current: report());

      final rationale = find.byKey(
        const ValueKey('relationship-agent-band-rationale'),
      );
      expect(rationale, findsOneWidget);
      expect(tester.widget<Text>(rationale).data, 'Two good calls in a row.');
    });

    testWidgets('an essay cannot push the briefing off the card', (
      tester,
    ) async {
      await pump(tester, checkIns: onTrackCheckIns, current: report());

      expect(
        tester
            .widget<Text>(
              find.byKey(
                const ValueKey('relationship-agent-band-rationale'),
              ),
            )
            .maxLines,
        3,
      );
    });

    testWidgets('a briefing with no band says nothing about one', (
      tester,
    ) async {
      await pump(
        tester,
        checkIns: onTrackCheckIns,
        current: report(band: null),
      );

      expect(
        find.byKey(const ValueKey('relationship-agent-band-rationale')),
        findsNothing,
        reason: 'no verdict, nothing to justify',
      );
    });

    // Out of date, the status line drops the band for the warning — so the
    // sentence explaining that band would be explaining something no
    // longer on screen.
    testWidgets('an out-of-date briefing drops it with the band', (
      tester,
    ) async {
      await pump(
        tester,
        checkIns: onTrackCheckIns,
        current: report(),
        state: agentState(staleAt: DateTime(2026, 8, 12, 19, 6)),
      );

      expect(
        find.byKey(const ValueKey('relationship-agent-band-rationale')),
        findsNothing,
      );
    });

    testWidgets('the band wears its colour as a dot beside its word, centred '
        'on the first line', (tester) async {
      await pump(tester, checkIns: onTrackCheckIns, current: report());
      final dotFinder = find.byKey(
        const ValueKey('relationship-agent-band-dot'),
      );
      // The design system's own presence dot, in the band's tone.
      final dot = tester.widget<DesignSystemBadge>(dotFinder);
      final tokens = tester
          .element(find.byType(RelationshipBriefingCard))
          .designTokens;
      expect(dot.tone, DesignSystemBadgeTone.success);
      expect(
        relationshipHealthBandTone(RelationshipHealthBand.steady),
        DesignSystemBadgeTone.neutral,
      );
      // The dot's offset is the text line less the dot, halved — computed,
      // not a fixed step, so it scales with the text.
      final line = tokens.typography.styles.body.bodySmall;
      final offset = tester
          .widget<Padding>(
            find.ancestor(of: dotFinder, matching: find.byType(Padding)).first,
          )
          .padding
          .resolve(TextDirection.ltr)
          .top;
      expect(
        offset,
        (line.fontSize! * line.height! - tokens.spacing.step3) / 2,
      );
    });

    testWidgets('with nothing to expand, the sources line is not hidden '
        'behind a Read more that does not exist', (tester) async {
      await pump(
        tester,
        checkIns: onTrackCheckIns,
        current: report(tldr: null),
      );
      expect(
        find.byKey(const ValueKey('relationship-briefing-expand')),
        findsNothing,
      );
      expect(
        find.text('Sources: 2 check-ins · contact channels never sent'),
        findsOneWidget,
      );
    });

    testWidgets('no cost on the model row without usage', (tester) async {
      await pump(tester, checkIns: onTrackCheckIns, current: report());

      expect(statusText(tester), 'Thriving · as of 1 h ago');
      expect(find.textContaining('tokens'), findsNothing);
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

    testWidgets('every band reads as its own label on the status line', (
      tester,
    ) async {
      const bands = {
        'steady': RelationshipHealthBand.steady,
        'needsAttention': RelationshipHealthBand.needsAttention,
        'strained': RelationshipHealthBand.strained,
      };
      for (final entry in bands.entries) {
        await pump(
          tester,
          checkIns: onTrackCheckIns,
          current: report(band: entry.key),
        );
        final context = tester.element(find.byType(RelationshipBriefingCard));
        expect(
          statusText(tester),
          '${relationshipHealthBandLabel(context, entry.value)} · as of 1 h ago',
          reason: entry.key,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('a report with no parseable band says only when', (
      tester,
    ) async {
      await pump(
        tester,
        checkIns: onTrackCheckIns,
        current: report(band: null),
      );

      expect(statusText(tester), 'as of 1 h ago');
    });

    testWidgets('open proposals are counted once — by the band, not the '
        'header too', (tester) async {
      final set = makeTestChangeSet(
        agentId: agentId,
        taskId: relationshipId,
        items: const [
          ChangeItem(
            toolName: 'create_and_link_task',
            args: {'title': 'Send the draft'},
            humanSummary: 'Create task: Send the draft',
          ),
          ChangeItem(
            toolName: 'create_and_link_task',
            args: {'title': 'Book the walkthrough'},
            humanSummary: 'Create task: Book the walkthrough',
          ),
        ],
      );
      await pump(
        tester,
        checkIns: onTrackCheckIns,
        current: report(),
        additionalOverrides: [
          relationshipSuggestionListProvider(relationshipId).overrideWith(
            (ref) async => RelationshipProposalSnapshot(
              suggestions: UnifiedSuggestionList(
                open: [
                  for (var i = 0; i < set.items.length; i++)
                    PendingSuggestion(
                      changeSet: set,
                      itemIndex: i,
                      item: set.items[i],
                      fingerprint: ChangeItem.fingerprint(set.items[i]),
                    ),
                ],
                activity: const [],
              ),
            ),
          ),
        ],
      );

      expect(
        find.byKey(const ValueKey('relationship-briefing-proposals')),
        findsNothing,
      );
      expect(find.text('2 pending'), findsOneWidget);
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
        tokens.colors.alert.warning.ink,
      );
      final update = tester.widget<DesignSystemButton>(briefMe);
      expect(update.label, 'Update now');
      expect(update.variant, DesignSystemButtonVariant.primary);
      expect(
        find.byKey(const ValueKey('relationship-briefing-age')),
        findsNothing,
        reason: 'an hour-old briefing is not old enough to count in days',
      );
      expect(
        find.textContaining('Sources:'),
        findsNothing,
        reason: 'the count would include the check-in the briefing missed',
      );
    });

    testWidgets('a briefing days old wears its age on the trailing rail', (
      tester,
    ) async {
      await pump(
        tester,
        checkIns: onTrackCheckIns,
        current: report(createdAt: now.subtract(const Duration(days: 6))),
        state: agentState(staleAt: DateTime(2026, 8, 12, 19, 6)),
      );

      expect(
        tester
            .widget<DsPill>(
              find.byKey(const ValueKey('relationship-briefing-age')),
            )
            .label,
        '6 days old',
      );
    });
  });

  group('out of date without a check-in on file', () {
    testWidgets('says only that it is out of date', (tester) async {
      await pump(
        tester,
        current: report(),
        state: agentState(staleAt: DateTime(2026, 8, 13, 13)),
      );

      expect(statusText(tester), 'Out of date');
    });
  });

  group('due', () {
    testWidgets('being overdue does not change who owns the doing verbs: '
        'the footer stays See activity · Update now', (tester) async {
      await pump(
        tester,
        entry: relationship(channels: const [mobile]),
        checkIns: lapsedCheckIns,
        current: report(),
      );

      // A lapsed cadence changes what the sticky bar's primary is *for*,
      // not who owns it. The card used to answer it with its own filled
      // "Call Pip" beside the bar's filled "Log check-in" — two teal
      // primaries for two different acts in one viewport.
      expect(find.text('Call Pip'), findsNothing);
      expect(
        find.byKey(const ValueKey('relationship-agent-call')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('relationship-agent-log-check-in')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('relationship-agent-log-check-in-primary')),
        findsNothing,
      );

      final quiet = tester.widget<DesignSystemButton>(
        find.byKey(const ValueKey('relationship-agent-see-activity')),
      );
      expect(quiet.variant, DesignSystemButtonVariant.tertiary);
      expect(tester.widget<DesignSystemButton>(briefMe).label, 'Update now');
      expect(
        statusText(tester),
        'Thriving · as of 1 h ago',
        reason: 'the status stays in the header',
      );
    });
  });
}
