import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/daily_token_usage.dart';
import 'package:lotti/features/agents/model/pending_wake_record.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/features/agents/state/soul_query_providers.dart';
import 'package:lotti/features/agents/state/token_stats_providers.dart';
import 'package:lotti/features/agents/ui/agent_instances_list.dart';
import 'package:lotti/features/agents/ui/agent_palette.dart';
import 'package:lotti/features/agents/ui/agent_settings_page.dart';
import 'package:lotti/features/agents/ui/instances/instance_view_model.dart';
import 'package:lotti/features/agents/ui/listing/widgets/soul_avatar.dart';
import 'package:lotti/features/agents/ui/pending_wakes/agent_pending_wakes_page.dart';
import 'package:lotti/features/agents/ui/token_stats_tab.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../test_utils.dart';

List<InstanceVm> _makeInstanceVms({
  required List<AgentDomainEntity> agents,
  required List<AgentDomainEntity> evolutions,
}) {
  final rows = <InstanceVm>[];
  for (final entity in agents.whereType<AgentIdentityEntity>()) {
    final type = instanceTypeFromAgentKind(entity.kind);
    if (type == null) {
      continue;
    }

    rows.add(
      InstanceVm(
        id: entity.agentId,
        displayName: entity.displayName,
        type: type,
        status: entity.lifecycle,
        updatedAt: entity.updatedAt,
        searchKey: [entity.displayName, entity.agentId].join(' '),
      ),
    );
  }

  for (final entity in evolutions.whereType<EvolutionSessionEntity>()) {
    rows.add(
      InstanceVm(
        id: entity.id,
        displayName: '',
        sessionNumber: entity.sessionNumber,
        type: InstanceType.evolution,
        status: switch (entity.status) {
          EvolutionSessionStatus.active => AgentLifecycle.active,
          EvolutionSessionStatus.completed => AgentLifecycle.dormant,
          EvolutionSessionStatus.abandoned => AgentLifecycle.destroyed,
        },
        updatedAt: entity.updatedAt,
        templateId: entity.templateId,
        searchKey: 'evolution ${entity.sessionNumber} ${entity.id}',
      ),
    );
  }

  return rows;
}

void main() {
  setUp(() async {
    await setUpTestGetIt();
  });
  tearDown(() async {
    beamToNamedOverride = null;
    await tearDownTestGetIt();
  });

  List<Override> buildOverrides({
    List<AgentDomainEntity> templates = const [],
    List<AgentDomainEntity> souls = const [],
    List<AgentDomainEntity> agents = const [],
    List<AgentDomainEntity> evolutions = const [],
    List<PendingWakeRecord> pendingWakes = const [],
    Map<String, String?> subjectTitles = const {},
    List<Override> extraOverrides = const [],
  }) {
    return [
      agentTemplatesProvider.overrideWith(
        (ref) async => templates,
      ),
      activeTemplateVersionProvider.overrideWith(
        (ref, templateId) async => makeTestTemplateVersion(
          agentId: templateId,
        ),
      ),
      allSoulDocumentsProvider.overrideWith(
        (ref) async => souls,
      ),
      activeSoulVersionProvider.overrideWith(
        (ref, soulId) async => makeTestSoulDocumentVersion(
          agentId: soulId,
        ),
      ),
      allAgentInstancesProvider.overrideWith(
        (ref) async => agents,
      ),
      allEvolutionSessionsProvider.overrideWith(
        (ref) async => evolutions,
      ),
      agentInstanceVmsProvider.overrideWith(
        (ref) async => _makeInstanceVms(
          agents: agents,
          evolutions: evolutions,
        ),
      ),
      agentIsRunningProvider.overrideWith(
        (ref, agentId) => Stream.value(false),
      ),
      templateForAgentProvider.overrideWith(
        (ref, agentId) async => null,
      ),
      pendingWakeRecordsProvider.overrideWith(
        (ref) async => pendingWakes,
      ),
      pendingWakeTargetTitleProvider.overrideWith(
        (ref, String? entryId) async => subjectTitles[entryId],
      ),
      hourlyWakeActivityProvider.overrideWith((ref) async => const []),
      dailyTokenUsageProvider.overrideWith(
        (ref, days) async => const <DailyTokenUsage>[],
      ),
      tokenUsageComparisonProvider.overrideWith(
        (ref, days) async => const TokenUsageComparison(
          averageTokensByTimeOfDay: 0,
          todayTokens: 0,
        ),
      ),
      dailyTokenUsageByModelProvider.overrideWith(
        (ref, days) async => const <String, List<DailyTokenUsage>>{},
      ),
      tokenSourceBreakdownProvider.overrideWith(
        (ref) async => const <TokenSourceBreakdown>[],
      ),
      ...extraOverrides,
    ];
  }

  Widget buildSubject({
    List<AgentDomainEntity> templates = const [],
    List<AgentDomainEntity> souls = const [],
    List<AgentDomainEntity> agents = const [],
    List<AgentDomainEntity> evolutions = const [],
    List<PendingWakeRecord> pendingWakes = const [],
    Map<String, String?> subjectTitles = const {},
    List<Override> extraOverrides = const [],
  }) {
    return makeTestableWidgetNoScroll(
      const AgentSettingsPage(),
      theme: DesignSystemTheme.light(),
      overrides: buildOverrides(
        templates: templates,
        souls: souls,
        agents: agents,
        evolutions: evolutions,
        pendingWakes: pendingWakes,
        subjectTitles: subjectTitles,
        extraOverrides: extraOverrides,
      ),
    );
  }

  group('AgentSettingsPage', () {
    testWidgets('shows Stats tab by default', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSettingsPage));
      expect(
        find.text(context.messages.agentStatsTabTitle),
        findsOneWidget,
      );
      // TokenStatsTab must be on-stage (active), not just mounted offstage.
      expect(find.byType(TokenStatsTab), findsOneWidget);
      // The daily usage heading is unique to the Stats tab content.
      expect(
        find.text(context.messages.agentStatsDailyUsageHeading),
        findsOneWidget,
      );
    });

    testWidgets(
      'AppBar title says "Agent Instances" only on the Instances tab',
      (tester) async {
        final agent = makeTestIdentity(
          id: 'agent-a',
          agentId: 'agent-a',
          displayName: 'Worker Agent',
        );

        await tester.pumpWidget(buildSubject(agents: [agent]));
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(AgentSettingsPage));
        // Stats tab → generic "Agents" title.
        expect(find.text(context.messages.agentSettingsTitle), findsOneWidget);
        expect(
          find.text(context.messages.agentInstancesPageTitle),
          findsNothing,
        );

        await tester.tap(find.text(context.messages.agentInstancesTitle));
        await tester.pumpAndSettle();

        // Instances tab → "Agent Instances" in the AppBar.
        expect(
          find.text(context.messages.agentInstancesPageTitle),
          findsOneWidget,
        );
      },
    );

    testWidgets('switches to Templates tab and shows template cards', (
      tester,
    ) async {
      final laura = makeTestTemplate(
        id: 'tpl-laura',
        agentId: 'tpl-laura',
        displayName: 'Laura',
      );
      final tom = makeTestTemplate(
        id: 'tpl-tom',
        agentId: 'tpl-tom',
        displayName: 'Tom',
      );

      await tester.pumpWidget(
        buildSubject(templates: [laura, tom]),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSettingsPage));
      await tester.tap(find.text(context.messages.agentTemplatesTitle));
      await tester.pumpAndSettle();

      // Title + subtitle are rendered together via `Text.rich`, so the
      // text widget's plain text is `'Laura  ·  models/gemini-3-flash-preview'`.
      // Match through the rich span.
      expect(
        find.textContaining('Laura', findRichText: true),
        findsAtLeast(1),
      );
      expect(
        find.textContaining('Tom', findRichText: true),
        findsAtLeast(1),
      );
    });

    testWidgets('shows empty state when no templates', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSettingsPage));
      await tester.tap(find.text(context.messages.agentTemplatesTitle));
      await tester.pumpAndSettle();

      expect(
        find.text(context.messages.agentTemplatesEmptyFiltered),
        findsOneWidget,
      );
    });

    testWidgets('switches to Instances tab and shows agent cards', (
      tester,
    ) async {
      final agent = makeTestIdentity(
        id: 'agent-a',
        agentId: 'agent-a',
        displayName: 'Worker Agent',
      );

      await tester.pumpWidget(
        buildSubject(agents: [agent]),
      );
      await tester.pumpAndSettle();

      // Tap on Instances tab
      final context = tester.element(find.byType(AgentSettingsPage));
      await tester.tap(find.text(context.messages.agentInstancesTitle));
      await tester.pumpAndSettle();

      expect(find.text('Worker Agent'), findsOneWidget);
    });

    testWidgets('shows Pending Wakes tab badge and wake cards', (tester) async {
      final wake = PendingWakeRecord(
        agent: makeTestIdentity(
          agentId: 'agent-wake',
          displayName: 'Wake Watcher',
        ),
        state: makeTestState(
          agentId: 'agent-wake',
          slots: const AgentSlots(activeTaskId: 'task-1'),
          nextWakeAt: kAgentTestDate.add(const Duration(minutes: 10)),
        ),
        type: PendingWakeType.pending,
        dueAt: kAgentTestDate.add(const Duration(minutes: 10)),
      );

      await tester.pumpWidget(
        buildSubject(
          pendingWakes: [wake],
          subjectTitles: const {'task-1': 'Wake dashboard polish'},
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSettingsPage));
      expect(
        find.text(context.messages.agentPendingWakesTitle),
        findsOneWidget,
      );
      expect(find.text('1'), findsOneWidget);

      await tester.tap(find.text(context.messages.agentPendingWakesTitle));
      await tester.pumpAndSettle();

      // Subject title + agent display name share a single Text.rich
      // in the shared row, so use `findRichText: true` to match through it.
      expect(
        find.textContaining('Wake dashboard polish', findRichText: true),
        findsAtLeast(1),
      );
      // The new shared row uses an hourglass icon for "pending" wakes,
      // sourced from `_PendingWakeTrailing`'s leading.
      expect(find.byIcon(Icons.hourglass_bottom_rounded), findsOneWidget);
    });

    testWidgets('keeps all tab bodies mounted in an IndexedStack', (
      tester,
    ) async {
      final agent = makeTestIdentity(
        agentId: 'agent-a',
        displayName: 'Worker Agent',
      );
      final wake = PendingWakeRecord(
        agent: makeTestIdentity(
          agentId: 'agent-wake',
          displayName: 'Wake Watcher',
        ),
        state: makeTestState(
          agentId: 'agent-wake',
          nextWakeAt: kAgentTestDate.add(const Duration(minutes: 10)),
        ),
        type: PendingWakeType.pending,
        dueAt: kAgentTestDate.add(const Duration(minutes: 10)),
      );

      await tester.pumpWidget(
        buildSubject(
          agents: [agent],
          pendingWakes: [wake],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(IndexedStack), findsOneWidget);
      expect(
        find.byType(AgentInstancesList, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.byType(AgentPendingWakesPage, skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('instances tab shows evolution sessions', (tester) async {
      final session = makeTestEvolutionSession(
        id: 'evo-001',
        sessionNumber: 3,
      );

      await tester.pumpWidget(
        buildSubject(evolutions: [session]),
      );
      await tester.pumpAndSettle();

      // Switch to Instances tab
      final context = tester.element(find.byType(AgentSettingsPage));
      await tester.tap(find.text(context.messages.agentInstancesTitle));
      await tester.pumpAndSettle();

      expect(
        find.text(context.messages.agentEvolutionSessionTitle(3)),
        findsOneWidget,
      );
    });

    testWidgets('template card shows kind badge and model ID', (tester) async {
      final template = makeTestTemplate(
        id: 'tpl-1',
        agentId: 'tpl-1',
        displayName: 'My Template',
      );

      await tester.pumpWidget(
        buildSubject(templates: [template]),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSettingsPage));
      await tester.tap(find.text(context.messages.agentTemplatesTitle));
      await tester.pumpAndSettle();

      expect(
        find.text(context.messages.agentTemplateKindTaskAgent),
        findsOneWidget,
      );
      // Model id renders inside the row's `Text.rich` (title · model).
      expect(
        find.textContaining(
          'models/gemini-3-flash-preview',
          findRichText: true,
        ),
        findsAtLeast(1),
      );
    });

    testWidgets('shows templateImprover kind badge', (tester) async {
      final improverTemplate = makeTestTemplate(
        id: 'tpl-improver',
        agentId: 'tpl-improver',
        displayName: 'Improver',
        kind: AgentTemplateKind.templateImprover,
      );

      await tester.pumpWidget(
        buildSubject(templates: [improverTemplate]),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSettingsPage));
      await tester.tap(find.text(context.messages.agentTemplatesTitle));
      await tester.pumpAndSettle();

      expect(
        find.text(context.messages.agentTemplateKindImprover),
        findsOneWidget,
      );
    });

    testWidgets('has FAB for creating templates', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSettingsPage));
      await tester.tap(find.text(context.messages.agentTemplatesTitle));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });

    testWidgets('shows error state when templates fail to load', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const AgentSettingsPage(),
          theme: DesignSystemTheme.light(),
          overrides: [
            agentTemplatesProvider.overrideWith(
              (ref) async => throw Exception('load failed'),
            ),
            activeTemplateVersionProvider.overrideWith(
              (ref, templateId) async => null,
            ),
            allAgentInstancesProvider.overrideWith(
              (ref) async => <AgentDomainEntity>[],
            ),
            allEvolutionSessionsProvider.overrideWith(
              (ref) async => <AgentDomainEntity>[],
            ),
            agentIsRunningProvider.overrideWith(
              (ref, agentId) => Stream.value(false),
            ),
            templateForAgentProvider.overrideWith(
              (ref, agentId) async => null,
            ),
            pendingWakeRecordsProvider.overrideWith(
              (ref) async => const <PendingWakeRecord>[],
            ),
            hourlyWakeActivityProvider.overrideWith(
              (ref) async => const [],
            ),
            dailyTokenUsageProvider.overrideWith(
              (ref, days) async => const <DailyTokenUsage>[],
            ),
            tokenUsageComparisonProvider.overrideWith(
              (ref, days) async => const TokenUsageComparison(
                averageTokensByTimeOfDay: 0,
                todayTokens: 0,
              ),
            ),
            dailyTokenUsageByModelProvider.overrideWith(
              (ref, days) async => const <String, List<DailyTokenUsage>>{},
            ),
            tokenSourceBreakdownProvider.overrideWith(
              (ref) async => const <TokenSourceBreakdown>[],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSettingsPage));
      await tester.tap(find.text(context.messages.agentTemplatesTitle));
      await tester.pumpAndSettle();

      expect(
        find.text(context.messages.commonError),
        findsOneWidget,
      );
    });

    testWidgets('shows version number on template card', (tester) async {
      final template = makeTestTemplate(
        id: 'tpl-ver',
        agentId: 'tpl-ver',
        displayName: 'Versioned Template',
      );

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const AgentSettingsPage(),
          theme: DesignSystemTheme.light(),
          overrides: [
            agentTemplatesProvider.overrideWith(
              (ref) async => [template],
            ),
            activeTemplateVersionProvider.overrideWith(
              (ref, templateId) async => makeTestTemplateVersion(
                agentId: templateId,
                version: 3,
              ),
            ),
            allAgentInstancesProvider.overrideWith(
              (ref) async => <AgentDomainEntity>[],
            ),
            allEvolutionSessionsProvider.overrideWith(
              (ref) async => <AgentDomainEntity>[],
            ),
            agentIsRunningProvider.overrideWith(
              (ref, agentId) => Stream.value(false),
            ),
            templateForAgentProvider.overrideWith(
              (ref, agentId) async => null,
            ),
            pendingWakeRecordsProvider.overrideWith(
              (ref) async => const <PendingWakeRecord>[],
            ),
            hourlyWakeActivityProvider.overrideWith(
              (ref) async => const [],
            ),
            dailyTokenUsageProvider.overrideWith(
              (ref, days) async => const <DailyTokenUsage>[],
            ),
            tokenUsageComparisonProvider.overrideWith(
              (ref, days) async => const TokenUsageComparison(
                averageTokensByTimeOfDay: 0,
                todayTokens: 0,
              ),
            ),
            dailyTokenUsageByModelProvider.overrideWith(
              (ref, days) async => const <String, List<DailyTokenUsage>>{},
            ),
            tokenSourceBreakdownProvider.overrideWith(
              (ref) async => const <TokenSourceBreakdown>[],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSettingsPage));
      await tester.tap(find.text(context.messages.agentTemplatesTitle));
      await tester.pumpAndSettle();

      // The new shared listing renders the active version as a compact
      // mono cell ("v3") in the row's metaRight slot, not the legacy
      // "Version 3" label.
      expect(find.text('v3'), findsOneWidget);
    });

    testWidgets('tapping FAB navigates to template creation', (tester) async {
      String? navigatedPath;
      beamToNamedOverride = (path) => navigatedPath = path;

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSettingsPage));
      await tester.tap(find.text(context.messages.agentTemplatesTitle));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_rounded));

      expect(navigatedPath, '/settings/agents/templates/create');
    });

    testWidgets('tapping template card navigates to template detail', (
      tester,
    ) async {
      String? navigatedPath;
      beamToNamedOverride = (path) => navigatedPath = path;

      final template = makeTestTemplate(
        id: 'tpl-nav',
        agentId: 'tpl-nav',
        displayName: 'Nav Template',
      );

      await tester.pumpWidget(buildSubject(templates: [template]));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSettingsPage));
      await tester.tap(find.text(context.messages.agentTemplatesTitle));
      await tester.pumpAndSettle();

      await tester.tap(
        find.textContaining('Nav Template', findRichText: true),
      );
      expect(navigatedPath, '/settings/agents/templates/tpl-nav');
    });

    // The new shared listing replaces the legacy Stack(Icon + purple
    // circle) with a leading Icon whose color flips to AgentPalette.purple
    // when the template is in `templatesPendingReviewProvider`'s set.
    // This finder counts those purple icons.
    Finder pendingPurpleIcon() => find.byWidgetPredicate(
      (w) => w is Icon && w.color == AgentPalette.purple,
    );

    for (final (label, pendingIds, expectVisible) in [
      ('visible when pending', {'tpl-dot'}, true),
      ('absent when not pending', <String>{}, false),
    ]) {
      testWidgets('pending dot is $label', (tester) async {
        final template = makeTestTemplate(
          id: 'tpl-dot',
          agentId: 'tpl-dot',
          displayName: 'Dot Template',
        );

        await tester.pumpWidget(
          buildSubject(
            templates: [template],
            extraOverrides: [
              templatesPendingReviewProvider.overrideWith(
                (ref) async => pendingIds,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(AgentSettingsPage));
        await tester.tap(find.text(context.messages.agentTemplatesTitle));
        await tester.pumpAndSettle();

        if (expectVisible) {
          expect(pendingPurpleIcon(), findsOneWidget);
        } else {
          expect(pendingPurpleIcon(), findsNothing);
        }
      });
    }

    testWidgets('switches to Souls tab and shows soul cards', (
      tester,
    ) async {
      final soul = makeTestSoulDocument(
        id: 'soul-laura',
        displayName: 'Laura Soul',
      );

      await tester.pumpWidget(
        buildSubject(souls: [soul]),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSettingsPage));
      await tester.tap(find.text(context.messages.agentSoulsTitle));
      await tester.pumpAndSettle();

      expect(find.text('Laura Soul'), findsOneWidget);
      // Souls list now renders the shared `SoulAvatar` initial-tile
      // instead of the legacy psychology icon.
      expect(find.byType(SoulAvatar), findsOneWidget);
    });

    testWidgets('shows empty state on Souls tab when no souls', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSettingsPage));
      await tester.tap(find.text(context.messages.agentSoulsTitle));
      await tester.pumpAndSettle();

      expect(
        find.text(context.messages.agentSoulsEmptyFiltered),
        findsOneWidget,
      );
    });

    testWidgets('shows FAB on Souls tab for creating souls', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSettingsPage));
      await tester.tap(find.text(context.messages.agentSoulsTitle));
      await tester.pumpAndSettle();

      // The DesignSystemFloatingActionButton exposes the per-tab label
      // through its `semanticLabel` (used by both screen readers and
      // hover tooltips), not via a Material `Tooltip` widget.
      final fab = tester.widget<DesignSystemFloatingActionButton>(
        find.byType(DesignSystemFloatingActionButton),
      );
      expect(fab.semanticLabel, context.messages.agentSoulCreateTitle);
      expect(
        find.byType(DesignSystemBottomNavigationFabPadding),
        findsOneWidget,
      );
    });

    testWidgets('tapping FAB on Souls tab navigates to soul creation', (
      tester,
    ) async {
      String? navigatedPath;
      beamToNamedOverride = (path) => navigatedPath = path;

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSettingsPage));
      await tester.tap(find.text(context.messages.agentSoulsTitle));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_rounded));

      expect(navigatedPath, '/settings/agents/souls/create');
    });

    testWidgets('tapping soul card navigates to soul detail', (tester) async {
      String? navigatedPath;
      beamToNamedOverride = (path) => navigatedPath = path;

      final soul = makeTestSoulDocument(
        id: 'soul-nav',
        displayName: 'Nav Soul',
      );

      await tester.pumpWidget(buildSubject(souls: [soul]));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSettingsPage));
      await tester.tap(find.text(context.messages.agentSoulsTitle));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nav Soul'));
      expect(navigatedPath, '/settings/agents/souls/soul-nav');
    });

    testWidgets('soul card shows version number', (tester) async {
      final soul = makeTestSoulDocument(
        id: 'soul-ver',
        displayName: 'Versioned Soul',
      );

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const AgentSettingsPage(),
          theme: DesignSystemTheme.light(),
          overrides: [
            agentTemplatesProvider.overrideWith(
              (ref) async => <AgentDomainEntity>[],
            ),
            activeTemplateVersionProvider.overrideWith(
              (ref, templateId) async => null,
            ),
            allSoulDocumentsProvider.overrideWith(
              (ref) async => [soul],
            ),
            activeSoulVersionProvider.overrideWith(
              (ref, soulId) async => makeTestSoulDocumentVersion(
                agentId: soulId,
                version: 5,
              ),
            ),
            allAgentInstancesProvider.overrideWith(
              (ref) async => <AgentDomainEntity>[],
            ),
            allEvolutionSessionsProvider.overrideWith(
              (ref) async => <AgentDomainEntity>[],
            ),
            agentIsRunningProvider.overrideWith(
              (ref, agentId) => Stream.value(false),
            ),
            templateForAgentProvider.overrideWith(
              (ref, agentId) async => null,
            ),
            pendingWakeRecordsProvider.overrideWith(
              (ref) async => const <PendingWakeRecord>[],
            ),
            hourlyWakeActivityProvider.overrideWith(
              (ref) async => const [],
            ),
            dailyTokenUsageProvider.overrideWith(
              (ref, days) async => const <DailyTokenUsage>[],
            ),
            tokenUsageComparisonProvider.overrideWith(
              (ref, days) async => const TokenUsageComparison(
                averageTokensByTimeOfDay: 0,
                todayTokens: 0,
              ),
            ),
            dailyTokenUsageByModelProvider.overrideWith(
              (ref, days) async => const <String, List<DailyTokenUsage>>{},
            ),
            tokenSourceBreakdownProvider.overrideWith(
              (ref) async => const <TokenSourceBreakdown>[],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSettingsPage));
      await tester.tap(find.text(context.messages.agentSoulsTitle));
      await tester.pumpAndSettle();

      // The shared row renders the active version as a mono `vN` cell.
      expect(find.text('v5'), findsOneWidget);
    });

    testWidgets('tapping back chevron calls NavService.beamBack', (
      tester,
    ) async {
      final mockNavService = MockNavService();
      when(() => mockNavService.currentPath).thenReturn('/settings/agents');
      // Body's URL-driven branch reads `isDesktopMode`; default the
      // mock to mobile so this test stays in the legacy local-state
      // path that the chevron back behavior relies on.
      when(() => mockNavService.isDesktopMode).thenReturn(false);
      when(mockNavService.beamBack).thenReturn(null);
      getIt.registerSingleton<NavService>(mockNavService);
      addTearDown(() => getIt.unregister<NavService>());

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();

      verify(mockNavService.beamBack).called(1);
    });

    group('URL-driven tab selection (desktop)', () {
      late MockNavService mockNavService;
      late ValueNotifier<DesktopSettingsRoute?> routeNotifier;

      setUp(() {
        routeNotifier = ValueNotifier<DesktopSettingsRoute?>(null);
        mockNavService = MockNavService();
        when(() => mockNavService.isDesktopMode).thenReturn(true);
        when(
          () => mockNavService.desktopSelectedSettingsRoute,
        ).thenReturn(routeNotifier);
        // Back-chevron and other rare in-page calls also hit
        // `currentPath` / `beamBack` — give them safe defaults so a
        // misclick during pump doesn't blow the test up.
        when(() => mockNavService.currentPath).thenReturn('/settings/agents');
        when(mockNavService.beamBack).thenReturn(null);
        getIt.registerSingleton<NavService>(mockNavService);
      });

      tearDown(() {
        routeNotifier.dispose();
      });

      DesktopSettingsRoute routeFor(String path) => (
        path: path,
        pathParameters: const <String, String>{},
        queryParameters: const <String, String>{},
      );

      // The active-tab signal must be on-stage-only; `find.byType` and
      // `find.text` default to `skipOffstage: true`, so the matching
      // `IndexedStack` child is the only one they observe — sibling
      // tabs that are still alive offstage don't poison the count.
      testWidgets(
        'route /settings/agents/templates puts Templates tab on stage',
        (tester) async {
          routeNotifier.value = routeFor('/settings/agents/templates');
          await tester.pumpWidget(buildSubject());
          await tester.pumpAndSettle();

          final context = tester.element(find.byType(AgentSettingsPage));
          expect(
            find.text(context.messages.agentTemplatesEmptyFiltered),
            findsOneWidget,
          );
          // Sibling-tab bodies must not be on-stage.
          expect(find.byType(TokenStatsTab), findsNothing);
          expect(find.byType(AgentInstancesList), findsNothing);
          expect(find.byType(AgentPendingWakesPage), findsNothing);
        },
      );

      testWidgets(
        'route /settings/agents/pending-wakes puts Pending Wakes on stage',
        (tester) async {
          routeNotifier.value = routeFor('/settings/agents/pending-wakes');
          await tester.pumpWidget(buildSubject());
          await tester.pumpAndSettle();

          expect(find.byType(AgentPendingWakesPage), findsOneWidget);
          expect(find.byType(TokenStatsTab), findsNothing);
          expect(find.byType(AgentInstancesList), findsNothing);
        },
      );

      testWidgets(
        'route change updates the active tab without remounting the page',
        (tester) async {
          routeNotifier.value = routeFor('/settings/agents/templates');
          await tester.pumpWidget(buildSubject());
          await tester.pumpAndSettle();

          final context = tester.element(find.byType(AgentSettingsPage));
          expect(
            find.text(context.messages.agentTemplatesEmptyFiltered),
            findsOneWidget,
          );

          // Drive the route to the souls tab — the same body should
          // pick up the souls empty-state without a fresh pumpWidget
          // (i.e. same widget instance).
          routeNotifier.value = routeFor('/settings/agents/souls');
          await tester.pumpAndSettle();

          expect(
            find.text(context.messages.agentSoulsEmptyFiltered),
            findsOneWidget,
          );
          // Templates empty-state must now be offstage.
          expect(
            find.text(context.messages.agentTemplatesEmptyFiltered),
            findsNothing,
          );
        },
      );

      testWidgets(
        'in-page tab strip is hidden on desktop — sidebar is the only '
        'navigation surface so the URL → tree → URL feedback loop has '
        'nothing to fight with',
        (tester) async {
          routeNotifier.value = routeFor('/settings/agents/templates');
          await tester.pumpWidget(buildSubject());
          await tester.pumpAndSettle();

          final context = tester.element(find.byType(AgentSettingsPage));
          // Tab labels only appear inside the in-page tab bar — the
          // tab body widgets (`_TemplatesTab`, `AgentPendingWakesPage`,
          // …) render their own content, not the tab name. So a
          // `find.text(label)` of zero is the cleanest "bar is hidden"
          // signal without reaching into a private widget class.
          expect(
            find.text(context.messages.agentTemplatesTitle),
            findsNothing,
          );
          expect(find.text(context.messages.agentSoulsTitle), findsNothing);
          expect(
            find.text(context.messages.agentPendingWakesTitle),
            findsNothing,
          );
          expect(find.text(context.messages.agentStatsTabTitle), findsNothing);
        },
      );

      testWidgets(
        'bare /settings/agents falls through to Stats (parent landing)',
        (tester) async {
          routeNotifier.value = routeFor('/settings/agents');
          await tester.pumpWidget(buildSubject());
          await tester.pumpAndSettle();

          // Stats tab content is on stage when the URL has no
          // per-tab segment, so the parent tree row stays a usable
          // landing.
          expect(find.byType(TokenStatsTab), findsOneWidget);
        },
      );

      testWidgets(
        'unknown sibling segment falls through to Stats — segment-aware '
        "match doesn't let `templates-archive` hijack the Templates tab",
        (tester) async {
          // Hypothetical future leaf whose name shares a prefix with
          // an existing tab. The segment-aware resolver must NOT
          // promote this to Templates via prefix-only matching.
          routeNotifier.value = routeFor('/settings/agents/templates-archive');
          await tester.pumpWidget(buildSubject());
          await tester.pumpAndSettle();

          expect(find.byType(TokenStatsTab), findsOneWidget);
        },
      );
    });

    testWidgets(
      'updating initialTab on the same widget instance re-syncs the '
      'selected tab (Settings V2 in-place rebuild path)',
      (tester) async {
        // Settings V2 routes `agents/templates`, `agents/souls`,
        // `agents/instances` through the same `AgentSettingsPage`
        // type. When Flutter updates this widget in place across
        // those routes, only `initialTab` changes — without the
        // `didUpdateWidget` re-sync the previously-selected tab
        // would survive and ignore the new request.
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            const _InitialTabHarness(initial: AgentSettingsTab.templates),
            theme: DesignSystemTheme.light(),
            overrides: [
              agentTemplatesProvider.overrideWith((ref) async => const []),
              activeTemplateVersionProvider.overrideWith(
                (ref, templateId) async => null,
              ),
              allSoulDocumentsProvider.overrideWith((ref) async => const []),
              activeSoulVersionProvider.overrideWith(
                (ref, soulId) async => null,
              ),
              allAgentInstancesProvider.overrideWith(
                (ref) async => const [],
              ),
              allEvolutionSessionsProvider.overrideWith(
                (ref) async => const [],
              ),
              agentIsRunningProvider.overrideWith(
                (ref, agentId) => Stream.value(false),
              ),
              templateForAgentProvider.overrideWith(
                (ref, agentId) async => null,
              ),
              pendingWakeRecordsProvider.overrideWith(
                (ref) async => const [],
              ),
              pendingWakeTargetTitleProvider.overrideWith(
                (ref, String? entryId) async => null,
              ),
              hourlyWakeActivityProvider.overrideWith(
                (ref) async => const [],
              ),
              dailyTokenUsageProvider.overrideWith(
                (ref, days) async => const <DailyTokenUsage>[],
              ),
              tokenUsageComparisonProvider.overrideWith(
                (ref, days) async => const TokenUsageComparison(
                  averageTokensByTimeOfDay: 0,
                  todayTokens: 0,
                ),
              ),
              dailyTokenUsageByModelProvider.overrideWith(
                (ref, days) async => const <String, List<DailyTokenUsage>>{},
              ),
              tokenSourceBreakdownProvider.overrideWith(
                (ref) async => const <TokenSourceBreakdown>[],
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // The Templates empty-state copy is the active-tab signal.
        var ctx = tester.element(find.byType(AgentSettingsPage));
        expect(
          find.text(ctx.messages.agentTemplatesEmptyFiltered),
          findsOneWidget,
        );

        // Swap initialTab on the same harness — didUpdateWidget fires
        // on the existing _AgentSettingsPageState. The Souls empty
        // state should now be on stage.
        _InitialTabHarnessState.current!.swap(AgentSettingsTab.souls);
        await tester.pumpAndSettle();

        ctx = tester.element(find.byType(AgentSettingsPage));
        expect(find.text(ctx.messages.agentSoulsEmptyFiltered), findsOneWidget);
      },
    );

    testWidgets(
      'AgentSettingsBody forwards initialTab to AgentSettingsPage so the '
      'Settings V2 leaf opens on the requested tab',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            const AgentSettingsBody(initialTab: AgentSettingsTab.souls),
            theme: DesignSystemTheme.light(),
            overrides: buildOverrides(),
          ),
        );
        await tester.pumpAndSettle();

        // The body must wrap an AgentSettingsPage carrying the same
        // initialTab, and that page must land on the Souls tab.
        final page = tester.widget<AgentSettingsPage>(
          find.byType(AgentSettingsPage),
        );
        expect(page.initialTab, AgentSettingsTab.souls);

        final context = tester.element(find.byType(AgentSettingsPage));
        expect(
          find.text(context.messages.agentSoulsEmptyFiltered),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'desktop mode with a null route falls through to the local fallback '
      '(initialTab) instead of throwing',
      (tester) async {
        // Desktop URL-driven branch, but the route notifier is still
        // null (no settings sub-route resolved yet). _resolveTabFromRoute
        // must return _localFallback — seeded from initialTab — so the
        // page renders the requested tab rather than crashing.
        final routeNotifier = ValueNotifier<DesktopSettingsRoute?>(null);
        addTearDown(routeNotifier.dispose);
        final mockNavService = MockNavService();
        when(() => mockNavService.isDesktopMode).thenReturn(true);
        when(
          () => mockNavService.desktopSelectedSettingsRoute,
        ).thenReturn(routeNotifier);
        when(() => mockNavService.currentPath).thenReturn('/settings/agents');
        when(mockNavService.beamBack).thenReturn(null);
        getIt.registerSingleton<NavService>(mockNavService);
        addTearDown(() => getIt.unregister<NavService>());

        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            const AgentSettingsPage(initialTab: AgentSettingsTab.souls),
            theme: DesignSystemTheme.light(),
            overrides: buildOverrides(),
          ),
        );
        await tester.pumpAndSettle();

        // Souls tab body (the local fallback) is on stage; sibling
        // bodies are not.
        final context = tester.element(find.byType(AgentSettingsPage));
        expect(
          find.text(context.messages.agentSoulsEmptyFiltered),
          findsOneWidget,
        );
        expect(find.byType(TokenStatsTab), findsNothing);
      },
    );

    testWidgets(
      'tab tap while url-driven beams to the per-tab URL instead of '
      'mutating local state',
      (tester) async {
        // The in-page tab bar is only rendered in mobile mode, so we
        // render it with isDesktopMode=false (bar shown, _onTabSelected
        // wired), then flip the mock to desktop so the live _isUrlDriven
        // read inside _onTabSelected takes the beam branch on tap.
        var desktop = false;
        final routeNotifier = ValueNotifier<DesktopSettingsRoute?>(null);
        addTearDown(routeNotifier.dispose);
        final mockNavService = MockNavService();
        when(() => mockNavService.isDesktopMode).thenAnswer((_) => desktop);
        when(
          () => mockNavService.desktopSelectedSettingsRoute,
        ).thenReturn(routeNotifier);
        when(() => mockNavService.currentPath).thenReturn('/settings/agents');
        when(mockNavService.beamBack).thenReturn(null);
        getIt.registerSingleton<NavService>(mockNavService);
        addTearDown(() => getIt.unregister<NavService>());

        String? beamedPath;
        beamToNamedOverride = (path) => beamedPath = path;

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(AgentSettingsPage));

        // Flip to desktop without rebuilding the subtree: the tab bar
        // stays mounted with its onSelected callback bound, but the
        // next _isUrlDriven read returns true.
        desktop = true;

        await tester.tap(find.text(context.messages.agentSoulsTitle));
        await tester.pump();

        // Beamed to the canonical per-tab URL (exercises _urlForTab),
        // and the local fallback was NOT mutated to Souls.
        expect(beamedPath, '/settings/agents/souls');
      },
    );

    testWidgets(
      'tab bar distributes extra width evenly when tabs do not fill the '
      'available width (wide layout)',
      (tester) async {
        // On a wide surface the five tabs do not fill the row, so
        // _segmentWidths takes the extra-per-tab distribution branch.
        // Each rendered tab is then wider than its natural width, and
        // together they span the full available width.
        tester.view.physicalSize = const Size(2400, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        // The tab strip lives in a horizontally scrolling view inside a
        // LayoutBuilder; the inner Row holds one SizedBox per tab.
        final scrollFinder = find.descendant(
          of: find.byType(Scaffold),
          matching: find.byType(SingleChildScrollView),
        );
        final innerRow = find.descendant(
          of: scrollFinder,
          matching: find.byType(Row),
        );
        final rowWidth = tester.getSize(innerRow.first).width;

        // The width handed to _segmentWidths comes from the LayoutBuilder
        // sized by the SingleChildScrollView's viewport (its own width).
        final availableWidth = tester.getSize(scrollFinder.first).width;

        // On the extra-per-tab branch the five cells are stretched to
        // exactly fill the available width, so the inner Row spans the
        // whole viewport (no horizontal overflow / scroll). On the
        // natural-width branch the Row would be wider and scroll instead.
        expect(rowWidth, moreOrLessEquals(availableWidth, epsilon: 1));

        // Each tab cell is wider than its natural (text-only) width,
        // confirming the surplus was distributed rather than left as
        // scrollable slack. The Instances tab still resolves on tap.
        final context = tester.element(find.byType(AgentSettingsPage));
        await tester.tap(find.text(context.messages.agentInstancesTitle));
        await tester.pumpAndSettle();
        expect(
          find.text(context.messages.agentInstancesPageTitle),
          findsOneWidget,
        );
      },
    );
  });
}

/// Minimal stateful harness that swaps `initialTab` on the same
/// `AgentSettingsPage` widget instance so `didUpdateWidget` (rather
/// than `initState`) is what reaches the underlying state. Pumping
/// a fresh `AgentSettingsPage` instead would re-initState and not
/// exercise the re-sync path.
class _InitialTabHarness extends StatefulWidget {
  const _InitialTabHarness({required this.initial});

  final AgentSettingsTab initial;

  @override
  State<_InitialTabHarness> createState() => _InitialTabHarnessState();
}

class _InitialTabHarnessState extends State<_InitialTabHarness> {
  static _InitialTabHarnessState? current;
  late AgentSettingsTab _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initial;
    current = this;
  }

  @override
  void dispose() {
    if (current == this) current = null;
    super.dispose();
  }

  void swap(AgentSettingsTab next) => setState(() => _tab = next);

  @override
  Widget build(BuildContext context) => AgentSettingsPage(initialTab: _tab);
}
