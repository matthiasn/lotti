import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/agents/wake/wake_queue.dart';
import 'package:lotti/features/agents/wake/wake_runner.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

// ── Agent initialization provider test bench ────────────────────────────────

/// Collects all mocks needed for `agentInitializationProvider` tests and
/// provides a single [createContainer] method that wires them up.
///
/// Usage:
/// ```dart
/// late InitProviderBench bench;
///
/// setUp(() async {
///   bench = await InitProviderBench.create();
/// });
/// tearDown(tearDownTestGetIt);
/// ```
class InitProviderBench {
  InitProviderBench._({
    required this.mockService,
    required this.mockRepository,
    required this.mockOrchestrator,
    required this.mockWorkflow,
    required this.mockImproverWorkflow,
    required this.mockProjectWorkflow,
    required this.mockTaskAgentService,
    required this.mockProjectAgentService,
    required this.mockTemplateService,
    required this.mockAiConfigRepo,
    required this.mockScheduledWakeManager,
    required this.mockProjectActivityMonitor,
    required this.mockProjectRepository,
    required this.mockSoulDocumentService,
    required this.mockSyncService,
  });

  /// Creates a fully-stubbed bench.  Calls [setUpTestGetIt] internally, so
  /// callers must call [tearDownTestGetIt] in their own tearDown.
  static Future<InitProviderBench> create() async {
    await setUpTestGetIt();

    final bench = InitProviderBench._(
      mockService: MockAgentService(),
      mockRepository: MockAgentRepository(),
      mockOrchestrator: MockWakeOrchestrator(),
      mockWorkflow: MockTaskAgentWorkflow(),
      mockImproverWorkflow: MockImproverAgentWorkflow(),
      mockProjectWorkflow: MockProjectAgentWorkflow(),
      mockTaskAgentService: MockTaskAgentService(),
      mockProjectAgentService: MockProjectAgentService(),
      mockTemplateService: MockAgentTemplateService(),
      mockAiConfigRepo: MockAiConfigRepository(),
      mockScheduledWakeManager: MockScheduledWakeManager(),
      mockProjectActivityMonitor: MockProjectActivityMonitor(),
      mockProjectRepository: MockProjectRepository(),
      mockSoulDocumentService: MockSoulDocumentService(),
      mockSyncService: MockAgentSyncService(),
    ).._stubDefaults();
    return bench;
  }

  final MockAgentService mockService;
  final MockAgentRepository mockRepository;
  final MockWakeOrchestrator mockOrchestrator;
  final MockTaskAgentWorkflow mockWorkflow;
  final MockImproverAgentWorkflow mockImproverWorkflow;
  final MockProjectAgentWorkflow mockProjectWorkflow;
  final MockTaskAgentService mockTaskAgentService;
  final MockProjectAgentService mockProjectAgentService;
  final MockAgentTemplateService mockTemplateService;
  final MockAiConfigRepository mockAiConfigRepo;
  final MockScheduledWakeManager mockScheduledWakeManager;
  final MockProjectActivityMonitor mockProjectActivityMonitor;
  final MockProjectRepository mockProjectRepository;
  final MockSoulDocumentService mockSoulDocumentService;
  final MockAgentSyncService mockSyncService;

  void _stubDefaults() {
    when(() => mockOrchestrator.start(any())).thenAnswer((_) async {});
    when(mockOrchestrator.stop).thenAnswer((_) async {});
    when(mockTaskAgentService.restoreSubscriptions).thenAnswer((_) async {});
    when(mockProjectAgentService.restoreSubscriptions).thenAnswer((_) async {});
    when(mockTemplateService.seedDefaults).thenAnswer((_) async {});
    when(mockSoulDocumentService.seedDefaults).thenAnswer((_) async {});
    when(
      () => mockTemplateService.getTemplateForAgent(any()),
    ).thenAnswer((_) async => null);
    when(mockRepository.abandonOrphanedWakeRuns).thenAnswer((_) async => 0);
    when(
      () => mockRepository.getLinksFrom(any(), type: any(named: 'type')),
    ).thenAnswer((_) async => []);
    when(
      () => mockProjectRepository.getProjectForTask(any()),
    ).thenAnswer((_) async => null);
    when(mockScheduledWakeManager.start).thenReturn(null);
    when(mockScheduledWakeManager.stop).thenReturn(null);
    when(mockProjectActivityMonitor.start).thenReturn(null);
    when(mockProjectActivityMonitor.stop).thenAnswer((_) async {});
    // Profile seeding stubs.
    when(
      () => mockAiConfigRepo.getConfigById(any()),
    ).thenAnswer((_) async => null);
    when(() => mockAiConfigRepo.saveConfig(any())).thenAnswer((_) async {});
    // Model prepopulation stubs (backfill + stale removal).
    when(
      () => mockAiConfigRepo.getConfigsByType(any()),
    ).thenAnswer((_) async => []);
    when(
      () => mockAiConfigRepo.deleteConfig(any()),
    ).thenAnswer((_) async {});
  }

  /// Creates a [ProviderContainer] with all mocks wired in.
  ///
  /// When [enableAgents] is true, the `enableAgentsFlag` config flag will
  /// emit `true`.
  ProviderContainer createContainer({
    bool enableAgents = true,
  }) {
    final container = ProviderContainer(
      overrides: [
        agentServiceProvider.overrideWithValue(mockService),
        agentRepositoryProvider.overrideWithValue(mockRepository),
        wakeOrchestratorProvider.overrideWithValue(mockOrchestrator),
        taskAgentWorkflowProvider.overrideWithValue(mockWorkflow),
        improverAgentWorkflowProvider.overrideWithValue(mockImproverWorkflow),
        projectAgentWorkflowProvider.overrideWithValue(mockProjectWorkflow),
        taskAgentServiceProvider.overrideWithValue(mockTaskAgentService),
        projectAgentServiceProvider.overrideWithValue(
          mockProjectAgentService,
        ),
        projectRepositoryProvider.overrideWithValue(mockProjectRepository),
        agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
        soulDocumentServiceProvider.overrideWithValue(
          mockSoulDocumentService,
        ),
        agentSyncServiceProvider.overrideWithValue(mockSyncService),
        aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepo),
        scheduledWakeManagerProvider.overrideWithValue(
          mockScheduledWakeManager,
        ),
        projectActivityMonitorProvider.overrideWithValue(
          mockProjectActivityMonitor,
        ),
        configFlagProvider.overrideWith(
          (ref, flagName) => Stream.value(
            flagName == enableAgentsFlag && enableAgents,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Reads [agentInitializationProvider] with a keep-alive subscription.
  ///
  /// Returns the subscription so tests can close it explicitly if needed
  /// (e.g. to test disposal behaviour).
  Future<ProviderSubscription<AsyncValue<void>>> initAndSubscribe(
    ProviderContainer container,
  ) async {
    final sub = container.listen(
      agentInitializationProvider,
      (_, _) {},
    );
    addTearDown(sub.close);
    await container.read(agentInitializationProvider.future);
    return sub;
  }

  /// Captures the [WakeExecutor] set on the mock orchestrator.
  ///
  /// Must be called *before* reading the init provider so that the setter
  /// stub is already in place when the provider runs.
  WakeExecutorCapture captureWakeExecutor() {
    WakeExecutor? captured;
    when(() => mockOrchestrator.wakeExecutor = any()).thenAnswer((inv) {
      captured = inv.positionalArguments[0] as WakeExecutor?;
      return null;
    });
    return WakeExecutorCapture._(() => captured);
  }
}

/// Holds a lazy reference to the [WakeExecutor] captured during init.
class WakeExecutorCapture {
  WakeExecutorCapture._(this._getter);

  final WakeExecutor? Function() _getter;

  WakeExecutor get executor {
    final e = _getter();
    if (e == null) {
      throw StateError(
        'WakeExecutor has not been captured yet. '
        'Make sure agentInitializationProvider has been read.',
      );
    }
    return e;
  }
}

// ── Template / evolution container helpers ───────────────────────────────────

/// Creates a [ProviderContainer] wired for template-provider tests.
ProviderContainer createTemplateContainer({
  required MockAgentTemplateService mockTemplateService,
  required MockAgentService mockService,
  required MockAgentRepository mockRepository,
}) {
  final container = ProviderContainer(
    overrides: [
      agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
      agentServiceProvider.overrideWithValue(mockService),
      agentRepositoryProvider.overrideWithValue(mockRepository),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

// ── Update-stream refetch test helper ───────────────────────────────────────

/// Sets up [UpdateNotifications] in GetIt with a broadcast controller and
/// returns a [ProviderContainer] that includes the given extra overrides.
///
/// Callers should [addTearDown] the returned controller.
Future<
  ({ProviderContainer container, StreamController<Set<String>> controller})
>
setUpUpdateStreamTest({
  ProviderContainer Function()? containerFactory,
}) async {
  final controller = StreamController<Set<String>>.broadcast();
  addTearDown(controller.close);

  final mockNotifications = MockUpdateNotifications();
  when(
    () => mockNotifications.updateStream,
  ).thenAnswer((_) => controller.stream);
  when(
    () => mockNotifications.localUpdateStream,
  ).thenAnswer((_) => const Stream.empty());

  await getIt.reset();
  getIt.registerSingleton<UpdateNotifications>(mockNotifications);
  addTearDown(getIt.reset);

  final container = containerFactory?.call() ?? ProviderContainer();
  addTearDown(container.dispose);

  return (container: container, controller: controller);
}

// ── Token-usage container helpers ───────────────────────────────────────────

/// Creates a [ProviderContainer] with a mock repository pre-stubbed to return
/// [records] from `getTokenUsageForAgent` for the given [agentId].
ProviderContainer createAgentTokenContainer({
  required String agentId,
  required List<WakeTokenUsageEntity> records,
}) {
  final repo = MockAgentRepository();
  when(
    () => repo.getTokenUsageForAgent(agentId, limit: any(named: 'limit')),
  ).thenAnswer((_) async => records);

  final container = ProviderContainer(
    overrides: [
      agentRepositoryProvider.overrideWithValue(repo),
      agentUpdateStreamProvider.overrideWith(
        (ref, agentId) => const Stream.empty(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Creates a [ProviderContainer] with a mock repository pre-stubbed to return
/// [records] from `getTokenUsageForTemplate` for the given [templateId].
ProviderContainer createTemplateTokenContainer({
  required String templateId,
  required List<WakeTokenUsageEntity> records,
}) {
  final repo = MockAgentRepository();
  when(
    () => repo.getTokenUsageForTemplate(
      templateId,
      limit: any(named: 'limit'),
    ),
  ).thenAnswer((_) async => records);

  final container = ProviderContainer(
    overrides: [
      agentRepositoryProvider.overrideWithValue(repo),
      agentUpdateStreamProvider.overrideWith(
        (ref, agentId) => const Stream.empty(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

// ── Task content checker container ──────────────────────────────────────────

/// Creates a [ProviderContainer] suitable for testing the `taskContentChecker`
/// callback on [WakeOrchestrator].
ProviderContainer createCheckerContainer({
  required MockAgentRepository mockRepo,
  required MockJournalDb mockDb,
}) {
  final runner = WakeRunner();
  addTearDown(runner.dispose);
  final container = ProviderContainer(
    overrides: [
      agentRepositoryProvider.overrideWithValue(mockRepo),
      wakeQueueProvider.overrideWithValue(WakeQueue()),
      wakeRunnerProvider.overrideWithValue(runner),
      domainLoggerProvider.overrideWithValue(
        DomainLogger(loggingService: LoggingService()),
      ),
      journalDbProvider.overrideWithValue(mockDb),
    ],
  );
  addTearDown(container.dispose);
  return container;
}
