import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:genui/genui.dart' show CreateSurface;
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as agent_model;
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/template_performance_metrics.dart';
import 'package:lotti/features/agents/projection/input_capture.dart';
import 'package:lotti/features/agents/service/suggestion_retraction_service.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/logging_domains.dart';
import 'package:mocktail/mocktail.dart';
import 'package:research_package/model.dart';

import '../mocks/mocks.dart';
import '../test_data/test_data.dart';

// Real fallback values for sealed unions used with mocktail

final JournalEntity fallbackJournalEntity = testTextEntry;

final ProjectEntry fallbackProjectEntry =
    JournalEntity.project(
          meta: Metadata(
            id: 'fallback-project-id',
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
            dateFrom: DateTime.fromMillisecondsSinceEpoch(0),
            dateTo: DateTime.fromMillisecondsSinceEpoch(0),
          ),
          data: ProjectData(
            title: 'Fallback Project',
            status: ProjectStatus.open(
              id: 'fallback-status-id',
              createdAt: DateTime.fromMillisecondsSinceEpoch(0),
              utcOffset: 0,
            ),
            dateFrom: DateTime.fromMillisecondsSinceEpoch(0),
            dateTo: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        )
        as ProjectEntry;

const SyncMessage fallbackSyncMessage = SyncJournalEntity(
  id: 'fallback-id',
  jsonPath: '/tmp/fallback.json',
  vectorClock: null,
  status: SyncEntryStatus.initial,
);

final AiConfig fallbackAiConfig = AiConfig.inferenceProvider(
  id: 'config-id',
  baseUrl: 'http://example.com',
  apiKey: 'key',
  name: 'name',
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  inferenceProviderType: InferenceProviderType.openAi,
);

final NotificationEntity fallbackNotificationEntity =
    NotificationEntity.taskSuggestion(
      meta: NotificationMeta(
        id: 'fallback-notification-id',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        scheduledFor: DateTime.fromMillisecondsSinceEpoch(0),
        vectorClock: const VectorClock({'fallback-host': 0}),
        originatingHostId: 'fallback-host',
      ),
      linkedTaskId: 'fallback-task-id',
      suggestionCount: 1,
      title: 'Fallback',
      body: 'Fallback notification',
    );

const ConfigFlag fallbackConfigFlag = ConfigFlag(
  name: 'fallback-flag',
  description: 'fallback',
  status: false,
);

final SurveyData fallbackSurveyData = SurveyData(
  taskResult: RPTaskResult(identifier: 'fallback-survey'),
  scoreDefinitions: const {},
  calculatedScores: const {},
);

final Checklist fallbackChecklist = Checklist(
  meta: Metadata(
    id: 'fallback-checklist',
    createdAt: DateTime(2024, 3, 15),
    updatedAt: DateTime(2024, 3, 15),
    dateFrom: DateTime(2024, 3, 15),
    dateTo: DateTime(2024, 3, 15),
  ),
  data: const ChecklistData(
    title: 'Fallback Checklist',
    linkedChecklistItems: [],
    linkedTasks: [],
  ),
);

final ChecklistItem fallbackChecklistItem = ChecklistItem(
  meta: Metadata(
    id: 'fallback-checklist-item',
    createdAt: DateTime(2024, 3, 15),
    updatedAt: DateTime(2024, 3, 15),
    dateFrom: DateTime(2024, 3, 15),
    dateTo: DateTime(2024, 3, 15),
  ),
  data: const ChecklistItemData(
    title: 'Fallback Item',
    isChecked: false,
    linkedChecklists: [],
  ),
);

/// Registers all commonly used fallback values for mocktail in one call.
///
/// Call this in `setUpAll()` or `setUp()` instead of scattering individual
/// `registerFallbackValue()` calls across test files. Safe to call multiple
/// times — mocktail deduplicates internally.
void registerAllFallbackValues() {
  // Sealed union / abstract class fallbacks (need real instances)
  registerFallbackValue(fallbackJournalEntity);
  registerFallbackValue(fallbackProjectEntry);
  registerFallbackValue(fallbackSyncMessage);
  registerFallbackValue(fallbackAiConfig);
  registerFallbackValue(fallbackNotificationEntity);
  registerFallbackValue(fallbackConfigFlag);
  registerFallbackValue(fallbackSurveyData);

  // Logging
  registerFallbackValue(LogDomain.general);
  registerFallbackValue(InsightLevel.info);
  registerFallbackValue(StackTrace.empty);

  // AI skill types (for hasAutomatedSkillType stubs with `any()`)
  registerFallbackValue(SkillType.transcription);

  // Fake classes from mocks.dart
  registerFallbackValue(FakeMetadata());
  registerFallbackValue(FakeDashboardDefinition());
  registerFallbackValue(FakeHabitDefinition());
  registerFallbackValue(FakeCategoryDefinition());
  registerFallbackValue(FakeEntryText());
  registerFallbackValue(FakeEventData());
  registerFallbackValue(FakeTaskData());
  registerFallbackValue(FakeJournalAudio());
  registerFallbackValue(FakePlayable());
  registerFallbackValue(FakeMeasurementData());
  registerFallbackValue(FakeHabitCompletionData());
  registerFallbackValue(FakeAiConfigPrompt());
  registerFallbackValue(FakeAiConfigModel());
  registerFallbackValue(FakeAiConfigInferenceProvider());
  registerFallbackValue(FakeChatSession());
  registerFallbackValue(FakeChecklistData());
  registerFallbackValue(FakeChecklistItemData());
  registerFallbackValue(fallbackChecklist);
  registerFallbackValue(fallbackChecklistItem);

  // Agent domain entity fallbacks
  registerFallbackValue(
    AgentDomainEntity.agent(
      id: 'fallback-agent-id',
      agentId: 'fallback-agent-id',
      kind: 'task_agent',
      displayName: 'Fallback Agent',
      lifecycle: AgentLifecycle.active,
      mode: AgentInteractionMode.autonomous,
      allowedCategoryIds: const {},
      currentStateId: 'fallback-state-id',
      config: const AgentConfig(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      vectorClock: null,
    ),
  );
  registerFallbackValue(
    agent_model.AgentLink.basic(
      id: 'fallback-link-id',
      fromId: 'fallback-from-id',
      toId: 'fallback-to-id',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      vectorClock: null,
    ),
  );

  // Agent repository fallback (for setter verification with `any()`)
  registerFallbackValue(MockAgentRepository());

  // Captured input sources (compaction summarizer stubs with `any()`)
  registerFallbackValue(const <RenderedSource>[]);

  // Staged retractions list (wake-output writer stubs applyStaged with `any()`)
  registerFallbackValue(const <StagedRetraction>[]);

  // Agent database fallbacks
  registerFallbackValue(
    WakeRunLogData(
      runKey: 'fallback-run-key',
      agentId: 'fallback-agent-id',
      reason: 'subscription',
      threadId: 'fallback-thread-id',
      status: 'queued',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    ),
  );

  // Agent config fallback
  registerFallbackValue(const AgentConfig());

  // Agent subscription fallback
  registerFallbackValue(
    AgentSubscription(
      id: 'fallback-sub',
      agentId: 'fallback-agent',
      matchEntityIds: const {},
    ),
  );

  // Agent domain entity variant fallbacks
  registerFallbackValue(
    AgentDomainEntity.unknown(
      id: 'fallback-unknown',
      agentId: 'fallback-unknown-agent',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    ),
  );

  // SyncMessage variant fallbacks
  registerFallbackValue(
    const SyncMessage.agentEntity(status: SyncEntryStatus.initial),
  );
  registerFallbackValue(
    const SyncMessage.agentLink(status: SyncEntryStatus.initial),
  );

  // Sync-related fallbacks
  registerFallbackValue(const VectorClock({}));
  registerFallbackValue(SyncSequencePayloadType.journalEntity);

  // Enum fallbacks
  registerFallbackValue(ChangeSource.user);
  registerFallbackValue(AiConfigType.inferenceProvider);
  registerFallbackValue(AgentMilestone.wakeCompleted);
  registerFallbackValue(AgentMessageKind.system);

  // Profile-automation result fallback (used by synced-audio-inference
  // dispatcher and skill-inference runner tests via `any()`).
  registerFallbackValue(AutomationResult.notHandled);

  registerFallbackValue(
    const TemplatePerformanceMetrics(
      templateId: 'fallback-template',
      totalWakes: 0,
      successCount: 0,
      failureCount: 0,
      successRate: 0,
      averageDuration: null,
      firstWakeAt: null,
      lastWakeAt: null,
      activeInstanceCount: 0,
    ),
  );
  registerFallbackValue(
    AgentDomainEntity.agentTemplate(
          id: 'fallback-tpl',
          agentId: 'fallback-tpl',
          displayName: 'Fallback',
          kind: AgentTemplateKind.taskAgent,
          modelId: 'models/fallback',
          categoryIds: const {},
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
          vectorClock: null,
        )
        as AgentTemplateEntity,
  );
  registerFallbackValue(
    AgentDomainEntity.agentTemplateVersion(
          id: 'fallback-ver',
          agentId: 'fallback-tpl',
          version: 1,
          status: AgentTemplateVersionStatus.active,
          directives: 'fallback',
          authoredBy: 'system',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          vectorClock: null,
        )
        as AgentTemplateVersionEntity,
  );

  // Change set fallbacks
  registerFallbackValue(
    AgentDomainEntity.changeSet(
          id: 'fallback-cs',
          agentId: 'fallback-agent',
          taskId: 'fallback-task',
          threadId: 'fallback-thread',
          runKey: 'fallback-run',
          status: ChangeSetStatus.pending,
          items: const [
            ChangeItem(
              toolName: 'fallback_tool',
              args: {},
              humanSummary: 'Fallback',
            ),
          ],
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          vectorClock: null,
        )
        as ChangeSetEntity,
  );
  registerFallbackValue(
    AgentDomainEntity.changeDecision(
          id: 'fallback-cd',
          agentId: 'fallback-agent',
          changeSetId: 'fallback-cs',
          itemIndex: 0,
          toolName: 'fallback_tool',
          verdict: ChangeDecisionVerdict.confirmed,
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          vectorClock: null,
          taskId: 'fallback-task',
          humanSummary: 'Fallback decision',
          args: const {'title': 'Fallback recommendation'},
        )
        as ChangeDecisionEntity,
  );

  // Logging enum fallbacks
  registerFallbackValue(InsightLevel.info);
  registerFallbackValue(InsightType.log);

  // EntryLink fallback (for sealed union matching with any())
  registerFallbackValue(
    EntryLink.basic(
      id: 'fallback-link',
      fromId: 'fallback-from',
      toId: 'fallback-to',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      vectorClock: null,
    ),
  );

  // Drift companion fallbacks (for mocked DB operations).
  registerFallbackValue(
    OutboxCompanion(
      status: drift.Value(OutboxStatus.pending.index),
    ),
  );

  // Common builtin fallbacks
  registerFallbackValue(StackTrace.empty);
  registerFallbackValue(Duration.zero);
  registerFallbackValue(Uri());
  registerFallbackValue(<String>{});
  registerFallbackValue(DateTime(2024));
  registerFallbackValue(EntryFlag.none);
  registerFallbackValue(Float32List(0));
  registerFallbackValue(<int>[]);
  registerFallbackValue(<String>[]);

  // AI response data fallback
  registerFallbackValue(
    const AiResponseData(
      model: 'fallback-model',
      systemMessage: '',
      prompt: '',
      thoughts: '',
      response: '',
    ),
  );

  // GenUI A2uiMessage fallback (needed when MockSurfaceController.handleMessage
  // is stubbed with any()).
  registerFallbackValue(
    const CreateSurface(surfaceId: 'fallback-surface', catalogId: 'fallback'),
  );
}
