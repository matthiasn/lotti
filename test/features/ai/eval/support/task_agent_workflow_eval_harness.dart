import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/services/geolocation_service.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../helpers/path_provider.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/test_data/template_factories.dart';
import 'penguin_wake_scenarios.dart';
import 'penguin_wake_world_seed.dart';

/// The task-agent workflow standing on real databases instead of mocks.
///
/// The workflow eval used to stub twenty-four repository getters, which meant
/// it measured the model against a context the harness had written by hand:
/// `_taskDetailsJson` carried an empty checklist and a single log line
/// restating the description. Anything the real context builder does — folding
/// three checklists into their task, ordering linked notes by time, surfacing
/// logged time, carrying the previous wake's report — was invisible to it, so
/// the suite could not see a model fail at the thing the app actually asks of
/// it.
///
/// Here `JournalDb`, `AgentDatabase`, `PersistenceLogic`, the checklist, label
/// and journal repositories, and `AiInputRepository` are all real and in
/// memory. The only mocks left are the ones that would reach outside the
/// process — outbox, notifications, full-text search, geolocation — and
/// `AiConfigRepository`, which serves provider settings rather than storing
/// anything the model reads.
///
/// Because the context is now built rather than declared, a change to the real
/// prompt-assembly path shows up in the next eval run instead of silently
/// diverging from it.
class TaskAgentWorkflowEvalHarness {
  TaskAgentWorkflowEvalHarness._({
    required this.journalDb,
    required this.settingsDb,
    required this.agentDb,
    required this.agentRepository,
    required this.syncService,
    required this.templateService,
    required this.container,
    required this.world,
    required this.agentId,
    required this.threadId,
    required this.scenario,
  });

  final JournalDb journalDb;
  final SettingsDb settingsDb;
  final AgentDatabase agentDb;
  final AgentRepository agentRepository;
  final AgentSyncService syncService;
  final AgentTemplateService templateService;
  final ProviderContainer container;
  final PenguinWakeWorld world;
  final String agentId;
  final String threadId;
  final PenguinWakeScenario scenario;

  /// Builds the harness, seeds the wake world, and leaves everything ready for
  /// a [TaskAgentWorkflow] to run against it.
  ///
  /// [additionalGetItSetup] runs after the standard registrations, so a caller
  /// can replace one of them without reimplementing the rest.
  static Future<TaskAgentWorkflowEvalHarness> start({
    required ProviderContainer container,
    String agentId = 'agent-penguin-wake-eval',
    PenguinWakeScenarioId scenario = PenguinWakeScenarioId.requalification,
    String threadId = 'thread-penguin-wake-eval',
    void Function()? additionalGetItSetup,
  }) async {
    setFakeDocumentsPath();

    final settingsDb = SettingsDb(inMemoryDatabase: true);
    final journalDb = JournalDb(inMemoryDatabase: true);
    await initConfigFlags(journalDb, inMemoryDatabase: true);
    final agentDb = AgentDatabase(inMemoryDatabase: true);

    final notificationService = MockNotificationService();
    final updateNotifications = MockUpdateNotifications();
    final fts5Db = MockFts5Db();
    final outboxService = MockOutboxService();
    final navService = MockNavService();

    when(notificationService.updateBadge).thenAnswer((_) async {});
    when(
      () => notificationService.cancelNotification(any()),
    ).thenAnswer((_) async {});
    when(
      () => updateNotifications.updateStream,
    ).thenAnswer((_) => Stream<Set<String>>.fromIterable([]));
    when(
      () => fts5Db.insertText(any(), removePrevious: true),
    ).thenAnswer((_) async {});
    when(() => outboxService.enqueueMessage(any())).thenAnswer((_) async {});

    final documentsDirectory = await getApplicationDocumentsDirectory();
    await setUpTestGetIt(
      additionalSetup: () {
        // setUpTestGetIt already registers several of these with mocks. The
        // point of this harness is the real thing behind the same locator the
        // app reads from, so replace rather than register.
        void put<T extends Object>(T instance) {
          if (getIt.isRegistered<T>()) getIt.unregister<T>();
          getIt.registerSingleton<T>(instance);
        }

        put<UpdateNotifications>(updateNotifications);
        put<Directory>(documentsDirectory);
        put<SettingsDb>(settingsDb);
        put<Fts5Db>(fts5Db);
        put<JournalDb>(journalDb);
        put<AgentDatabase>(agentDb);
        put<OutboxService>(outboxService);
        put<NotificationService>(notificationService);
        put<VectorClockService>(VectorClockService());
        put<TimeService>(TimeService());
        put<NavService>(navService);
        put<EntitiesCacheService>(MockEntitiesCacheService());
        put<DomainLogger>(DomainLogger(loggingService: LoggingService()));
        put<MetadataService>(
          MetadataService(vectorClockService: getIt<VectorClockService>()),
        );
        put<GeolocationService>(MockGeolocationService());
        put<PersistenceLogic>(PersistenceLogic());
        additionalGetItSetup?.call();
      },
    );

    final agentRepository = AgentRepository(agentDb);
    final syncService = AgentSyncService(
      repository: agentRepository,
      outboxService: outboxService,
      vectorClockService: getIt<VectorClockService>(),
    );
    final templateService = AgentTemplateService(
      repository: agentRepository,
      syncService: syncService,
    );

    // The no-op wake is the world *before* the unblock: customs is still
    // holding and the closing note reports no new fact, so the prior report
    // remains accurate and a correct wake has nothing to do.
    final isNoOp = scenario == PenguinWakeScenarioId.noOp;
    final world = await seedPenguinWakeWorld(
      persistenceLogic: getIt<PersistenceLogic>(),
      checklistRepository: ChecklistRepository(),
      customsCleared: !isNoOp,
      finalNote: isNoOp ? penguinWakeNoOpNote : null,
      // The 07-24 extension request was granted in an earlier wake, so no
      // outstanding ask remains for the model to act on.
      dueDate: isNoOp ? penguinWakeExtendedDueDate : null,
    );

    // The seed is worth checking rather than assuming: a task without a
    // category silently loses checklist creation, and an eval that runs on an
    // empty context measures nothing while still producing a report.
    expect(
      await journalDb.journalEntityById(world.taskId),
      isNotNull,
      reason: 'the wake task must be stored before the workflow runs',
    );
    expect(
      world.checkedItemIds.length + world.pendingItemIds.length,
      14,
      reason: 'the seeded checklist must be the mid-sized one',
    );

    await _seedAgent(
      syncService: syncService,
      agentId: agentId,
      categoryId: world.categoryId,
    );

    // Every scenario but the original is a follow-up wake, which is the common
    // case in the app and the one the synthetic scenarios never covered.
    if (scenario != PenguinWakeScenarioId.requalification) {
      await seedPenguinWakePriorReport(
        syncService: syncService,
        agentId: agentId,
      );
    }

    if (scenario == PenguinWakeScenarioId.pendingProposal) {
      await seedPenguinWakePendingProposal(
        syncService: syncService,
        agentId: agentId,
        threadId: threadId,
      );
      // Assert the queue rather than trust it: if the proposal is not actually
      // pending, the model has nothing to be restrained about and the scenario
      // silently degrades into the ordinary unblocking wake.
      final pending = await agentRepository.getPendingChangeSets(
        agentId,
        taskId: penguinWakeTaskId,
      );
      expect(
        pending.expand((changeSet) => changeSet.items).map((i) => i.toolName),
        contains(TaskAgentToolNames.setTaskStatus),
        reason: 'the status proposal must be queued before the wake runs',
      );
    }

    return TaskAgentWorkflowEvalHarness._(
      journalDb: journalDb,
      settingsDb: settingsDb,
      agentDb: agentDb,
      agentRepository: agentRepository,
      syncService: syncService,
      templateService: templateService,
      container: container,
      world: world,
      agentId: agentId,
      threadId: threadId,
      scenario: PenguinWakeScenario.of(scenario),
    );
  }

  /// The real context builder, reading the seeded databases.
  AiInputRepository get aiInputRepository =>
      container.read(aiInputRepositoryProvider);

  /// The seeded agent, read back from the agent database.
  ///
  /// Read rather than kept from the seed, so a run works from the same row the
  /// app would load — if `upsertEntity` ever stopped persisting the identity,
  /// this fails here instead of surfacing as an unexplained wake failure.
  Future<AgentIdentityEntity> loadAgentIdentity() async {
    final entity = await agentRepository.getEntity(agentId);
    if (entity is! AgentIdentityEntity) {
      throw StateError(
        'Seeded agent $agentId did not read back as an identity: $entity',
      );
    }
    return entity;
  }

  /// The task context exactly as the app would assemble it for this wake.
  Future<String?> buildTaskContextJson() =>
      aiInputRepository.buildTaskDetailsJson(id: world.taskId);

  Future<void> dispose() async {
    await tearDownTestGetIt();
    await agentDb.close();
    await journalDb.close();
    await settingsDb.close();
  }

  static Future<void> _seedAgent({
    required AgentSyncService syncService,
    required String agentId,
    required String categoryId,
  }) async {
    final now = DateTime.utc(2026, 8, 5, 8, 30);
    const stateId = 'state-penguin-wake-eval';

    await syncService.upsertEntity(
      AgentDomainEntity.agent(
        id: agentId,
        agentId: agentId,
        kind: 'task_agent',
        displayName: 'Laura',
        lifecycle: AgentLifecycle.active,
        mode: AgentInteractionMode.autonomous,
        allowedCategoryIds: {categoryId},
        currentStateId: stateId,
        config: const AgentConfig(),
        createdAt: now,
        updatedAt: now,
        vectorClock: null,
      ),
    );

    await syncService.upsertEntity(
      AgentDomainEntity.agentState(
        id: stateId,
        agentId: agentId,
        revision: 1,
        slots: const AgentSlots(activeTaskId: penguinWakeTaskId),
        updatedAt: now,
        vectorClock: null,
      ),
    );
  }
}

/// A Laura template and version for the eval agent, so the workflow resolves a
/// real directive set rather than a stubbed one.
({AgentTemplateEntity template, AgentTemplateVersionEntity version})
buildEvalTemplate({required String profileId}) {
  return (
    template: makeTestTemplate(
      id: lauraTemplateId,
      agentId: lauraTemplateId,
      displayName: 'Laura',
      profileId: profileId,
      createdAt: DateTime(2026, 6, 21),
      updatedAt: DateTime(2026, 6, 21),
    ),
    version: makeTestTemplateVersion(
      id: 'version-penguin-wake-eval',
      agentId: lauraTemplateId,
      profileId: profileId,
    ),
  );
}
