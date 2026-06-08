import 'dart:async';

import 'package:beamer/beamer.dart';
import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:genui/genui.dart' as genui;
import 'package:http/http.dart' as http;
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:location/location.dart' as location_pkg;
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/database/notifications_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/service/agent_log_llm_summarizer.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/service/change_set_confirmation_service.dart';
import 'package:lotti/features/agents/service/feedback_extraction_service.dart';
import 'package:lotti/features/agents/service/improver_agent_service.dart';
import 'package:lotti/features/agents/service/project_activity_monitor.dart';
import 'package:lotti/features/agents/service/project_agent_service.dart';
import 'package:lotti/features/agents/service/project_recommendation_service.dart';
import 'package:lotti/features/agents/service/soul_document_service.dart';
import 'package:lotti/features/agents/service/task_agent_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/wake/scheduled_wake_manager.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/agents/workflow/improver_agent_workflow.dart';
import 'package:lotti/features/agents/workflow/project_agent_workflow.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart';
import 'package:lotti/features/agents/workflow/task_tool_dispatcher.dart';
import 'package:lotti/features/agents/workflow/template_evolution_workflow.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/database/objectbox_ops.dart';
import 'package:lotti/features/ai/helpers/automatic_image_analysis_trigger.dart';
import 'package:lotti/features/ai/helpers/profile_automation_resolver.dart';
import 'package:lotti/features/ai/helpers/prompt_builder_helper.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/dashscope_inference_repository.dart';
import 'package:lotti/features/ai/repository/gemini_inference_repository.dart';
import 'package:lotti/features/ai/repository/ollama_embedding_repository.dart';
import 'package:lotti/features/ai/repository/ollama_inference_repository.dart';
import 'package:lotti/features/ai/repository/task_summary_resolver.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
import 'package:lotti/features/ai/repository/vector_search_repository.dart';
import 'package:lotti/features/ai/service/embedding_service.dart';
import 'package:lotti/features/ai/services/auto_checklist_service.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/services/skill_inference_runner.dart';
import 'package:lotti/features/ai/util/profile_resolver.dart';
import 'package:lotti/features/ai_chat/models/chat_session.dart';
import 'package:lotti/features/ai_chat/repository/chat_repository.dart';
import 'package:lotti/features/ai_chat/repository/task_summary_repository.dart';
import 'package:lotti/features/ai_chat/services/audio_transcription_service.dart';
import 'package:lotti/features/ai_chat/services/realtime_transcription_service.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/daily_os/repository/day_plan_repository.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_knowledge_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_service.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_agent_workflow.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';
import 'package:lotti/features/habits/repository/habits_repository.dart';
import 'package:lotti/features/insights/repository/insights_repository.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/state/linked_from_entries_controller.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/services/label_assignment_processor.dart';
import 'package:lotti/features/notifications/repository/notification_repository.dart';
import 'package:lotti/features/notifications/scheduler/notification_scheduler.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/ratings/repository/rating_repository.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/features/speech/services/audio_waveform_service.dart';
import 'package:lotti/features/speech/services/speech_dictionary_service.dart';
import 'package:lotti/features/speech/state/audio_player_controller.dart';
import 'package:lotti/features/sync/backfill/backfill_request_service.dart';
import 'package:lotti/features/sync/backfill/backfill_response_handler.dart';
import 'package:lotti/features/sync/gateway/matrix_sdk_gateway.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/key_verification_runner.dart';
import 'package:lotti/features/sync/matrix/matrix_message_sender.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_consumer.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_processor.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_engine.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_lifecycle_coordinator.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/outbox/outbox_processor.dart';
import 'package:lotti/features/sync/outbox/outbox_repository.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/queue/bridge_coordinator.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/queue_pipeline_coordinator.dart';
import 'package:lotti/features/sync/repository/sync_maintenance_repository.dart';
import 'package:lotti/features/sync/repository/sync_node_profile_repository.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/services/sync_node_profile_broadcaster.dart';
import 'package:lotti/features/sync/services/synced_audio_inference_dispatcher.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/features/tasks/repository/task_progress_repository.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/features/tasks/state/linked_tasks_controller.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/features/whats_new/model/whats_new_release.dart';
import 'package:lotti/features/whats_new/repository/whats_new_service.dart';
import 'package:lotti/logic/create/entry_creation_service.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/services/geolocation_service.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/health_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/location.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/encryption/cross_signing.dart';
import 'package:matrix/encryption/key_verification_manager.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:record/record.dart' as record;
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Generic mock for drift Selectable queries used in widget tests.
class MockSelectable<T> extends Mock implements drift.Selectable<T> {
  MockSelectable(this._values);
  final List<T> _values;
  @override
  Future<List<T>> get() async => _values;
}

class MockJournalDb extends Mock implements JournalDb {
  Future<void> deleteLoggingDatabase() async {}

  @override
  Future<T> transaction<T>(
    Future<T> Function() action, {
    bool requireNew = false,
  }) => action();

  @override
  Stream<Set<String>> watchActiveConfigFlagNames() {
    try {
      final result = super.noSuchMethod(
        Invocation.method(#watchActiveConfigFlagNames, []),
      );
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
      final result = super.noSuchMethod(
        Invocation.method(#watchConfigFlag, [flagName]),
      );
      if (result is Stream<bool>) {
        return result;
      }
    } catch (_) {
      // ignore and fall back
    }

    return Stream<bool>.multi((controller) {
      StreamSubscription<Set<ConfigFlag>>? subscription;

      try {
        subscription = watchConfigFlags().listen(
          (flags) {
            controller.add(
              flags.any((flag) => flag.name == flagName && flag.status),
            );
          },
          onError: controller.addError,
          onDone: controller.close,
        );
      } catch (_) {
        controller
          ..add(false)
          ..close();
      }

      controller.onCancel = () => subscription?.cancel();
    }, isBroadcast: true);
  }
}

class MockRoom extends Mock implements Room {}

class MockTimeline extends Mock implements Timeline {}

class MockEvent extends Mock implements Event {
  MockEvent() {
    // Default stub so tests that don't care about originServerTs still get a
    // non-null DateTime — MatrixStreamSignalBinder reads it for Phase 0
    // `onTimelineEvent.ordering` diagnostics on every timeline event.
    when(() => originServerTs).thenReturn(DateTime(2026, 4, 20));
  }
}

class MockSurfaceController extends Mock implements genui.SurfaceController {}

class MockSurfaceContext extends Mock implements genui.SurfaceContext {}

class MockMatrixClient extends Mock implements Client {}

class MockLoginResponse extends Mock implements LoginResponse {}

class MockMatrixFile extends Mock implements MatrixFile {}

class MockGetVersionsResponse extends Mock implements GetVersionsResponse {}

class MockSyncMaintenanceRepository extends Mock
    implements SyncMaintenanceRepository {}

class MockSyncedAudioInferenceDispatcher extends Mock
    implements SyncedAudioInferenceDispatcher {}

class MockMatrixSyncGateway extends Mock implements MatrixSyncGateway {}

class MockMatrixMessageSender extends Mock implements MatrixMessageSender {}

class MockSentEventRegistry extends Mock implements SentEventRegistry {}

class MockMatrixSessionManager extends Mock implements MatrixSessionManager {}

class MockSyncRoomManager extends Mock implements SyncRoomManager {}

class MockMatrixStreamConsumer extends Mock implements MatrixStreamConsumer {}

class MockSyncEngine extends Mock implements SyncEngine {}

class MockSyncLifecycleCoordinator extends Mock
    implements SyncLifecycleCoordinator {}

class MockKeyVerification extends Mock implements KeyVerification {}

class MockKeyVerificationRunner extends Mock implements KeyVerificationRunner {}

class MockUserActivityGate extends Mock implements UserActivityGate {}

class MockOutboxRepository extends Mock implements OutboxRepository {}

class MockOutboxMessageSender extends Mock implements OutboxMessageSender {}

class MockOutboxProcessor extends Mock implements OutboxProcessor {}

class MockCachedLoginController extends Mock
    implements CachedStreamController<LoginState> {}

class MockMatrixDatabase extends Mock implements DatabaseApi {}

class MockDeviceKeys extends Mock implements DeviceKeys {}

/// Identical fake used by both verification-modal test files: a fixed
/// (emoji, name) pair for the SAS comparison row.
class FakeKeyVerificationEmoji extends Fake implements KeyVerificationEmoji {
  FakeKeyVerificationEmoji(this.emoji, this.name);

  @override
  final String emoji;

  @override
  final String name;
}

class MockDeviceKeysList extends Mock implements DeviceKeysList {}

class MockMatrixSdkGateway extends Mock implements MatrixSdkGateway {}

class MockSyncUpdate extends Mock implements SyncUpdate {}

class MockEncryption extends Mock implements Encryption {}

class MockCrossSigning extends Mock implements CrossSigning {}

class MockKeyVerificationManager extends Mock
    implements KeyVerificationManager {}

class MockStrippedStateEvent extends Mock implements StrippedStateEvent {}

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

class MockUserActivityService extends Mock implements UserActivityService {}

class RefreshBlockingShutdownAgent extends MockDayAgent {
  RefreshBlockingShutdownAgent()
    : super(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        draftLatency: Duration.zero,
        summarizeLatency: Duration.zero,
        clock: () => DateTime(2026, 5, 25, 9),
      );

  final pendingShutdownRefresh =
      Completer<
        ({
          List<CompletedItem> completed,
          List<CarryoverItem> carryover,
          ShutdownMetrics metrics,
        })
      >();
  int shutdownCalls = 0;

  @override
  Future<
    ({
      List<CompletedItem> completed,
      List<CarryoverItem> carryover,
      ShutdownMetrics metrics,
    })
  >
  surfaceShutdownData({required DateTime forDate}) {
    shutdownCalls += 1;
    if (shutdownCalls == 1) return super.surfaceShutdownData(forDate: forDate);
    return pendingShutdownRefresh.future;
  }

  @override
  Future<TomorrowNote> generateTomorrowNote({required DateTime forDate}) async {
    return const TomorrowNote(body: 'Tomorrow stays queued.', maturity: 1);
  }
}

class ThrowingShutdownAgent extends MockDayAgent {
  ThrowingShutdownAgent()
    : super(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        draftLatency: Duration.zero,
        summarizeLatency: Duration.zero,
        clock: () => DateTime(2026, 5, 25, 9),
      );

  @override
  Future<
    ({
      List<CompletedItem> completed,
      List<CarryoverItem> carryover,
      ShutdownMetrics metrics,
    })
  >
  surfaceShutdownData({required DateTime forDate}) async {
    throw StateError('shutdown unavailable');
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
    when(
      () => mock.getMeasurableDataTypeById(dataType.id),
    ).thenAnswer((_) async => dataType);
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
    when(
      () => mock.getHabitById(habitDefinition.id),
    ).thenAnswer((_) async => habitDefinition);
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

class MockEmbeddingStore extends Mock implements EmbeddingStore {}

class MockOllamaEmbeddingRepository extends Mock
    implements OllamaEmbeddingRepository {}

class MockHttpClient extends Mock implements http.Client {}

class MockFts5Db extends Mock implements Fts5Db {}

class MockTimeService extends Mock implements TimeService {}

class MockTaskProgressRepository extends Mock
    implements TaskProgressRepository {}

class MockAiConfigDb extends Mock implements AiConfigDb {}

class MockLoggingService extends Mock implements LoggingService {
  MockLoggingService() {
    registerFallbackValue(InsightLevel.info);
    registerFallbackValue(InsightType.log);
    registerFallbackValue(StackTrace.empty);
  }

  @override
  void captureException(
    dynamic exception, {
    required String domain,
    String? subDomain,
    dynamic stackTrace,
    InsightLevel level = InsightLevel.error,
    InsightType type = InsightType.exception,
  }) {
    super.noSuchMethod(
      Invocation.method(
        #captureException,
        <dynamic>[exception],
        <Symbol, dynamic>{
          #domain: domain,
          #subDomain: subDomain,
          #stackTrace: stackTrace,
          #level: level,
          #type: type,
        },
      ),
    );
  }
}

/// Stubs `LoggingService.captureEvent` and `captureException` on a
/// [MockLoggingService] so that tests don't crash on logging calls.
/// Import and call once in `setUp` or at the top of a `group`.
void stubLoggingService(MockLoggingService mock) {
  when(
    () => mock.captureEvent(
      any<Object>(),
      domain: any<String>(named: 'domain'),
      subDomain: any<String>(named: 'subDomain'),
      level: any(named: 'level'),
      type: any(named: 'type'),
    ),
  ).thenAnswer((_) {});
  when(
    () => mock.captureException(
      any<Object>(),
      domain: any<String>(named: 'domain'),
      subDomain: any<String>(named: 'subDomain'),
      stackTrace: any<StackTrace?>(named: 'stackTrace'),
      level: any(named: 'level'),
      type: any(named: 'type'),
    ),
  ).thenAnswer((_) {});
}

class MockDomainLogger extends Mock implements DomainLogger {
  MockDomainLogger() {
    // Fallbacks for `any()` matchers on log/error parameters. `LogDomain` is an
    // enum, so (unlike String) mocktail has no built-in fallback for it.
    registerFallbackValue(LogDomain.general);
    registerFallbackValue(InsightLevel.info);
    registerFallbackValue(StackTrace.empty);
  }
}

class MockEditorDb extends Mock implements EditorDb {}

class MockEditorStateService extends Mock implements EditorStateService {}

class MockLinkService extends Mock implements LinkService {}

class MockInsightsRepository extends Mock implements InsightsRepository {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {
  @override
  Stream<Set<String>> get updateStream {
    try {
      final result = super.noSuchMethod(Invocation.getter(#updateStream));
      if (result is Stream<Set<String>>) {
        return result;
      }
    } catch (_) {
      // ignore and fall back
    }
    return const Stream<Set<String>>.empty().asBroadcastStream();
  }
}

class MockHealthImport extends Mock implements HealthImport {}

class MockSecureStorage extends Mock implements SecureStorage {}

class MockVectorClockService extends Mock implements VectorClockService {
  /// Default passthrough so tests don't each have to stub the VC scope.
  ///
  /// Mirrors the production semantics closely enough for unit tests:
  /// - Runs the action.
  /// - If [commitWhen] is provided and returns false, no persistence is
  ///   exercised (mocktail mocks don't persist anyway, so the only observable
  ///   effect in tests is that `getNextVectorClock` stubs still fire).
  /// - Rethrows on action exceptions.
  ///
  /// Tests that want to assert on the scope wrapping can still use
  /// `when(() => mock.withVcScope(...))` — overriding this default.
  @override
  Future<T> withVcScope<T>(
    Future<T> Function() action, {
    bool Function(T result)? commitWhen,
  }) {
    return action();
  }
}

class MockSettingsDb extends Mock implements SettingsDb {}

class MockSyncNodeProfileRepository extends Mock
    implements SyncNodeProfileRepository {}

class MockAudioPlayerController extends Mock implements AudioPlayerController {}

class MockAudioWaveformService extends Mock implements AudioWaveformService {}

class MockAudioRecorderRepository extends Mock
    implements AudioRecorderRepository {}

class MockAudioRecorder extends Mock implements record.AudioRecorder {}

class MockAudioTranscriptionService extends Mock
    implements AudioTranscriptionService {}

class MockRealtimeTranscriptionService extends Mock
    implements RealtimeTranscriptionService {}

class MockNavService extends Mock implements NavService {}

/// Recording [BeamerDelegate] for navigation tests — captures every
/// `beamToNamed` URI instead of routing anywhere.
class RecordingBeamerDelegate extends BeamerDelegate {
  RecordingBeamerDelegate()
    : super(
        locationBuilder: RoutesLocationBuilder(
          routes: {'*': (_, _, _) => const SizedBox.shrink()},
        ).call,
      );

  final List<String> beamed = <String>[];

  @override
  void beamToNamed(
    String uri, {
    Object? data,
    Object? routeState,
    bool beamBackOnPop = false,
    bool popBeamLocationOnPop = false,
    bool stacked = true,
    bool replaceRouteInformation = false,
    TransitionDelegate<dynamic>? transitionDelegate,
    String? popToNamed,
  }) {
    beamed.add(uri);
  }
}

/// Recording variant of [MockNavService]: captures beamToNamed paths so
/// tests can assert navigation without stubbing.
class RecordingMockNavService extends Mock implements NavService {
  final List<String> navigationHistory = [];

  @override
  void beamToNamed(String path, {Object? data}) {
    navigationHistory.add(path);
  }
}

class MockNotificationService extends Mock implements NotificationService {}

class MockNotificationsDb extends Mock implements NotificationsDb {}

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

class MockNotificationScheduler extends Mock implements NotificationScheduler {}

class MockOutboxService extends Mock implements OutboxService {}

class FakeDashboardDefinition extends Fake implements DashboardDefinition {
  FakeDashboardDefinition({this.id = 'fake-dashboard-id', this.deletedAt});
  @override
  final String id;
  @override
  final DateTime? deletedAt;
}

class FakeHabitDefinition extends Fake implements HabitDefinition {
  FakeHabitDefinition({this.id = 'fake-habit-id', this.deletedAt});
  @override
  final String id;
  @override
  final DateTime? deletedAt;
}

class FakeCategoryDefinition extends Fake implements CategoryDefinition {
  FakeCategoryDefinition({this.id = 'fake-category-id', this.deletedAt});
  @override
  final String id;
  @override
  final DateTime? deletedAt;
}

class FakeMeasurableDataType extends Fake implements MeasurableDataType {
  FakeMeasurableDataType({this.id = 'fake-measurable-id', this.deletedAt});
  @override
  final String id;
  @override
  final DateTime? deletedAt;
}

class FakeEntryText extends Fake implements EntryText {}

class FakeEventData extends Fake implements EventData {}

class FakeTaskData extends Fake implements TaskData {}

/// Task stand-in serving a fixed [data] payload and deterministic metadata —
/// for tests that only read `data`/`meta`.
class MockTask extends Mock implements Task {
  MockTask({this.id = 'test-task-id', TaskData? data, DateTime? date})
    // ignore: prefer_initializing_formals
    : _data = data,
      _date = date ?? DateTime(2024, 3, 15);

  final String id;
  final TaskData? _data;
  final DateTime _date;

  @override
  TaskData get data =>
      _data ??
      (throw StateError(
        'MockTask.data was read but no TaskData was passed to the '
        'constructor — provide one via MockTask(data: ...).',
      ));

  @override
  Metadata get meta => Metadata(
    id: id,
    createdAt: _date,
    updatedAt: _date,
    dateFrom: _date,
    dateTo: _date,
  );
}

class FakeMetadata extends Fake implements Metadata {}

class FakeWhatsNewRelease extends Fake implements WhatsNewRelease {}

class MockWhatsNewService extends Mock implements WhatsNewService {}

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

/// Fallback for the MediaKit [Playable] (e.g. `Media`) passed to
/// `Player.open(...)`. Register via `registerFallbackValue(FakePlayable())`.
class FakePlayable extends Fake implements Playable {}

class FakeMeasurementData extends Fake implements MeasurementData {}

class FakeHabitCompletionData extends Fake implements HabitCompletionData {}

class MockMaintenance extends Mock implements Maintenance {}

class MockMatrixService extends Mock implements MatrixService {}

class MockGeolocationService extends Mock implements GeolocationService {}

/// Mock for the `location` plugin's device-location API.
class MockLocation extends Mock implements location_pkg.Location {}

/// Mock for a single `location` plugin reading.
class MockLocationData extends Mock implements location_pkg.LocationData {}

class MockMetadataService extends Mock implements MetadataService {}

class MockDeviceLocation extends Mock implements DeviceLocation {}

class MockHealthService extends Mock implements HealthService {}

class MockDeviceInfoPlugin extends Mock implements DeviceInfoPlugin {}

class MockBuildContext extends Mock implements BuildContext {}

class FakeQuantitativeData extends Fake implements CumulativeQuantityData {}

class FakeDiscreteQuantityData extends Fake implements DiscreteQuantityData {}

class FakeWorkoutData extends Fake implements WorkoutData {}

class FakeJournalImage extends Fake implements JournalImage {}

/// Drop-item fake backed by an [XFile], for desktop drag-and-drop import
/// tests.
class FakeDropItem extends Fake implements DropItem {
  FakeDropItem(this._xFile);

  final XFile _xFile;

  @override
  String get name => _xFile.name;

  @override
  String get path => _xFile.path;

  @override
  Future<DateTime> lastModified() => _xFile.lastModified();
}

// --- Repository mocks (frequently duplicated inline) ---

class MockAgentRepository extends Mock implements AgentRepository {
  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) => action();
}

class MockAgentService extends Mock implements AgentService {}

class MockAgentSyncService extends Mock implements AgentSyncService {
  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) => action();

  /// Default local host so tests that exercise counter (G-counter) increments
  /// don't each have to stub it. A fixed value is fine — workflow tests assert
  /// on the resulting counter value, not on which host was attributed.
  @override
  Future<String> localHost() async => 'test-host';
}

/// Stubs [MockAgentSyncService.appendMilestone] to a no-op so workflow/service
/// tests that don't assert on milestone emission don't trip over the unstubbed
/// mock (the watermark markers from PR 4, B2 are fire-and-forget here). Calls
/// are still recorded, so a test can `verify(() => mock.appendMilestone(...))`.
/// Requires the `AgentMilestone` fallback from `registerAllFallbackValues()`.
void stubAppendMilestone(MockAgentSyncService mock) {
  when(
    () => mock.appendMilestone(
      agentId: any(named: 'agentId'),
      milestone: any(named: 'milestone'),
      createdAt: any(named: 'createdAt'),
      threadId: any(named: 'threadId'),
      runKey: any(named: 'runKey'),
    ),
  ).thenAnswer((_) async {});
}

/// Verifies [MockAgentSyncService.appendMilestone] was called and returns the
/// captured `milestone` arguments, in call order — so a test can assert which
/// watermark markers (PR 4, B2) a wake emitted (e.g. `contains(wakeCompleted)`).
List<Object?> capturedMilestones(MockAgentSyncService mock) => verify(
  () => mock.appendMilestone(
    agentId: any(named: 'agentId'),
    milestone: captureAny(named: 'milestone'),
    createdAt: any(named: 'createdAt'),
    threadId: any(named: 'threadId'),
    runKey: any(named: 'runKey'),
  ),
).captured;

/// Stubs [MockAgentSyncService.reconciledAgentState] (the wake-start read
/// cutover, PR 4 B6) to delegate to the repository's raw `getAgentState`. In
/// unit tests there is no divergence, so the reconcile is the identity — this
/// lets workflow tests keep stubbing `getAgentState` while the wake reads the
/// reconciled state. The real reconcile + persist + convergence is covered by
/// the projection sim tests.
void stubReconciledAgentState(
  MockAgentSyncService sync,
  MockAgentRepository repo,
) {
  when(() => sync.reconciledAgentState(any())).thenAnswer(
    (invocation) =>
        repo.getAgentState(invocation.positionalArguments.single as String),
  );
}

class MockSoulDocumentService extends Mock implements SoulDocumentService {}

class MockBackfillResponseHandler extends Mock
    implements BackfillResponseHandler {}

class MockSyncEventProcessor extends Mock implements SyncEventProcessor {
  // Default null/no-op so tests that stub only `process` keep working: a
  // null prepare leaves no slot in the pipeline's pre-pass and the
  // in-transaction fallback calls `process` as before. Tests exercising the
  // new prepare/apply split use a local mock and stub both via `when(...)`.
  @override
  Future<PreparedSyncEvent?> prepare({required Event event}) async => null;

  @override
  Future<SyncApplyDiagnostics?> apply({
    required PreparedSyncEvent prepared,
    required JournalDb journalDb,
  }) async => null;
}

class MockMatrixStreamProcessor extends Mock implements MatrixStreamProcessor {}

class MockJournalEntityLoader extends Mock implements SyncJournalEntityLoader {}

class MockSyncNodeProfileBroadcaster extends Mock
    implements SyncNodeProfileBroadcaster {}

class MockWakeOrchestrator extends Mock implements WakeOrchestrator {}

class MockTaskAgentService extends Mock implements TaskAgentService {}

class MockTaskAgentWorkflow extends Mock implements TaskAgentWorkflow {}

class MockTaskToolDispatcher extends Mock implements TaskToolDispatcher {}

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class MockJournalRepository extends Mock implements JournalRepository {}

class MockChecklistRepository extends Mock implements ChecklistRepository {}

class MockChecklistController extends Mock implements ChecklistController {}

class MockCategoryRepository extends Mock implements CategoryRepository {}

class MockLabelsRepository extends Mock implements LabelsRepository {}

class MockAiInputRepository extends Mock implements AiInputRepository {}

class MockChatRepository extends Mock implements ChatRepository {}

class MockTaskSummaryRepository extends Mock implements TaskSummaryRepository {}

class MockTaskSummaryResolver extends Mock implements TaskSummaryResolver {}

class MockDayPlanRepository extends Mock implements DayPlanRepository {}

class MockHabitsRepository extends Mock implements HabitsRepository {}

class MockRatingRepository extends Mock implements RatingRepository {}

class MockProjectRepository extends Mock implements ProjectRepository {}

class MockSyncDatabase extends Mock implements SyncDatabase {}

class MockAgentDatabase extends Mock implements AgentDatabase {}

class MockBackfillRequestService extends Mock
    implements BackfillRequestService {}

class MockSyncSequenceLogService extends Mock
    implements SyncSequenceLogService {}

class MockInboundQueue extends Mock implements InboundQueue {}

class MockBridgeCoordinator extends Mock implements BridgeCoordinator {}

class MockPreparedSyncEvent extends Mock implements PreparedSyncEvent {}

/// Unlike [MockSyncEventProcessor] — whose `prepare`/`apply` are concrete
/// no-op overrides and therefore NOT interceptable by `when(...)` — this is a
/// plain mock for tests that need to stub the prepare/apply split.
class MockStubbableSyncEventProcessor extends Mock
    implements SyncEventProcessor {}

class MockQueuePipelineCoordinator extends Mock
    implements QueuePipelineCoordinator {}

class MockCloudInferenceRepository extends Mock
    implements CloudInferenceRepository {}

class MockUnifiedAiInferenceRepository extends Mock
    implements UnifiedAiInferenceRepository {}

class MockConversationManager extends Mock implements ConversationManager {}

class MockConversationStrategy extends Mock implements ConversationStrategy {}

class MockOllamaInferenceRepository extends Mock
    implements OllamaInferenceRepository {}

class MockOpenAIClient extends Mock implements OpenAIClient {}

class MockGeminiInferenceRepository extends Mock
    implements GeminiInferenceRepository {}

class MockAgentToolExecutor extends Mock implements AgentToolExecutor {}

class MockAgentTemplateService extends Mock implements AgentTemplateService {}

class MockAgentLogLlmSummarizer extends Mock implements AgentLogLlmSummarizer {}

class MockLabelAssignmentProcessor extends Mock
    implements LabelAssignmentProcessor {}

class MockTemplateEvolutionWorkflow extends Mock
    implements TemplateEvolutionWorkflow {}

class MockChangeSetConfirmationService extends Mock
    implements ChangeSetConfirmationService {}

class MockFeedbackExtractionService extends Mock
    implements FeedbackExtractionService {}

class MockImproverAgentService extends Mock implements ImproverAgentService {}

class MockImproverAgentWorkflow extends Mock implements ImproverAgentWorkflow {}

class MockProjectAgentService extends Mock implements ProjectAgentService {}

class MockProjectRecommendationService extends Mock
    implements ProjectRecommendationService {}

class MockProjectAgentWorkflow extends Mock implements ProjectAgentWorkflow {}

class MockDayAgentService extends Mock implements DayAgentService {}

class MockDayAgentCaptureService extends Mock
    implements DayAgentCaptureService {}

class MockDayAgentPlanService extends Mock implements DayAgentPlanService {}

class MockDayAgentKnowledgeService extends Mock
    implements DayAgentKnowledgeService {}

class MockDayAgentWorkflow extends Mock implements DayAgentWorkflow {}

class MockScheduledWakeManager extends Mock implements ScheduledWakeManager {}

class MockProjectActivityMonitor extends Mock
    implements ProjectActivityMonitor {}

// --- Additional Fake classes ---

class FakeAiConfigPrompt extends Fake implements AiConfigPrompt {}

class FakeAiConfigModel extends Fake implements AiConfigModel {}

class FakeAiConfigInferenceProvider extends Fake
    implements AiConfigInferenceProvider {}

class FakeChatSession extends Fake implements ChatSession {}

class FakeChecklistData extends Fake implements ChecklistData {}

class FakeChecklistItemData extends Fake implements ChecklistItemData {}

class MockDashScopeInferenceRepository extends Mock
    implements DashScopeInferenceRepository {}

class MockVectorSearchRepository extends Mock
    implements VectorSearchRepository {}

class MockAutoChecklistService extends Mock implements AutoChecklistService {}

class FakeBaseRequest extends Fake implements http.BaseRequest {}

class FakeRequest extends Fake implements http.Request {}

class MockObjectBoxOps extends Mock implements ObjectBoxOps {}

class MockEmbeddingService extends Mock implements EmbeddingService {}

class MockProfileResolver extends Mock implements ProfileResolver {}

class MockProfileAutomationResolver extends Mock
    implements ProfileAutomationResolver {}

class MockProfileAutomationService extends Mock
    implements ProfileAutomationService {}

class MockSkillInferenceRunner extends Mock implements SkillInferenceRunner {}

class MockAutomaticImageAnalysisTrigger extends Mock
    implements AutomaticImageAnalysisTrigger {}

class MockPromptBuilderHelper extends Mock implements PromptBuilderHelper {}

class MockPagingController extends Mock
    implements PagingController<int, JournalEntity> {}

class MockUrlLauncher extends Mock
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {}

class FakeLaunchOptions extends Fake implements LaunchOptions {}

class MockLinkedFromEntriesController extends LinkedFromEntriesController {
  MockLinkedFromEntriesController(this._entities);
  final List<JournalEntity> _entities;

  @override
  Future<List<JournalEntity>> build({required String id}) async => _entities;
}

class MockLinkedTasksControllerManageMode extends LinkedTasksController {
  @override
  LinkedTasksState build({required String taskId}) {
    return const LinkedTasksState(manageMode: true);
  }
}

class MockLinkedEntriesController extends LinkedEntriesController {
  MockLinkedEntriesController([this._links = const []]);
  final List<EntryLink> _links;

  @override
  Future<List<EntryLink>> build({required String id}) async => _links;
}

class MockEntryCreationService extends Mock implements EntryCreationService {}

class MockSpeechDictionaryService extends Mock
    implements SpeechDictionaryService {}

/// Mock for the MediaKit [Player] used by audio duration extraction and the
/// speech recorder.
class MockPlayer extends Mock implements Player {}

class MockPlayerState extends Mock implements PlayerState {}

/// Mock for the MediaKit [PlayerStream] exposing event streams such as
/// `duration`.
class MockPlayerStream extends Mock implements PlayerStream {}

class MockQueryExecutor extends Mock implements drift.QueryExecutor {}

class MockPathProviderPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {}
