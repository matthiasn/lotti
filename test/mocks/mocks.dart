import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/service/change_set_confirmation_service.dart';
import 'package:lotti/features/agents/service/feedback_extraction_service.dart';
import 'package:lotti/features/agents/service/improver_agent_service.dart';
import 'package:lotti/features/agents/service/task_agent_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart';
import 'package:lotti/features/agents/workflow/task_tool_dispatcher.dart';
import 'package:lotti/features/agents/workflow/template_evolution_workflow.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/database/embeddings_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/dashscope_inference_repository.dart';
import 'package:lotti/features/ai_chat/models/chat_session.dart';
import 'package:lotti/features/ai_chat/repository/chat_repository.dart';
import 'package:lotti/features/ai_chat/repository/task_summary_repository.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/habits/repository/habits_repository.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/services/label_assignment_processor.dart';
import 'package:lotti/features/ratings/repository/rating_repository.dart';
import 'package:lotti/features/speech/state/audio_player_controller.dart';
import 'package:lotti/features/sync/backfill/backfill_request_service.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/services/geolocation_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

/// Generic mock for drift Selectable queries used in widget tests.
class MockSelectable<T> extends Mock implements drift.Selectable<T> {
  MockSelectable(this._values);
  final List<T> _values;
  @override
  Future<List<T>> get() async => _values;
}

class MockTagsService extends Mock implements TagsService {}

MockTagsService mockTagsServiceWithTags(
  List<StoryTag> storyTags,
) {
  final mock = MockTagsService();

  return mock;
}

class MockJournalDb extends Mock implements JournalDb {
  Future<void> deleteLoggingDatabase() async {}

  @override
  Stream<Set<String>> watchActiveConfigFlagNames() {
    try {
      final result = super
          .noSuchMethod(Invocation.method(#watchActiveConfigFlagNames, []));
      if (result is Stream<Set<String>>) {
        return result;
      }
    } catch (_) {
      // ignore and fall back
    }
    return Stream<Set<String>>.value(<String>{}).asBroadcastStream();
  }

  @override
  Stream<bool> watchConfigFlag(String flagName) {
    try {
      final result =
          super.noSuchMethod(Invocation.method(#watchConfigFlag, [flagName]));
      if (result is Stream<bool>) {
        return result;
      }
    } catch (_) {
      // ignore and fall back
    }
    return Stream<bool>.value(false).asBroadcastStream();
  }
}

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {
  @override
  bool get showPrivateEntries {
    final result = super.noSuchMethod(Invocation.getter(#showPrivateEntries));
    if (result is bool) {
      return result;
    }
    return true;
  }
}

MockJournalDb mockJournalDbWithMeasurableTypes(
  List<MeasurableDataType> dataTypes,
) {
  final mock = MockJournalDb();
  when(mock.close).thenAnswer((_) async {});

  when(mock.getAllMeasurableDataTypes).thenAnswer((_) async => dataTypes);

  when(
    () => mock.getJournalEntities(
      types: any(named: 'types'),
      starredStatuses: any(named: 'starredStatuses'),
      privateStatuses: any(named: 'privateStatuses'),
      flaggedStatuses: any(named: 'flaggedStatuses'),
      ids: any(named: 'ids'),
      limit: any(named: 'limit'),
      offset: any(named: 'offset'),
      categoryIds: any(named: 'categoryIds'),
    ),
  ).thenAnswer((_) async => <JournalEntity>[]);

  when(
    () => mock.getTasks(
      ids: any(named: 'ids'),
      starredStatuses: any(named: 'starredStatuses'),
      taskStatuses: any(named: 'taskStatuses'),
      categoryIds: any(named: 'categoryIds'),
      labelIds: any(named: 'labelIds'),
      priorities: any(named: 'priorities'),
      limit: any(named: 'limit'),
      offset: any(named: 'offset'),
    ),
  ).thenAnswer((_) async => <JournalEntity>[]);

  for (final dataType in dataTypes) {
    when(() => mock.getMeasurableDataTypeById(dataType.id))
        .thenAnswer((_) async => dataType);
  }

  return mock;
}

MockJournalDb mockJournalDbWithHabits(
  List<HabitDefinition> habitDefinitions,
) {
  final mock = MockJournalDb();
  when(mock.close).thenAnswer((_) async {});

  when(mock.getAllHabitDefinitions).thenAnswer((_) async => habitDefinitions);

  // Default fallback for getHabitById
  when(() => mock.getHabitById(any())).thenAnswer((_) async => null);

  // Override with specific stubs for known habits
  for (final habitDefinition in habitDefinitions) {
    when(() => mock.getHabitById(habitDefinition.id))
        .thenAnswer((_) async => habitDefinition);
  }

  return mock;
}

MockJournalDb mockJournalDbWithSyncFlag({
  required bool enabled,
}) {
  final mock = MockJournalDb();
  when(mock.close).thenAnswer((_) async {});

  when(() => mock.watchConfigFlag(enableMatrixFlag)).thenAnswer(
    (_) => Stream<bool>.fromIterable([enabled]),
  );

  return mock;
}

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

class MockEmbeddingsDb extends Mock implements EmbeddingsDb {}

class MockFts5Db extends Mock implements Fts5Db {}

class MockTimeService extends Mock implements TimeService {}

class MockLoggingDb extends Mock implements LoggingDb {}

class MockLoggingService extends Mock implements LoggingService {}

class MockDomainLogger extends Mock implements DomainLogger {}

class MockEditorDb extends Mock implements EditorDb {}

class MockEditorStateService extends Mock implements EditorStateService {}

class MockLinkService extends Mock implements LinkService {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockHealthImport extends Mock implements HealthImport {}

class MockSecureStorage extends Mock implements SecureStorage {}

class MockVectorClockService extends Mock implements VectorClockService {}

class MockSettingsDb extends Mock implements SettingsDb {}

class MockAudioPlayerController extends Mock implements AudioPlayerController {}

class MockNavService extends Mock implements NavService {}

class MockNotificationService extends Mock implements NotificationService {}

class MockOutboxService extends Mock implements OutboxService {}

class FakeDashboardDefinition extends Fake implements DashboardDefinition {}

class FakeHabitDefinition extends Fake implements HabitDefinition {}

class FakeCategoryDefinition extends Fake implements CategoryDefinition {}

class FakeEntryText extends Fake implements EntryText {}

class FakeTaskData extends Fake implements TaskData {}

class FakeMetadata extends Fake implements Metadata {}

class FakeQuillController extends Fake implements QuillController {
  FakeQuillController({TextSelection? selection})
      : _selection = selection ?? const TextSelection.collapsed(offset: 0);

  TextSelection _selection;

  @override
  TextSelection get selection => _selection;

  set selection(TextSelection value) {
    _selection = value;
  }
}

class FakeJournalAudio extends Fake implements JournalAudio {}

class FakeMeasurementData extends Fake implements MeasurementData {}

class FakeHabitCompletionData extends Fake implements HabitCompletionData {}

class MockMaintenance extends Mock implements Maintenance {}

class MockMatrixService extends Mock implements MatrixService {}

class MockGeolocationService extends Mock implements GeolocationService {}

// --- Repository mocks (frequently duplicated inline) ---

class MockAgentRepository extends Mock implements AgentRepository {
  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) => action();
}

class MockAgentService extends Mock implements AgentService {}

class MockAgentSyncService extends Mock implements AgentSyncService {
  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) => action();
}

class MockSyncEventProcessor extends Mock implements SyncEventProcessor {}

class MockWakeOrchestrator extends Mock implements WakeOrchestrator {}

class MockTaskAgentService extends Mock implements TaskAgentService {}

class MockTaskAgentWorkflow extends Mock implements TaskAgentWorkflow {}

class MockTaskToolDispatcher extends Mock implements TaskToolDispatcher {}

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class MockJournalRepository extends Mock implements JournalRepository {}

class MockChecklistRepository extends Mock implements ChecklistRepository {}

class MockCategoryRepository extends Mock implements CategoryRepository {}

class MockLabelsRepository extends Mock implements LabelsRepository {}

class MockAiInputRepository extends Mock implements AiInputRepository {}

class MockChatRepository extends Mock implements ChatRepository {}

class MockTaskSummaryRepository extends Mock implements TaskSummaryRepository {}

class MockHabitsRepository extends Mock implements HabitsRepository {}

class MockRatingRepository extends Mock implements RatingRepository {}

class MockSyncDatabase extends Mock implements SyncDatabase {}

class MockBackfillRequestService extends Mock
    implements BackfillRequestService {}

class MockSyncSequenceLogService extends Mock
    implements SyncSequenceLogService {}

class MockCloudInferenceRepository extends Mock
    implements CloudInferenceRepository {}

class MockConversationManager extends Mock implements ConversationManager {}

class MockAgentToolExecutor extends Mock implements AgentToolExecutor {}

class MockAgentTemplateService extends Mock implements AgentTemplateService {}

class MockLabelAssignmentProcessor extends Mock
    implements LabelAssignmentProcessor {}

class MockTemplateEvolutionWorkflow extends Mock
    implements TemplateEvolutionWorkflow {}

class MockChangeSetConfirmationService extends Mock
    implements ChangeSetConfirmationService {}

class MockFeedbackExtractionService extends Mock
    implements FeedbackExtractionService {}

class MockImproverAgentService extends Mock implements ImproverAgentService {}

// --- Additional Fake classes ---

class FakeAiConfigPrompt extends Fake implements AiConfigPrompt {}

class FakeAiConfigModel extends Fake implements AiConfigModel {}

class FakeAiConfigInferenceProvider extends Fake
    implements AiConfigInferenceProvider {}

class FakeChatSession extends Fake implements ChatSession {}

class FakeChecklistItemData extends Fake implements ChecklistItemData {}

class MockDashScopeInferenceRepository extends Mock
    implements DashScopeInferenceRepository {}

class MockHttpClient extends Mock implements http.Client {}

class FakeBaseRequest extends Fake implements http.BaseRequest {}
