// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Optional UpdateNotifications service from GetIt.

@ProviderFor(maybeUpdateNotifications)
final maybeUpdateNotificationsProvider = MaybeUpdateNotificationsProvider._();

/// Optional UpdateNotifications service from GetIt.

final class MaybeUpdateNotificationsProvider
    extends
        $FunctionalProvider<
          UpdateNotifications?,
          UpdateNotifications?,
          UpdateNotifications?
        >
    with $Provider<UpdateNotifications?> {
  /// Optional UpdateNotifications service from GetIt.
  MaybeUpdateNotificationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'maybeUpdateNotificationsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$maybeUpdateNotificationsHash();

  @$internal
  @override
  $ProviderElement<UpdateNotifications?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  UpdateNotifications? create(Ref ref) {
    return maybeUpdateNotifications(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateNotifications? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateNotifications?>(value),
    );
  }
}

String _$maybeUpdateNotificationsHash() =>
    r'e8339e677470a5a0354952e365c467218396a8f5';

/// Required UpdateNotifications service for agent runtime wiring.

@ProviderFor(updateNotifications)
final updateNotificationsProvider = UpdateNotificationsProvider._();

/// Required UpdateNotifications service for agent runtime wiring.

final class UpdateNotificationsProvider
    extends
        $FunctionalProvider<
          UpdateNotifications,
          UpdateNotifications,
          UpdateNotifications
        >
    with $Provider<UpdateNotifications> {
  /// Required UpdateNotifications service for agent runtime wiring.
  UpdateNotificationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateNotificationsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateNotificationsHash();

  @$internal
  @override
  $ProviderElement<UpdateNotifications> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  UpdateNotifications create(Ref ref) {
    return updateNotifications(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateNotifications value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateNotifications>(value),
    );
  }
}

String _$updateNotificationsHash() =>
    r'97b9de5f312a3deff3ad088d92f3c1e227ad0755';

/// Optional sync processor dependency for cross-device agent wiring.

@ProviderFor(maybeSyncEventProcessor)
final maybeSyncEventProcessorProvider = MaybeSyncEventProcessorProvider._();

/// Optional sync processor dependency for cross-device agent wiring.

final class MaybeSyncEventProcessorProvider
    extends
        $FunctionalProvider<
          SyncEventProcessor?,
          SyncEventProcessor?,
          SyncEventProcessor?
        >
    with $Provider<SyncEventProcessor?> {
  /// Optional sync processor dependency for cross-device agent wiring.
  MaybeSyncEventProcessorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'maybeSyncEventProcessorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$maybeSyncEventProcessorHash();

  @$internal
  @override
  $ProviderElement<SyncEventProcessor?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SyncEventProcessor? create(Ref ref) {
    return maybeSyncEventProcessor(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncEventProcessor? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncEventProcessor?>(value),
    );
  }
}

String _$maybeSyncEventProcessorHash() =>
    r'efc9ebdc91606182cd75a614389472b9a9cff8d7';

/// Domain logger for agent runtime / workflow structured logging.
///
/// Uses `ref.listen` (not `ref.watch`) for config flag changes so that
/// toggling a logging domain mutates [DomainLogger.enabledDomains] in-place
/// without rebuilding the provider. This prevents a flag toggle from
/// cascading into orchestrator/workflow/service rebuilds and unintentionally
/// restarting the agent runtime.

@ProviderFor(domainLogger)
final domainLoggerProvider = DomainLoggerProvider._();

/// Domain logger for agent runtime / workflow structured logging.
///
/// Uses `ref.listen` (not `ref.watch`) for config flag changes so that
/// toggling a logging domain mutates [DomainLogger.enabledDomains] in-place
/// without rebuilding the provider. This prevents a flag toggle from
/// cascading into orchestrator/workflow/service rebuilds and unintentionally
/// restarting the agent runtime.

final class DomainLoggerProvider
    extends $FunctionalProvider<DomainLogger, DomainLogger, DomainLogger>
    with $Provider<DomainLogger> {
  /// Domain logger for agent runtime / workflow structured logging.
  ///
  /// Uses `ref.listen` (not `ref.watch`) for config flag changes so that
  /// toggling a logging domain mutates [DomainLogger.enabledDomains] in-place
  /// without rebuilding the provider. This prevents a flag toggle from
  /// cascading into orchestrator/workflow/service rebuilds and unintentionally
  /// restarting the agent runtime.
  DomainLoggerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'domainLoggerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$domainLoggerHash();

  @$internal
  @override
  $ProviderElement<DomainLogger> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DomainLogger create(Ref ref) {
    return domainLogger(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DomainLogger value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DomainLogger>(value),
    );
  }
}

String _$domainLoggerHash() => r'e203383757041025f853dec58f2f6c2a47af2693';

/// The agent database instance (singleton via GetIt).

@ProviderFor(agentDatabase)
final agentDatabaseProvider = AgentDatabaseProvider._();

/// The agent database instance (singleton via GetIt).

final class AgentDatabaseProvider
    extends $FunctionalProvider<AgentDatabase, AgentDatabase, AgentDatabase>
    with $Provider<AgentDatabase> {
  /// The agent database instance (singleton via GetIt).
  AgentDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'agentDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$agentDatabaseHash();

  @$internal
  @override
  $ProviderElement<AgentDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AgentDatabase create(Ref ref) {
    return agentDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AgentDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AgentDatabase>(value),
    );
  }
}

String _$agentDatabaseHash() => r'729f95bfb1e3c84ba20013ecef8ba281fc4fa713';

/// The agent repository wrapping the database.

@ProviderFor(agentRepository)
final agentRepositoryProvider = AgentRepositoryProvider._();

/// The agent repository wrapping the database.

final class AgentRepositoryProvider
    extends
        $FunctionalProvider<AgentRepository, AgentRepository, AgentRepository>
    with $Provider<AgentRepository> {
  /// The agent repository wrapping the database.
  AgentRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'agentRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$agentRepositoryHash();

  @$internal
  @override
  $ProviderElement<AgentRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AgentRepository create(Ref ref) {
    return agentRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AgentRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AgentRepository>(value),
    );
  }
}

String _$agentRepositoryHash() => r'9506f288080ed0c5c3a258a6d765c745f4d40258';

/// Sync-aware write wrapper for agent entities and links.

@ProviderFor(agentSyncService)
final agentSyncServiceProvider = AgentSyncServiceProvider._();

/// Sync-aware write wrapper for agent entities and links.

final class AgentSyncServiceProvider
    extends
        $FunctionalProvider<
          AgentSyncService,
          AgentSyncService,
          AgentSyncService
        >
    with $Provider<AgentSyncService> {
  /// Sync-aware write wrapper for agent entities and links.
  AgentSyncServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'agentSyncServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$agentSyncServiceHash();

  @$internal
  @override
  $ProviderElement<AgentSyncService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AgentSyncService create(Ref ref) {
    return agentSyncService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AgentSyncService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AgentSyncService>(value),
    );
  }
}

String _$agentSyncServiceHash() => r'04aecfa0882f6fb9c569cbaf39c826db2ab21553';

/// The in-memory wake queue.

@ProviderFor(wakeQueue)
final wakeQueueProvider = WakeQueueProvider._();

/// The in-memory wake queue.

final class WakeQueueProvider
    extends $FunctionalProvider<WakeQueue, WakeQueue, WakeQueue>
    with $Provider<WakeQueue> {
  /// The in-memory wake queue.
  WakeQueueProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wakeQueueProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wakeQueueHash();

  @$internal
  @override
  $ProviderElement<WakeQueue> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WakeQueue create(Ref ref) {
    return wakeQueue(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WakeQueue value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WakeQueue>(value),
    );
  }
}

String _$wakeQueueHash() => r'4c56660bf2e5b12d90237da678b50d84fed36f55';

/// The single-flight wake runner.

@ProviderFor(wakeRunner)
final wakeRunnerProvider = WakeRunnerProvider._();

/// The single-flight wake runner.

final class WakeRunnerProvider
    extends $FunctionalProvider<WakeRunner, WakeRunner, WakeRunner>
    with $Provider<WakeRunner> {
  /// The single-flight wake runner.
  WakeRunnerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wakeRunnerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wakeRunnerHash();

  @$internal
  @override
  $ProviderElement<WakeRunner> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WakeRunner create(Ref ref) {
    return wakeRunner(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WakeRunner value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WakeRunner>(value),
    );
  }
}

String _$wakeRunnerHash() => r'1136b7407940255b856748fe11f9a7b1c49c722c';

/// The wake orchestrator (notification listener + subscription matching).

@ProviderFor(wakeOrchestrator)
final wakeOrchestratorProvider = WakeOrchestratorProvider._();

/// The wake orchestrator (notification listener + subscription matching).

final class WakeOrchestratorProvider
    extends
        $FunctionalProvider<
          WakeOrchestrator,
          WakeOrchestrator,
          WakeOrchestrator
        >
    with $Provider<WakeOrchestrator> {
  /// The wake orchestrator (notification listener + subscription matching).
  WakeOrchestratorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wakeOrchestratorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wakeOrchestratorHash();

  @$internal
  @override
  $ProviderElement<WakeOrchestrator> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WakeOrchestrator create(Ref ref) {
    return wakeOrchestrator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WakeOrchestrator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WakeOrchestrator>(value),
    );
  }
}

String _$wakeOrchestratorHash() => r'1ed2401446f7f0631d79528e28b77392ceb6af6c';

/// The scheduled wake manager for time-based agent wakes.

@ProviderFor(scheduledWakeManager)
final scheduledWakeManagerProvider = ScheduledWakeManagerProvider._();

/// The scheduled wake manager for time-based agent wakes.

final class ScheduledWakeManagerProvider
    extends
        $FunctionalProvider<
          ScheduledWakeManager,
          ScheduledWakeManager,
          ScheduledWakeManager
        >
    with $Provider<ScheduledWakeManager> {
  /// The scheduled wake manager for time-based agent wakes.
  ScheduledWakeManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'scheduledWakeManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$scheduledWakeManagerHash();

  @$internal
  @override
  $ProviderElement<ScheduledWakeManager> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ScheduledWakeManager create(Ref ref) {
    return scheduledWakeManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ScheduledWakeManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ScheduledWakeManager>(value),
    );
  }
}

String _$scheduledWakeManagerHash() =>
    r'7e7cb29997d30e6caeca0349e0862bc4a86ba86d';

/// Tracks local project/task changes and marks project reports stale without
/// waking the project agent immediately.

@ProviderFor(projectActivityMonitor)
final projectActivityMonitorProvider = ProjectActivityMonitorProvider._();

/// Tracks local project/task changes and marks project reports stale without
/// waking the project agent immediately.

final class ProjectActivityMonitorProvider
    extends
        $FunctionalProvider<
          ProjectActivityMonitor,
          ProjectActivityMonitor,
          ProjectActivityMonitor
        >
    with $Provider<ProjectActivityMonitor> {
  /// Tracks local project/task changes and marks project reports stale without
  /// waking the project agent immediately.
  ProjectActivityMonitorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectActivityMonitorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectActivityMonitorHash();

  @$internal
  @override
  $ProviderElement<ProjectActivityMonitor> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProjectActivityMonitor create(Ref ref) {
    return projectActivityMonitor(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProjectActivityMonitor value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProjectActivityMonitor>(value),
    );
  }
}

String _$projectActivityMonitorHash() =>
    r'31ccbdd01c76e6ed185c4904ad42b37ca0c61053';

/// The high-level agent service.

@ProviderFor(agentService)
final agentServiceProvider = AgentServiceProvider._();

/// The high-level agent service.

final class AgentServiceProvider
    extends $FunctionalProvider<AgentService, AgentService, AgentService>
    with $Provider<AgentService> {
  /// The high-level agent service.
  AgentServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'agentServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$agentServiceHash();

  @$internal
  @override
  $ProviderElement<AgentService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AgentService create(Ref ref) {
    return agentService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AgentService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AgentService>(value),
    );
  }
}

String _$agentServiceHash() => r'faebbb3da6c43ad7767b1eccb45d190858c897f3';

/// The agent template service.

@ProviderFor(agentTemplateService)
final agentTemplateServiceProvider = AgentTemplateServiceProvider._();

/// The agent template service.

final class AgentTemplateServiceProvider
    extends
        $FunctionalProvider<
          AgentTemplateService,
          AgentTemplateService,
          AgentTemplateService
        >
    with $Provider<AgentTemplateService> {
  /// The agent template service.
  AgentTemplateServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'agentTemplateServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$agentTemplateServiceHash();

  @$internal
  @override
  $ProviderElement<AgentTemplateService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AgentTemplateService create(Ref ref) {
    return agentTemplateService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AgentTemplateService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AgentTemplateService>(value),
    );
  }
}

String _$agentTemplateServiceHash() =>
    r'104340be1f31a3ca3b8a0e5b3726a0084969940b';

/// The soul document service.

@ProviderFor(soulDocumentService)
final soulDocumentServiceProvider = SoulDocumentServiceProvider._();

/// The soul document service.

final class SoulDocumentServiceProvider
    extends
        $FunctionalProvider<
          SoulDocumentService,
          SoulDocumentService,
          SoulDocumentService
        >
    with $Provider<SoulDocumentService> {
  /// The soul document service.
  SoulDocumentServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'soulDocumentServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$soulDocumentServiceHash();

  @$internal
  @override
  $ProviderElement<SoulDocumentService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SoulDocumentService create(Ref ref) {
    return soulDocumentService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SoulDocumentService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SoulDocumentService>(value),
    );
  }
}

String _$soulDocumentServiceHash() =>
    r'eca54a9f9beab414e084c1a2a0f589a1474f0939';

/// The feedback extraction service.

@ProviderFor(feedbackExtractionService)
final feedbackExtractionServiceProvider = FeedbackExtractionServiceProvider._();

/// The feedback extraction service.

final class FeedbackExtractionServiceProvider
    extends
        $FunctionalProvider<
          FeedbackExtractionService,
          FeedbackExtractionService,
          FeedbackExtractionService
        >
    with $Provider<FeedbackExtractionService> {
  /// The feedback extraction service.
  FeedbackExtractionServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'feedbackExtractionServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$feedbackExtractionServiceHash();

  @$internal
  @override
  $ProviderElement<FeedbackExtractionService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FeedbackExtractionService create(Ref ref) {
    return feedbackExtractionService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FeedbackExtractionService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FeedbackExtractionService>(value),
    );
  }
}

String _$feedbackExtractionServiceHash() =>
    r'a5de05f01a608ba127a146f540f7ec515ec0cfd2';

/// The improver agent service.

@ProviderFor(improverAgentService)
final improverAgentServiceProvider = ImproverAgentServiceProvider._();

/// The improver agent service.

final class ImproverAgentServiceProvider
    extends
        $FunctionalProvider<
          ImproverAgentService,
          ImproverAgentService,
          ImproverAgentService
        >
    with $Provider<ImproverAgentService> {
  /// The improver agent service.
  ImproverAgentServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'improverAgentServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$improverAgentServiceHash();

  @$internal
  @override
  $ProviderElement<ImproverAgentService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ImproverAgentService create(Ref ref) {
    return improverAgentService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImproverAgentService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImproverAgentService>(value),
    );
  }
}

String _$improverAgentServiceHash() =>
    r'8dac9d73ab543b14fb416325781f6f07638fa37a';

/// Initializes the agent infrastructure when the `enableAgents` config flag
/// is enabled.
///
/// This provider:
/// 1. Watches the `enableAgents` config flag.
/// 2. When enabled, starts the [WakeOrchestrator] listening to
///    `UpdateNotifications.updateStream`.
/// 3. Restores task agent subscriptions from persisted state.
///
/// Must be watched (e.g. from a top-level widget or app initialization) to
/// take effect.

@ProviderFor(agentInitialization)
final agentInitializationProvider = AgentInitializationProvider._();

/// Initializes the agent infrastructure when the `enableAgents` config flag
/// is enabled.
///
/// This provider:
/// 1. Watches the `enableAgents` config flag.
/// 2. When enabled, starts the [WakeOrchestrator] listening to
///    `UpdateNotifications.updateStream`.
/// 3. Restores task agent subscriptions from persisted state.
///
/// Must be watched (e.g. from a top-level widget or app initialization) to
/// take effect.

final class AgentInitializationProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Initializes the agent infrastructure when the `enableAgents` config flag
  /// is enabled.
  ///
  /// This provider:
  /// 1. Watches the `enableAgents` config flag.
  /// 2. When enabled, starts the [WakeOrchestrator] listening to
  ///    `UpdateNotifications.updateStream`.
  /// 3. Restores task agent subscriptions from persisted state.
  ///
  /// Must be watched (e.g. from a top-level widget or app initialization) to
  /// take effect.
  AgentInitializationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'agentInitializationProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$agentInitializationHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return agentInitialization(ref);
  }
}

String _$agentInitializationHash() =>
    r'c788725c5510e8a9c7bc62413f3ccc9fcbd01921';
