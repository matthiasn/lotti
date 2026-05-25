import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_agent_workflow.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  group('dayAgentWorkflowProvider', () {
    setUp(() async {
      await setUpTestGetIt(
        additionalSetup: () {
          getIt.registerSingleton<Fts5Db>(MockFts5Db());
        },
      );
    });

    tearDown(tearDownTestGetIt);

    test('resolves dependencies and wires persisted-state notifications', () {
      final repository = MockAgentRepository();
      final syncService = MockAgentSyncService();
      final journalDb = MockJournalDb();
      final journalRepository = MockJournalRepository();
      final aiConfigRepository = MockAiConfigRepository();
      final cloudInferenceRepository = MockCloudInferenceRepository();
      final templateService = MockAgentTemplateService();
      final soulDocumentService = MockSoulDocumentService();
      final domainLogger = MockDomainLogger();
      final wakeOrchestrator = MockWakeOrchestrator();
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
          journalDbProvider.overrideWithValue(journalDb),
          journalRepositoryProvider.overrideWithValue(journalRepository),
          wakeOrchestratorProvider.overrideWithValue(wakeOrchestrator),
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
