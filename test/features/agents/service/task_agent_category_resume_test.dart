import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/features/agents/service/task_agent_category_resume.dart';
import 'package:lotti/services/logging_domains.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_data/entity_factories.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockTaskAgentService taskAgentService;
  late MockAgentService agentService;
  late MockDomainLogger logger;

  setUp(() {
    taskAgentService = MockTaskAgentService();
    agentService = MockAgentService();
    logger = MockDomainLogger();
    when(() => taskAgentService.agentService).thenReturn(agentService);
    when(
      () => taskAgentService.updateAgentInferenceSetup(
        agentId: any(named: 'agentId'),
        setup: any(named: 'setup'),
      ),
    ).thenAnswer((_) async {});
  });

  AgentConfig disabled(AgentInferenceSetupOrigin origin) => AgentConfig(
    inferenceSetup: AgentInferenceSetup(
      mode: AgentInferenceSetupMode.disabled,
      origin: origin,
      originEntityId: 'penguin-operations',
    ),
  );

  Future<int> resume() => resumeTaskAgentsSwitchedOffForCategory(
    taskAgentService: taskAgentService,
    domainLogger: logger,
  );

  test('hands a task agent switched off for a category without a profile '
      'back to its category, and only that one', () async {
    when(
      () => agentService.listAgents(lifecycle: AgentLifecycle.dormant),
    ).thenAnswer(
      (_) async => [
        makeTestIdentity(
          agentId: 'category-off',
          config: disabled(AgentInferenceSetupOrigin.categorySnapshot),
        ),
        // Turned off by the user: stays off.
        makeTestIdentity(
          agentId: 'user-off',
          config: disabled(AgentInferenceSetupOrigin.user),
        ),
        // Not a task agent.
        makeTestIdentity(
          agentId: 'goal-off',
          kind: AgentKinds.goalAgent,
          config: disabled(AgentInferenceSetupOrigin.categorySnapshot),
        ),
        // Dormant for another reason, with a running setup.
        makeTestIdentity(agentId: 'no-setup'),
      ],
    );

    expect(await resume(), 1);

    final setup =
        verify(
              () => taskAgentService.updateAgentInferenceSetup(
                agentId: 'category-off',
                setup: captureAny(named: 'setup'),
              ),
            ).captured.single
            as AgentInferenceSetup;
    expect(setup.mode, AgentInferenceSetupMode.configured);
    expect(setup.followsCategory, isTrue);
    expect(setup.originEntityId, 'penguin-operations');
    verifyNever(
      () => taskAgentService.updateAgentInferenceSetup(
        agentId: any(named: 'agentId', that: isNot('category-off')),
        setup: any(named: 'setup'),
      ),
    );
  });

  test('one agent that cannot be handed back is logged and skipped; the '
      'others still are', () async {
    when(
      () => agentService.listAgents(lifecycle: AgentLifecycle.dormant),
    ).thenAnswer(
      (_) async => [
        makeTestIdentity(
          agentId: 'broken',
          config: disabled(AgentInferenceSetupOrigin.categorySnapshot),
        ),
        makeTestIdentity(
          agentId: 'fine',
          config: disabled(AgentInferenceSetupOrigin.categorySnapshot),
        ),
      ],
    );
    when(
      () => taskAgentService.updateAgentInferenceSetup(
        agentId: 'broken',
        setup: any(named: 'setup'),
      ),
    ).thenThrow(StateError('Agent broken not found'));

    expect(await resume(), 1);

    verify(
      () => taskAgentService.updateAgentInferenceSetup(
        agentId: 'fine',
        setup: any(named: 'setup'),
      ),
    ).called(1);
    verify(
      () => logger.error(
        LogDomain.agentRuntime,
        any<Object>(that: isA<StateError>()),
        stackTrace: any(named: 'stackTrace'),
        subDomain: 'restore',
        message: any(named: 'message'),
      ),
    ).called(1);
  });

  test(
    'changes nothing when no agent was switched off for its category',
    () async {
      when(
        () => agentService.listAgents(lifecycle: AgentLifecycle.dormant),
      ).thenAnswer((_) async => [makeTestIdentity(agentId: 'no-setup')]);

      expect(await resume(), 0);

      verifyNever(
        () => taskAgentService.updateAgentInferenceSetup(
          agentId: any(named: 'agentId'),
          setup: any(named: 'setup'),
        ),
      );
      verifyNever(
        () => logger.log(
          any(),
          any(),
          subDomain: any(named: 'subDomain'),
        ),
      );
    },
  );
}
