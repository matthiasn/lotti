import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_error_controller.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/skill_trigger_providers.dart';
import 'package:lotti/features/goals/service/goal_checkin_notifier.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';

import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';

void main() {
  tearDown(getIt.reset);

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        agentRepositoryProvider.overrideWithValue(MockAgentRepository()),
        agentSyncServiceProvider.overrideWithValue(MockAgentSyncService()),
        agentServiceProvider.overrideWithValue(MockAgentService()),
        cloudInferenceRepositoryProvider.overrideWithValue(
          MockCloudInferenceRepository(),
        ),
        loggingServiceProvider.overrideWithValue(MockLoggingService()),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  void registerJournalStack() {
    getIt
      ..registerSingleton<JournalDb>(MockJournalDb())
      ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
      ..registerSingleton<MetadataService>(MockMetadataService())
      ..registerSingleton<UpdateNotifications>(MockUpdateNotifications());
  }

  group('without the journal stack', () {
    test('the journal-side providers resolve to null, not to a throw', () {
      final c = container();

      // The agent tier is authoritative for evaluation and must not acquire a
      // hard dependency on journal infrastructure: a missing stack means no
      // mirror, not a broken goal runtime.
      expect(c.read(goalRepositoryProvider), isNull);
      expect(c.read(goalMirrorServiceProvider), isNull);
      expect(c.read(goalCheckInNotifierProvider), isNull);
      expect(c.read(goalCheckInSourceReaderProvider), isNull);
    });
  });

  group('with the journal stack registered', () {
    setUp(registerJournalStack);

    test('the repository and the services it feeds are constructed', () {
      final c = container();

      expect(c.read(goalRepositoryProvider), isNotNull);
      expect(c.read(goalMirrorServiceProvider), isNotNull);
      expect(c.read(goalCheckInNotifierProvider), isA<GoalCheckInNotifier>());
      expect(c.read(goalCheckInSourceReaderProvider), isNotNull);
    });

    test('the compactor is available wherever inference is', () {
      expect(container().read(goalCheckInCompactorProvider), isNotNull);
    });
  });

  test('the check-in trigger routes into the shared skill pipeline', () async {
    final agentService = MockAgentService();
    when(() => agentService.getAgent('goal-1')).thenAnswer(
      (_) async => makeTestIdentity(
        agentId: 'goal-1',
        kind: 'goal_agent',
        config: const AgentConfig(automaticUpdatesEnabled: true),
      ),
    );
    TriggerSkillParams? triggered;
    final c = ProviderContainer(
      overrides: [
        agentServiceProvider.overrideWithValue(agentService),
        loggingServiceProvider.overrideWithValue(MockLoggingService()),
        triggerSkillProvider.overrideWith((ref, params) async {
          triggered = params;
        }),
      ],
    );
    addTearDown(c.dispose);

    await c
        .read(goalCheckInTranscriptionTriggerProvider)
        .transcribe(agentId: 'goal-1', entryId: 'checkin-1');

    // The built-in transcribe skill, on the entry, with no task context — the
    // recording belongs to a goal, and claiming a task here would send the
    // runner looking for one that does not exist.
    expect(triggered?.entityId, 'checkin-1');
    expect(triggered?.skillId, skillTranscribeContextId);
    expect(triggered?.linkedTaskId, isNull);
  });

  test('a goal with automatic updates off records a visible decline', () async {
    final agentService = MockAgentService();
    when(() => agentService.getAgent('goal-off')).thenAnswer(
      (_) async => makeTestIdentity(
        agentId: 'goal-off',
        kind: 'goal_agent',
        config: const AgentConfig(automaticUpdatesEnabled: false),
      ),
    );
    var triggered = false;
    final c = ProviderContainer(
      overrides: [
        agentServiceProvider.overrideWithValue(agentService),
        loggingServiceProvider.overrideWithValue(MockLoggingService()),
        triggerSkillProvider.overrideWith((ref, params) async {
          triggered = true;
        }),
      ],
    );
    addTearDown(c.dispose);
    getIt.registerSingleton<DomainLogger>(MockDomainLogger());

    await c
        .read(goalCheckInTranscriptionTriggerProvider)
        .transcribe(agentId: 'goal-off', entryId: 'checkin-off');

    // Nothing is spent — that is what the switch is for…
    expect(triggered, isFalse);
    // …but the recording is marked as needing the user rather than left
    // claiming progress it will never make.
    expect(
      c.read(
        inferenceStatusControllerProvider((
          id: 'checkin-off',
          aiResponseType: AiResponseType.audioTranscription,
        )),
      ),
      InferenceStatus.error,
    );
    expect(
      c.read(
        inferenceErrorControllerProvider((
          id: 'checkin-off',
          aiResponseType: AiResponseType.audioTranscription,
        )),
      ),
      AppLocalizationsEn().goalCheckInTranscriptionOff,
    );
  });
}
