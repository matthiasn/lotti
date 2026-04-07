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
import 'package:lotti/features/agents/ui/agent_pending_wakes_list.dart';
import 'package:lotti/features/agents/ui/agent_settings_page.dart';
import 'package:lotti/features/agents/ui/token_stats_tab.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/gamey/colors.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../test_utils.dart';

void main() {
  setUp(() async {
    await setUpTestGetIt();
  });
  tearDown(() async {
    beamToNamedOverride = null;
    await tearDownTestGetIt();
  });

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
      overrides: [
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
      ],
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
      expect(
        find.byType(TokenStatsTab, skipOffstage: false),
        findsOneWidget,
      );
    });

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

      expect(find.text('Laura'), findsOneWidget);
      expect(find.text('Tom'), findsOneWidget);
    });

    testWidgets('shows empty state when no templates', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSettingsPage));
      await tester.tap(find.text(context.messages.agentTemplatesTitle));
      await tester.pumpAndSettle();

      expect(
        find.text(context.messages.agentTemplateEmptyList),
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

      expect(find.text('Wake dashboard polish'), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
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
        find.byType(AgentPendingWakesList, skipOffstage: false),
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
      expect(find.text('models/gemini-3-flash-preview'), findsOneWidget);
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

      expect(find.byIcon(Icons.add), findsOneWidget);
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

      expect(
        find.text(context.messages.agentTemplateVersionLabel(3)),
        findsOneWidget,
      );
    });

    testWidgets('tapping FAB navigates to template creation', (tester) async {
      String? navigatedPath;
      beamToNamedOverride = (path) => navigatedPath = path;

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSettingsPage));
      await tester.tap(find.text(context.messages.agentTemplatesTitle));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));

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

      await tester.tap(find.text('Nav Template'));
      expect(navigatedPath, '/settings/agents/templates/tpl-nav');
    });

    Finder pendingDotInCard(String templateName) {
      final card = find.ancestor(
        of: find.text(templateName),
        matching: find.byType(ListTile),
      );
      return find.descendant(
        of: card,
        matching: find.byWidgetPredicate((widget) {
          if (widget is Container) {
            final decoration = widget.decoration;
            if (decoration is BoxDecoration) {
              return decoration.shape == BoxShape.circle &&
                  decoration.color == GameyColors.primaryPurple;
            }
          }
          return false;
        }),
      );
    }

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
          expect(pendingDotInCard('Dot Template'), findsOneWidget);
        } else {
          expect(pendingDotInCard('Dot Template'), findsNothing);
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
      expect(find.byIcon(Icons.psychology_rounded), findsOneWidget);
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
        find.text(context.messages.agentSoulEmptyList),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.psychology_outlined), findsOneWidget);
    });

    testWidgets('shows FAB on Souls tab for creating souls', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSettingsPage));
      await tester.tap(find.text(context.messages.agentSoulsTitle));
      await tester.pumpAndSettle();

      expect(
        find.byTooltip(context.messages.agentSoulCreateTitle),
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

      await tester.tap(find.byIcon(Icons.add));

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

      expect(
        find.text(context.messages.agentSoulVersionLabel(5)),
        findsOneWidget,
      );
    });

    testWidgets('tapping back chevron calls NavService.beamBack', (
      tester,
    ) async {
      final mockNavService = MockNavService();
      when(() => mockNavService.currentPath).thenReturn('/settings/agents');
      when(mockNavService.beamBack).thenReturn(null);
      getIt.registerSingleton<NavService>(mockNavService);
      addTearDown(() => getIt.unregister<NavService>());

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();

      verify(mockNavService.beamBack).called(1);
    });
  });
}
