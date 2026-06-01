import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_internals_body.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
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
class _FakeProfileController extends InferenceProfileController {
  _FakeProfileController(this._profiles);

  final List<AiConfig> _profiles;

  @override
  Stream<List<AiConfig>> build() => Stream.value(_profiles);
}

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
        revision: 7,
        wakeCounter: 4,
      );
      await tester.pumpWidget(
        buildSubject(stateAsync: AsyncValue.data(state)),
      );
      await tester.pumpAndSettle();

      // Stats content includes the agent state heading.
      expect(find.text('State Info'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
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

  group('AgentInternalsBody - ProfileSection onProfileSelected callback', () {
    // Both tests give the identity a profileId so ProfileSelector renders its
    // clear (×) button.  Tapping that button fires onProfileSelected(null),
    // which enters the async callback and exercises the success / error paths.

    Widget buildProfileSubject({
      required MockTaskAgentService mockService,
      required String profileId,
    }) {
      return RiverpodWidgetTestBench(
        mediaQueryData: const MediaQueryData(size: Size(900, 800)),
        overrides: [
          agentIdentityProvider.overrideWith(
            (ref, agentId) async => makeTestIdentity(
              config: AgentConfig(profileId: profileId),
            ),
          ),
          templateForAgentProvider.overrideWith(
            (ref, agentId) async => null,
          ),
          inferenceProfileControllerProvider.overrideWith(
            () => _FakeProfileController([
              testInferenceProfile(id: profileId),
            ]),
          ),
          taskAgentServiceProvider.overrideWithValue(mockService),
        ],
        child: const SingleChildScrollView(
          child: AgentInternalsBody(
            agentId: 'agent-001',
            lifecycle: AgentLifecycle.active,
            stateAsync: AsyncValue.data(null),
          ),
        ),
      );
    }

    // Scrolls the clear (×) button into view and taps it, triggering
    // onProfileSelected(null) on the ProfileSelector.
    Future<void> tapClearButton(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        find.byIcon(Icons.clear),
        200,
        scrollable: find.byType(Scrollable).at(1),
      );
      await tester.tap(find.byIcon(Icons.clear));
      // pump twice: first frame processes the async callback initiation,
      // second frame processes the awaited future completion.
      await tester.pump();
      await tester.pump();
    }

    testWidgets(
      'success path: updateAgentProfile called with agentId and null profileId',
      (tester) async {
        final mockService = MockTaskAgentService();
        when(
          () => mockService.updateAgentProfile(
            agentId: any(named: 'agentId'),
            profileId: any(named: 'profileId'),
          ),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(
          buildProfileSubject(
            mockService: mockService,
            profileId: 'prof-active',
          ),
        );
        await tester.pump();
        await tester.pump();

        await tapClearButton(tester);

        // Tapping clear calls onProfileSelected(null), which invokes
        // updateAgentProfile with profileId: null (lines 333-340).
        verify(
          () => mockService.updateAgentProfile(
            agentId: 'agent-001',
            profileId: null,
          ),
        ).called(1);
      },
    );

    testWidgets(
      'error path: shows error toast when updateAgentProfile throws',
      (tester) async {
        final mockService = MockTaskAgentService();
        when(
          () => mockService.updateAgentProfile(
            agentId: any(named: 'agentId'),
            profileId: any(named: 'profileId'),
          ),
        ).thenThrow(StateError('agent not found'));

        await tester.pumpWidget(
          buildProfileSubject(
            mockService: mockService,
            profileId: 'prof-active',
          ),
        );
        await tester.pump();
        await tester.pump();

        await tapClearButton(tester);

        // The catch block (lines 342-351) shows an error toast with the
        // localized "Error" title.
        final toast = tester.widget<DesignSystemToast>(
          find.byType(DesignSystemToast),
        );
        expect(toast.tone, DesignSystemToastTone.error);
        expect(toast.title, 'Error');
      },
    );
  });
}
