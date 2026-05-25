import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_agent_workflow.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  group('dayAgentWorkflowProvider', () {
    test('resolves dependencies and wires persisted-state notifications', () {
      final repository = MockAgentRepository();
      final syncService = MockAgentSyncService();
      final aiConfigRepository = MockAiConfigRepository();
      final cloudInferenceRepository = MockCloudInferenceRepository();
      final templateService = MockAgentTemplateService();
      final soulDocumentService = MockSoulDocumentService();
      final domainLogger = MockDomainLogger();
      final notifications = MockUpdateNotifications();
      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(repository),
          conversationRepositoryProvider.overrideWith(
            ConversationRepository.new,
          ),
          aiConfigRepositoryProvider.overrideWithValue(aiConfigRepository),
          cloudInferenceRepositoryProvider.overrideWithValue(
            cloudInferenceRepository,
          ),
          agentSyncServiceProvider.overrideWithValue(syncService),
          agentTemplateServiceProvider.overrideWithValue(templateService),
          soulDocumentServiceProvider.overrideWithValue(soulDocumentService),
          domainLoggerProvider.overrideWithValue(domainLogger),
          updateNotificationsProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(container.dispose);

      final workflow = container.read(dayAgentWorkflowProvider);

      expect(workflow, isA<DayAgentWorkflow>());
      workflow.onPersistedStateChanged?.call('day-agent-001');
      verify(
        () => notifications.notifyUiOnly({
          'day-agent-001',
          agentNotification,
        }),
      ).called(1);
    });
  });
}
