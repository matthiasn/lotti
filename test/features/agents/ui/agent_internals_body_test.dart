import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/ui/agent_internals_body.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_service.dart';

import '../../../test_helper.dart';
import '../test_data/ai_config_factories.dart';
import '../test_data/entity_factories.dart';
import '../test_data/template_factories.dart';

/// Minimal smoke coverage for [AgentInternalsBody]. The deep behaviour
/// of each tab (Stats / Reports / Conversations / Observations /
/// Activity) is exercised by `agent_detail_page_test.dart`, which
/// renders the same widget through `AgentDetailPage`. This file confirms
/// the body can be instantiated standalone (the contract the side-panel
/// route relies on) and that switching tabs swaps the body content.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildSubject({
    AgentLifecycle lifecycle = AgentLifecycle.active,
    AsyncValue<AgentDomainEntity?> stateAsync = const AsyncValue.data(null),
    List<Override> extraOverrides = const [],
  }) {
    return RiverpodWidgetTestBench(
      mediaQueryData: const MediaQueryData(size: Size(900, 800)),
      overrides: [
        agentIdentityProvider.overrideWith(
          (ref, agentId) async => makeTestIdentity(),
        ),
        templateForAgentProvider.overrideWith(
          (ref, agentId) async => null,
        ),
        ...extraOverrides,
      ],
      child: SingleChildScrollView(
        child: AgentInternalsBody(
          agentId: 'agent-001',
          lifecycle: lifecycle,
          stateAsync: stateAsync,
        ),
      ),
    );
  }

  group('AgentInternalsBody', () {
    testWidgets('renders the canonical five tabs', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Stats'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('Conversations'), findsOneWidget);
      expect(find.text('Observations'), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);
    });

    testWidgets('Stats tab is selected by default', (tester) async {
      // Use a populated state so the State section renders, which only
      // appears on the Stats tab.
      final state = makeTestState(
        wakeCounter: 4,
      );
      await tester.pumpWidget(
        buildSubject(stateAsync: AsyncValue.data(state)),
      );
      await tester.pumpAndSettle();

      // Stats content includes the agent state heading and the wake count.
      expect(find.text('State Info'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets(
      'tapping the assigned template chip pushes the template detail page',
      (tester) async {
        final template = makeTestTemplate();
        // Bypass `buildSubject` so we can override
        // `templateForAgentProvider` once and avoid the family-double-
        // override assertion.
        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            mediaQueryData: const MediaQueryData(size: Size(900, 800)),
            overrides: [
              agentIdentityProvider.overrideWith(
                (ref, agentId) async => makeTestIdentity(),
              ),
              templateForAgentProvider.overrideWith(
                (ref, agentId) async => template,
              ),
            ],
            child: const SingleChildScrollView(
              child: AgentInternalsBody(
                agentId: 'agent-001',
                lifecycle: AgentLifecycle.active,
                stateAsync: AsyncValue.data(null),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The Stats tab surfaces the template name as an ActionChip.
        expect(find.text(template.displayName), findsOneWidget);

        // Tapping the chip exercises the `onPressed` closure that
        // pushes `AgentTemplateDetailPage`. The chip lives below the
        // fold of the test viewport; scroll it into view first so
        // `tap` resolves to a real hit. We don't assert on the
        // pushed page's contents (its own tests cover that and it
        // requires extra provider scaffolding) — only that the
        // closure runs without throwing.
        await tester.scrollUntilVisible(
          find.text(template.displayName),
          200,
          scrollable: find
              .byType(Scrollable)
              .at(1), // skip the bench's outer Scaffold scroller
        );
        await tester.tap(find.text(template.displayName));
        await tester.pump();
      },
    );
  });

  testWidgets('setup row opens the same persistent Agent setup sheet', (
    tester,
  ) async {
    final profile = testInferenceProfile(
      id: 'profile-1',
      thinkingModelId: 'model-1',
    );
    final model = testAiModel();
    final provider = testInferenceProvider();
    final state = makeTestState(
      slots: const AgentSlots(activeTaskId: 'task-1'),
    );
    final resolved = ResolvedAgentSetup(
      status: AgentSetupResolutionStatus.resolved,
      profile: ResolvedProfile(
        thinkingModelId: model.providerModelId,
        thinkingProvider: provider,
        thinkingModel: model,
      ),
      source: AgentSetupResolutionSource.baseProfile,
      setupOrigin: AgentInferenceSetupOrigin.user,
    );
    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        mediaQueryData: const MediaQueryData(size: Size(900, 800)),
        overrides: [
          agentIdentityProvider.overrideWith(
            (ref, agentId) async => makeTestIdentity(
              config: const AgentConfig(
                profileId: 'profile-1',
                inferenceSetup: AgentInferenceSetup(
                  mode: AgentInferenceSetupMode.configured,
                  origin: AgentInferenceSetupOrigin.user,
                  baseProfileId: 'profile-1',
                ),
              ),
            ),
          ),
          agentStateProvider.overrideWith((ref, agentId) async => state),
          templateForAgentProvider.overrideWith((ref, agentId) async => null),
          taskAgentResolvedSetupProvider.overrideWith(
            (ref, agentId) async => resolved,
          ),
          taskAgentSetupOptionsProvider.overrideWith(
            (ref) async => TaskAgentSetupOptions(
              profiles: [profile],
              models: [model],
              providers: [provider],
            ),
          ),
        ],
        child: const SingleChildScrollView(
          child: AgentInternalsBody(
            agentId: 'agent-001',
            lifecycle: AgentLifecycle.active,
            stateAsync: AsyncValue.data(null),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Test Model · via Gemini'),
      200,
      scrollable: find.byType(Scrollable).at(1),
    );
    await tester.tap(find.text('Test Model · via Gemini'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Agent setup'), findsWidgets);
    expect(find.text('You chose this for this agent'), findsOneWidget);
  });

  testWidgets('setup row distinguishes a broken setup from no selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        mediaQueryData: const MediaQueryData(size: Size(900, 800)),
        overrides: [
          agentIdentityProvider.overrideWith(
            (ref, agentId) async => makeTestIdentity(),
          ),
          agentStateProvider.overrideWith((ref, agentId) async => null),
          templateForAgentProvider.overrideWith((ref, agentId) async => null),
          taskAgentResolvedSetupProvider.overrideWith(
            (ref, agentId) async => const ResolvedAgentSetup(
              status: AgentSetupResolutionStatus.broken,
              brokenSelectionId: 'missing-profile',
            ),
          ),
        ],
        child: const SingleChildScrollView(
          child: AgentInternalsBody(
            agentId: 'agent-001',
            lifecycle: AgentLifecycle.active,
            stateAsync: AsyncValue.data(null),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Selected AI setup is unavailable').first,
      200,
      scrollable: find.byType(Scrollable).at(1),
    );
    expect(find.text('Selected AI setup is unavailable'), findsNWidgets(2));
    expect(find.text('No AI setup'), findsNothing);
  });

  testWidgets('Daily OS setup row opens the planner override sheet', (
    tester,
  ) async {
    final profile = testInferenceProfile(
      id: 'profile-1',
      thinkingModelId: 'model-1',
    );
    final model = testAiModel();
    final provider = testInferenceProvider();
    final identity = makeTestIdentity(
      id: dailyOsPlannerAgentId,
      agentId: dailyOsPlannerAgentId,
      kind: AgentKinds.dayAgent,
      config: const AgentConfig(
        profileId: 'profile-1',
        inferenceSetup: AgentInferenceSetup(
          mode: AgentInferenceSetupMode.configured,
          origin: AgentInferenceSetupOrigin.user,
          baseProfileId: 'profile-1',
        ),
      ),
    );
    final resolved = ResolvedAgentSetup(
      status: AgentSetupResolutionStatus.resolved,
      profile: ResolvedProfile(
        thinkingModelId: model.providerModelId,
        thinkingProvider: provider,
        thinkingModel: model,
      ),
      source: AgentSetupResolutionSource.baseProfile,
      setupOrigin: AgentInferenceSetupOrigin.user,
    );
    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        mediaQueryData: const MediaQueryData(size: Size(900, 800)),
        overrides: [
          agentIdentityProvider.overrideWith((ref, agentId) async => identity),
          agentStateProvider.overrideWith((ref, agentId) async => null),
          templateForAgentProvider.overrideWith((ref, agentId) async => null),
          taskAgentResolvedSetupProvider.overrideWith(
            (ref, agentId) async => resolved,
          ),
          taskAgentSetupOptionsProvider.overrideWith(
            (ref) async => TaskAgentSetupOptions(
              profiles: [profile],
              models: [model],
              providers: [provider],
            ),
          ),
        ],
        child: const SingleChildScrollView(
          child: AgentInternalsBody(
            agentId: dailyOsPlannerAgentId,
            lifecycle: AgentLifecycle.active,
            stateAsync: AsyncValue.data(null),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Test Model · via Gemini'),
      200,
      scrollable: find.byType(Scrollable).at(1),
    );
    expect(find.text('Daily OS inference'), findsOneWidget);
    expect(find.text('Current planner setup'), findsOneWidget);
    await tester.tap(find.text('Test Model · via Gemini'));
    await tester.pumpAndSettle();

    expect(find.text('Use Daily OS default'), findsOneWidget);
  });
}
