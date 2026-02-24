// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The agent database instance (lazy singleton).

@ProviderFor(agentDatabase)
final agentDatabaseProvider = AgentDatabaseProvider._();

/// The agent database instance (lazy singleton).

final class AgentDatabaseProvider
    extends $FunctionalProvider<AgentDatabase, AgentDatabase, AgentDatabase>
    with $Provider<AgentDatabase> {
  /// The agent database instance (lazy singleton).
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

String _$agentDatabaseHash() => r'32b4e998e7242188077d24ec885585cafd2ae33c';

/// The agent repository wrapping the database.

@ProviderFor(agentRepository)
final agentRepositoryProvider = AgentRepositoryProvider._();

/// The agent repository wrapping the database.

final class AgentRepositoryProvider extends $FunctionalProvider<AgentRepository,
    AgentRepository, AgentRepository> with $Provider<AgentRepository> {
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

final class AgentSyncServiceProvider extends $FunctionalProvider<
    AgentSyncService,
    AgentSyncService,
    AgentSyncService> with $Provider<AgentSyncService> {
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

String _$agentSyncServiceHash() => r'6f6862cbc8b443e39b34eab5d5fe38a57480ea5e';

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

/// Whether a specific agent is currently running.
///
/// Yields the initial synchronous value, then updates reactively whenever the
/// agent starts or stops running.

@ProviderFor(agentIsRunning)
final agentIsRunningProvider = AgentIsRunningFamily._();

/// Whether a specific agent is currently running.
///
/// Yields the initial synchronous value, then updates reactively whenever the
/// agent starts or stops running.

final class AgentIsRunningProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// Whether a specific agent is currently running.
  ///
  /// Yields the initial synchronous value, then updates reactively whenever the
  /// agent starts or stops running.
  AgentIsRunningProvider._(
      {required AgentIsRunningFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'agentIsRunningProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$agentIsRunningHash();

  @override
  String toString() {
    return r'agentIsRunningProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    final argument = this.argument as String;
    return agentIsRunning(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AgentIsRunningProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$agentIsRunningHash() => r'7b5990fac89b7c820ed6bca412aabf16f7302aa4';

/// Whether a specific agent is currently running.
///
/// Yields the initial synchronous value, then updates reactively whenever the
/// agent starts or stops running.

final class AgentIsRunningFamily extends $Family
    with $FunctionalFamilyOverride<Stream<bool>, String> {
  AgentIsRunningFamily._()
      : super(
          retry: null,
          name: r'agentIsRunningProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Whether a specific agent is currently running.
  ///
  /// Yields the initial synchronous value, then updates reactively whenever the
  /// agent starts or stops running.

  AgentIsRunningProvider call(
    String agentId,
  ) =>
      AgentIsRunningProvider._(argument: agentId, from: this);

  @override
  String toString() => r'agentIsRunningProvider';
}

/// Stream that emits when a specific agent's data changes (from sync or local
/// wake). Detail providers watch this to self-invalidate.
///
/// Returns the raw `Set<String>` from `UpdateNotifications` rather than `void`
/// because Riverpod deduplicates `AsyncData` values using `==`. Since
/// `null == null`, a `Stream<void>` would only notify watchers on the first
/// emission. Each `Set` instance is identity-distinct, ensuring every
/// notification triggers a provider rebuild.

@ProviderFor(agentUpdateStream)
final agentUpdateStreamProvider = AgentUpdateStreamFamily._();

/// Stream that emits when a specific agent's data changes (from sync or local
/// wake). Detail providers watch this to self-invalidate.
///
/// Returns the raw `Set<String>` from `UpdateNotifications` rather than `void`
/// because Riverpod deduplicates `AsyncData` values using `==`. Since
/// `null == null`, a `Stream<void>` would only notify watchers on the first
/// emission. Each `Set` instance is identity-distinct, ensuring every
/// notification triggers a provider rebuild.

final class AgentUpdateStreamProvider extends $FunctionalProvider<
        AsyncValue<Set<String>>, Set<String>, Stream<Set<String>>>
    with $FutureModifier<Set<String>>, $StreamProvider<Set<String>> {
  /// Stream that emits when a specific agent's data changes (from sync or local
  /// wake). Detail providers watch this to self-invalidate.
  ///
  /// Returns the raw `Set<String>` from `UpdateNotifications` rather than `void`
  /// because Riverpod deduplicates `AsyncData` values using `==`. Since
  /// `null == null`, a `Stream<void>` would only notify watchers on the first
  /// emission. Each `Set` instance is identity-distinct, ensuring every
  /// notification triggers a provider rebuild.
  AgentUpdateStreamProvider._(
      {required AgentUpdateStreamFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'agentUpdateStreamProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$agentUpdateStreamHash();

  @override
  String toString() {
    return r'agentUpdateStreamProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Set<String>> $createElement(
          $ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Set<String>> create(Ref ref) {
    final argument = this.argument as String;
    return agentUpdateStream(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AgentUpdateStreamProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$agentUpdateStreamHash() => r'b2ad428362e088c14beb6e64ff9b9dc5745ef8f4';

/// Stream that emits when a specific agent's data changes (from sync or local
/// wake). Detail providers watch this to self-invalidate.
///
/// Returns the raw `Set<String>` from `UpdateNotifications` rather than `void`
/// because Riverpod deduplicates `AsyncData` values using `==`. Since
/// `null == null`, a `Stream<void>` would only notify watchers on the first
/// emission. Each `Set` instance is identity-distinct, ensuring every
/// notification triggers a provider rebuild.

final class AgentUpdateStreamFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Set<String>>, String> {
  AgentUpdateStreamFamily._()
      : super(
          retry: null,
          name: r'agentUpdateStreamProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Stream that emits when a specific agent's data changes (from sync or local
  /// wake). Detail providers watch this to self-invalidate.
  ///
  /// Returns the raw `Set<String>` from `UpdateNotifications` rather than `void`
  /// because Riverpod deduplicates `AsyncData` values using `==`. Since
  /// `null == null`, a `Stream<void>` would only notify watchers on the first
  /// emission. Each `Set` instance is identity-distinct, ensuring every
  /// notification triggers a provider rebuild.

  AgentUpdateStreamProvider call(
    String agentId,
  ) =>
      AgentUpdateStreamProvider._(argument: agentId, from: this);

  @override
  String toString() => r'agentUpdateStreamProvider';
}

/// The wake orchestrator (notification listener + subscription matching).

@ProviderFor(wakeOrchestrator)
final wakeOrchestratorProvider = WakeOrchestratorProvider._();

/// The wake orchestrator (notification listener + subscription matching).

final class WakeOrchestratorProvider extends $FunctionalProvider<
    WakeOrchestrator,
    WakeOrchestrator,
    WakeOrchestrator> with $Provider<WakeOrchestrator> {
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

String _$wakeOrchestratorHash() => r'7e10bc88a2db8d318b6a094902ba52b1edf65bde';

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

String _$agentServiceHash() => r'6009a2c80577a05731e21a2cf7a569111cb42603';

/// The agent template service.

@ProviderFor(agentTemplateService)
final agentTemplateServiceProvider = AgentTemplateServiceProvider._();

/// The agent template service.

final class AgentTemplateServiceProvider extends $FunctionalProvider<
    AgentTemplateService,
    AgentTemplateService,
    AgentTemplateService> with $Provider<AgentTemplateService> {
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
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

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

/// List all non-deleted agent templates.

@ProviderFor(agentTemplates)
final agentTemplatesProvider = AgentTemplatesProvider._();

/// List all non-deleted agent templates.

final class AgentTemplatesProvider extends $FunctionalProvider<
        AsyncValue<List<AgentDomainEntity>>,
        List<AgentDomainEntity>,
        FutureOr<List<AgentDomainEntity>>>
    with
        $FutureModifier<List<AgentDomainEntity>>,
        $FutureProvider<List<AgentDomainEntity>> {
  /// List all non-deleted agent templates.
  AgentTemplatesProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'agentTemplatesProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$agentTemplatesHash();

  @$internal
  @override
  $FutureProviderElement<List<AgentDomainEntity>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<AgentDomainEntity>> create(Ref ref) {
    return agentTemplates(ref);
  }
}

String _$agentTemplatesHash() => r'11181589ced963f8f4bbf169e06f8d82e1667045';

/// Fetch a single agent template by [templateId].
///
/// The returned entity is an [AgentTemplateEntity] (or `null`).

@ProviderFor(agentTemplate)
final agentTemplateProvider = AgentTemplateFamily._();

/// Fetch a single agent template by [templateId].
///
/// The returned entity is an [AgentTemplateEntity] (or `null`).

final class AgentTemplateProvider extends $FunctionalProvider<
        AsyncValue<AgentDomainEntity?>,
        AgentDomainEntity?,
        FutureOr<AgentDomainEntity?>>
    with
        $FutureModifier<AgentDomainEntity?>,
        $FutureProvider<AgentDomainEntity?> {
  /// Fetch a single agent template by [templateId].
  ///
  /// The returned entity is an [AgentTemplateEntity] (or `null`).
  AgentTemplateProvider._(
      {required AgentTemplateFamily super.from, required String super.argument})
      : super(
          retry: null,
          name: r'agentTemplateProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$agentTemplateHash();

  @override
  String toString() {
    return r'agentTemplateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<AgentDomainEntity?> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<AgentDomainEntity?> create(Ref ref) {
    final argument = this.argument as String;
    return agentTemplate(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AgentTemplateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$agentTemplateHash() => r'5ee0eea3d220f610c9d97e022a369d277801234c';

/// Fetch a single agent template by [templateId].
///
/// The returned entity is an [AgentTemplateEntity] (or `null`).

final class AgentTemplateFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<AgentDomainEntity?>, String> {
  AgentTemplateFamily._()
      : super(
          retry: null,
          name: r'agentTemplateProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Fetch a single agent template by [templateId].
  ///
  /// The returned entity is an [AgentTemplateEntity] (or `null`).

  AgentTemplateProvider call(
    String templateId,
  ) =>
      AgentTemplateProvider._(argument: templateId, from: this);

  @override
  String toString() => r'agentTemplateProvider';
}

/// Fetch the active version for a template by [templateId].
///
/// The returned entity is an [AgentTemplateVersionEntity] (or `null`).

@ProviderFor(activeTemplateVersion)
final activeTemplateVersionProvider = ActiveTemplateVersionFamily._();

/// Fetch the active version for a template by [templateId].
///
/// The returned entity is an [AgentTemplateVersionEntity] (or `null`).

final class ActiveTemplateVersionProvider extends $FunctionalProvider<
        AsyncValue<AgentDomainEntity?>,
        AgentDomainEntity?,
        FutureOr<AgentDomainEntity?>>
    with
        $FutureModifier<AgentDomainEntity?>,
        $FutureProvider<AgentDomainEntity?> {
  /// Fetch the active version for a template by [templateId].
  ///
  /// The returned entity is an [AgentTemplateVersionEntity] (or `null`).
  ActiveTemplateVersionProvider._(
      {required ActiveTemplateVersionFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'activeTemplateVersionProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$activeTemplateVersionHash();

  @override
  String toString() {
    return r'activeTemplateVersionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<AgentDomainEntity?> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<AgentDomainEntity?> create(Ref ref) {
    final argument = this.argument as String;
    return activeTemplateVersion(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ActiveTemplateVersionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$activeTemplateVersionHash() =>
    r'fdb4eb5d0f919e42b00dacb96bf96a8f12d0d23e';

/// Fetch the active version for a template by [templateId].
///
/// The returned entity is an [AgentTemplateVersionEntity] (or `null`).

final class ActiveTemplateVersionFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<AgentDomainEntity?>, String> {
  ActiveTemplateVersionFamily._()
      : super(
          retry: null,
          name: r'activeTemplateVersionProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Fetch the active version for a template by [templateId].
  ///
  /// The returned entity is an [AgentTemplateVersionEntity] (or `null`).

  ActiveTemplateVersionProvider call(
    String templateId,
  ) =>
      ActiveTemplateVersionProvider._(argument: templateId, from: this);

  @override
  String toString() => r'activeTemplateVersionProvider';
}

/// Fetch the version history for a template by [templateId].
///
/// Each element is an [AgentTemplateVersionEntity].

@ProviderFor(templateVersionHistory)
final templateVersionHistoryProvider = TemplateVersionHistoryFamily._();

/// Fetch the version history for a template by [templateId].
///
/// Each element is an [AgentTemplateVersionEntity].

final class TemplateVersionHistoryProvider extends $FunctionalProvider<
        AsyncValue<List<AgentDomainEntity>>,
        List<AgentDomainEntity>,
        FutureOr<List<AgentDomainEntity>>>
    with
        $FutureModifier<List<AgentDomainEntity>>,
        $FutureProvider<List<AgentDomainEntity>> {
  /// Fetch the version history for a template by [templateId].
  ///
  /// Each element is an [AgentTemplateVersionEntity].
  TemplateVersionHistoryProvider._(
      {required TemplateVersionHistoryFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'templateVersionHistoryProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$templateVersionHistoryHash();

  @override
  String toString() {
    return r'templateVersionHistoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<AgentDomainEntity>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<AgentDomainEntity>> create(Ref ref) {
    final argument = this.argument as String;
    return templateVersionHistory(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TemplateVersionHistoryProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$templateVersionHistoryHash() =>
    r'5c79f0c0ec038e06bb2c5eab1b74d50d7bdd5f34';

/// Fetch the version history for a template by [templateId].
///
/// Each element is an [AgentTemplateVersionEntity].

final class TemplateVersionHistoryFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<AgentDomainEntity>>, String> {
  TemplateVersionHistoryFamily._()
      : super(
          retry: null,
          name: r'templateVersionHistoryProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Fetch the version history for a template by [templateId].
  ///
  /// Each element is an [AgentTemplateVersionEntity].

  TemplateVersionHistoryProvider call(
    String templateId,
  ) =>
      TemplateVersionHistoryProvider._(argument: templateId, from: this);

  @override
  String toString() => r'templateVersionHistoryProvider';
}

/// Resolve the template assigned to an agent by [agentId].
///
/// The returned entity is an [AgentTemplateEntity] (or `null`).

@ProviderFor(templateForAgent)
final templateForAgentProvider = TemplateForAgentFamily._();

/// Resolve the template assigned to an agent by [agentId].
///
/// The returned entity is an [AgentTemplateEntity] (or `null`).

final class TemplateForAgentProvider extends $FunctionalProvider<
        AsyncValue<AgentDomainEntity?>,
        AgentDomainEntity?,
        FutureOr<AgentDomainEntity?>>
    with
        $FutureModifier<AgentDomainEntity?>,
        $FutureProvider<AgentDomainEntity?> {
  /// Resolve the template assigned to an agent by [agentId].
  ///
  /// The returned entity is an [AgentTemplateEntity] (or `null`).
  TemplateForAgentProvider._(
      {required TemplateForAgentFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'templateForAgentProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$templateForAgentHash();

  @override
  String toString() {
    return r'templateForAgentProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<AgentDomainEntity?> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<AgentDomainEntity?> create(Ref ref) {
    final argument = this.argument as String;
    return templateForAgent(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TemplateForAgentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$templateForAgentHash() => r'fc6ba0981e92157bbf69bef00f3ff73a8f4cc4a6';

/// Resolve the template assigned to an agent by [agentId].
///
/// The returned entity is an [AgentTemplateEntity] (or `null`).

final class TemplateForAgentFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<AgentDomainEntity?>, String> {
  TemplateForAgentFamily._()
      : super(
          retry: null,
          name: r'templateForAgentProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Resolve the template assigned to an agent by [agentId].
  ///
  /// The returned entity is an [AgentTemplateEntity] (or `null`).

  TemplateForAgentProvider call(
    String agentId,
  ) =>
      TemplateForAgentProvider._(argument: agentId, from: this);

  @override
  String toString() => r'templateForAgentProvider';
}

/// Fetch the latest report for an agent by [agentId].
///
/// Returns [AgentDomainEntity] (variant: [AgentReportEntity]) or `null`.

@ProviderFor(agentReport)
final agentReportProvider = AgentReportFamily._();

/// Fetch the latest report for an agent by [agentId].
///
/// Returns [AgentDomainEntity] (variant: [AgentReportEntity]) or `null`.

final class AgentReportProvider extends $FunctionalProvider<
        AsyncValue<AgentDomainEntity?>,
        AgentDomainEntity?,
        FutureOr<AgentDomainEntity?>>
    with
        $FutureModifier<AgentDomainEntity?>,
        $FutureProvider<AgentDomainEntity?> {
  /// Fetch the latest report for an agent by [agentId].
  ///
  /// Returns [AgentDomainEntity] (variant: [AgentReportEntity]) or `null`.
  AgentReportProvider._(
      {required AgentReportFamily super.from, required String super.argument})
      : super(
          retry: null,
          name: r'agentReportProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$agentReportHash();

  @override
  String toString() {
    return r'agentReportProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<AgentDomainEntity?> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<AgentDomainEntity?> create(Ref ref) {
    final argument = this.argument as String;
    return agentReport(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AgentReportProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$agentReportHash() => r'a3db3955b73c6821bbc73c4f96fb86266660973b';

/// Fetch the latest report for an agent by [agentId].
///
/// Returns [AgentDomainEntity] (variant: [AgentReportEntity]) or `null`.

final class AgentReportFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<AgentDomainEntity?>, String> {
  AgentReportFamily._()
      : super(
          retry: null,
          name: r'agentReportProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Fetch the latest report for an agent by [agentId].
  ///
  /// Returns [AgentDomainEntity] (variant: [AgentReportEntity]) or `null`.

  AgentReportProvider call(
    String agentId,
  ) =>
      AgentReportProvider._(argument: agentId, from: this);

  @override
  String toString() => r'agentReportProvider';
}

/// Fetch agent state for an agent by [agentId].
///
/// Returns [AgentDomainEntity] (variant: [AgentStateEntity]) or `null`.

@ProviderFor(agentState)
final agentStateProvider = AgentStateFamily._();

/// Fetch agent state for an agent by [agentId].
///
/// Returns [AgentDomainEntity] (variant: [AgentStateEntity]) or `null`.

final class AgentStateProvider extends $FunctionalProvider<
        AsyncValue<AgentDomainEntity?>,
        AgentDomainEntity?,
        FutureOr<AgentDomainEntity?>>
    with
        $FutureModifier<AgentDomainEntity?>,
        $FutureProvider<AgentDomainEntity?> {
  /// Fetch agent state for an agent by [agentId].
  ///
  /// Returns [AgentDomainEntity] (variant: [AgentStateEntity]) or `null`.
  AgentStateProvider._(
      {required AgentStateFamily super.from, required String super.argument})
      : super(
          retry: null,
          name: r'agentStateProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$agentStateHash();

  @override
  String toString() {
    return r'agentStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<AgentDomainEntity?> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<AgentDomainEntity?> create(Ref ref) {
    final argument = this.argument as String;
    return agentState(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AgentStateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$agentStateHash() => r'08465c11bf7cb2c5cb0c8e064ba4502af5773c6e';

/// Fetch agent state for an agent by [agentId].
///
/// Returns [AgentDomainEntity] (variant: [AgentStateEntity]) or `null`.

final class AgentStateFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<AgentDomainEntity?>, String> {
  AgentStateFamily._()
      : super(
          retry: null,
          name: r'agentStateProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Fetch agent state for an agent by [agentId].
  ///
  /// Returns [AgentDomainEntity] (variant: [AgentStateEntity]) or `null`.

  AgentStateProvider call(
    String agentId,
  ) =>
      AgentStateProvider._(argument: agentId, from: this);

  @override
  String toString() => r'agentStateProvider';
}

/// Fetch agent identity by [agentId].
///
/// Returns [AgentDomainEntity] (variant: [AgentIdentityEntity]) or `null`.

@ProviderFor(agentIdentity)
final agentIdentityProvider = AgentIdentityFamily._();

/// Fetch agent identity by [agentId].
///
/// Returns [AgentDomainEntity] (variant: [AgentIdentityEntity]) or `null`.

final class AgentIdentityProvider extends $FunctionalProvider<
        AsyncValue<AgentDomainEntity?>,
        AgentDomainEntity?,
        FutureOr<AgentDomainEntity?>>
    with
        $FutureModifier<AgentDomainEntity?>,
        $FutureProvider<AgentDomainEntity?> {
  /// Fetch agent identity by [agentId].
  ///
  /// Returns [AgentDomainEntity] (variant: [AgentIdentityEntity]) or `null`.
  AgentIdentityProvider._(
      {required AgentIdentityFamily super.from, required String super.argument})
      : super(
          retry: null,
          name: r'agentIdentityProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$agentIdentityHash();

  @override
  String toString() {
    return r'agentIdentityProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<AgentDomainEntity?> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<AgentDomainEntity?> create(Ref ref) {
    final argument = this.argument as String;
    return agentIdentity(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AgentIdentityProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$agentIdentityHash() => r'01933854263e081557cf5c5ed035f70a61a92bd2';

/// Fetch agent identity by [agentId].
///
/// Returns [AgentDomainEntity] (variant: [AgentIdentityEntity]) or `null`.

final class AgentIdentityFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<AgentDomainEntity?>, String> {
  AgentIdentityFamily._()
      : super(
          retry: null,
          name: r'agentIdentityProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Fetch agent identity by [agentId].
  ///
  /// Returns [AgentDomainEntity] (variant: [AgentIdentityEntity]) or `null`.

  AgentIdentityProvider call(
    String agentId,
  ) =>
      AgentIdentityProvider._(argument: agentId, from: this);

  @override
  String toString() => r'agentIdentityProvider';
}

/// Fetch recent messages for an agent by [agentId].
///
/// Returns up to 50 of the most recent message entities (all kinds),
/// ordered most-recent first. Each element is an [AgentDomainEntity] of
/// variant [AgentMessageEntity].

@ProviderFor(agentRecentMessages)
final agentRecentMessagesProvider = AgentRecentMessagesFamily._();

/// Fetch recent messages for an agent by [agentId].
///
/// Returns up to 50 of the most recent message entities (all kinds),
/// ordered most-recent first. Each element is an [AgentDomainEntity] of
/// variant [AgentMessageEntity].

final class AgentRecentMessagesProvider extends $FunctionalProvider<
        AsyncValue<List<AgentDomainEntity>>,
        List<AgentDomainEntity>,
        FutureOr<List<AgentDomainEntity>>>
    with
        $FutureModifier<List<AgentDomainEntity>>,
        $FutureProvider<List<AgentDomainEntity>> {
  /// Fetch recent messages for an agent by [agentId].
  ///
  /// Returns up to 50 of the most recent message entities (all kinds),
  /// ordered most-recent first. Each element is an [AgentDomainEntity] of
  /// variant [AgentMessageEntity].
  AgentRecentMessagesProvider._(
      {required AgentRecentMessagesFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'agentRecentMessagesProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$agentRecentMessagesHash();

  @override
  String toString() {
    return r'agentRecentMessagesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<AgentDomainEntity>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<AgentDomainEntity>> create(Ref ref) {
    final argument = this.argument as String;
    return agentRecentMessages(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AgentRecentMessagesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$agentRecentMessagesHash() =>
    r'e2f7d7c0351250705af48635b57b674fdefb7721';

/// Fetch recent messages for an agent by [agentId].
///
/// Returns up to 50 of the most recent message entities (all kinds),
/// ordered most-recent first. Each element is an [AgentDomainEntity] of
/// variant [AgentMessageEntity].

final class AgentRecentMessagesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<AgentDomainEntity>>, String> {
  AgentRecentMessagesFamily._()
      : super(
          retry: null,
          name: r'agentRecentMessagesProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Fetch recent messages for an agent by [agentId].
  ///
  /// Returns up to 50 of the most recent message entities (all kinds),
  /// ordered most-recent first. Each element is an [AgentDomainEntity] of
  /// variant [AgentMessageEntity].

  AgentRecentMessagesProvider call(
    String agentId,
  ) =>
      AgentRecentMessagesProvider._(argument: agentId, from: this);

  @override
  String toString() => r'agentRecentMessagesProvider';
}

/// Loads the text content of an [AgentMessagePayloadEntity] by its ID.
///
/// Returns the `text` field from the payload content map, or `null` if the
/// payload doesn't exist or has no text.

@ProviderFor(agentMessagePayloadText)
final agentMessagePayloadTextProvider = AgentMessagePayloadTextFamily._();

/// Loads the text content of an [AgentMessagePayloadEntity] by its ID.
///
/// Returns the `text` field from the payload content map, or `null` if the
/// payload doesn't exist or has no text.

final class AgentMessagePayloadTextProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// Loads the text content of an [AgentMessagePayloadEntity] by its ID.
  ///
  /// Returns the `text` field from the payload content map, or `null` if the
  /// payload doesn't exist or has no text.
  AgentMessagePayloadTextProvider._(
      {required AgentMessagePayloadTextFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'agentMessagePayloadTextProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$agentMessagePayloadTextHash();

  @override
  String toString() {
    return r'agentMessagePayloadTextProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    final argument = this.argument as String;
    return agentMessagePayloadText(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AgentMessagePayloadTextProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$agentMessagePayloadTextHash() =>
    r'95b9c1d028dbfc17b9b14b68057bf7f61a4e7fca';

/// Loads the text content of an [AgentMessagePayloadEntity] by its ID.
///
/// Returns the `text` field from the payload content map, or `null` if the
/// payload doesn't exist or has no text.

final class AgentMessagePayloadTextFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, String> {
  AgentMessagePayloadTextFamily._()
      : super(
          retry: null,
          name: r'agentMessagePayloadTextProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Loads the text content of an [AgentMessagePayloadEntity] by its ID.
  ///
  /// Returns the `text` field from the payload content map, or `null` if the
  /// payload doesn't exist or has no text.

  AgentMessagePayloadTextProvider call(
    String payloadId,
  ) =>
      AgentMessagePayloadTextProvider._(argument: payloadId, from: this);

  @override
  String toString() => r'agentMessagePayloadTextProvider';
}

/// Fetch recent messages grouped by thread ID for an agent.
///
/// Returns a map of threadId → list of [AgentMessageEntity] sorted
/// chronologically within each thread. Threads are sorted most-recent-first
/// (by the latest message in each thread).

@ProviderFor(agentMessagesByThread)
final agentMessagesByThreadProvider = AgentMessagesByThreadFamily._();

/// Fetch recent messages grouped by thread ID for an agent.
///
/// Returns a map of threadId → list of [AgentMessageEntity] sorted
/// chronologically within each thread. Threads are sorted most-recent-first
/// (by the latest message in each thread).

final class AgentMessagesByThreadProvider extends $FunctionalProvider<
        AsyncValue<Map<String, List<AgentDomainEntity>>>,
        Map<String, List<AgentDomainEntity>>,
        FutureOr<Map<String, List<AgentDomainEntity>>>>
    with
        $FutureModifier<Map<String, List<AgentDomainEntity>>>,
        $FutureProvider<Map<String, List<AgentDomainEntity>>> {
  /// Fetch recent messages grouped by thread ID for an agent.
  ///
  /// Returns a map of threadId → list of [AgentMessageEntity] sorted
  /// chronologically within each thread. Threads are sorted most-recent-first
  /// (by the latest message in each thread).
  AgentMessagesByThreadProvider._(
      {required AgentMessagesByThreadFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'agentMessagesByThreadProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$agentMessagesByThreadHash();

  @override
  String toString() {
    return r'agentMessagesByThreadProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Map<String, List<AgentDomainEntity>>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, List<AgentDomainEntity>>> create(Ref ref) {
    final argument = this.argument as String;
    return agentMessagesByThread(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AgentMessagesByThreadProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$agentMessagesByThreadHash() =>
    r'391b4396f7dce55356e51185d5e112580acc23f1';

/// Fetch recent messages grouped by thread ID for an agent.
///
/// Returns a map of threadId → list of [AgentMessageEntity] sorted
/// chronologically within each thread. Threads are sorted most-recent-first
/// (by the latest message in each thread).

final class AgentMessagesByThreadFamily extends $Family
    with
        $FunctionalFamilyOverride<
            FutureOr<Map<String, List<AgentDomainEntity>>>, String> {
  AgentMessagesByThreadFamily._()
      : super(
          retry: null,
          name: r'agentMessagesByThreadProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Fetch recent messages grouped by thread ID for an agent.
  ///
  /// Returns a map of threadId → list of [AgentMessageEntity] sorted
  /// chronologically within each thread. Threads are sorted most-recent-first
  /// (by the latest message in each thread).

  AgentMessagesByThreadProvider call(
    String agentId,
  ) =>
      AgentMessagesByThreadProvider._(argument: agentId, from: this);

  @override
  String toString() => r'agentMessagesByThreadProvider';
}

/// Fetch recent observation messages for an agent by [agentId].
///
/// Returns only messages with kind [AgentMessageKind.observation], ordered
/// most-recent first.

@ProviderFor(agentObservationMessages)
final agentObservationMessagesProvider = AgentObservationMessagesFamily._();

/// Fetch recent observation messages for an agent by [agentId].
///
/// Returns only messages with kind [AgentMessageKind.observation], ordered
/// most-recent first.

final class AgentObservationMessagesProvider extends $FunctionalProvider<
        AsyncValue<List<AgentDomainEntity>>,
        List<AgentDomainEntity>,
        FutureOr<List<AgentDomainEntity>>>
    with
        $FutureModifier<List<AgentDomainEntity>>,
        $FutureProvider<List<AgentDomainEntity>> {
  /// Fetch recent observation messages for an agent by [agentId].
  ///
  /// Returns only messages with kind [AgentMessageKind.observation], ordered
  /// most-recent first.
  AgentObservationMessagesProvider._(
      {required AgentObservationMessagesFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'agentObservationMessagesProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$agentObservationMessagesHash();

  @override
  String toString() {
    return r'agentObservationMessagesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<AgentDomainEntity>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<AgentDomainEntity>> create(Ref ref) {
    final argument = this.argument as String;
    return agentObservationMessages(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AgentObservationMessagesProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$agentObservationMessagesHash() =>
    r'f6f7cadcd29a155a6ccfe0457ab02a1b3648c67d';

/// Fetch recent observation messages for an agent by [agentId].
///
/// Returns only messages with kind [AgentMessageKind.observation], ordered
/// most-recent first.

final class AgentObservationMessagesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<AgentDomainEntity>>, String> {
  AgentObservationMessagesFamily._()
      : super(
          retry: null,
          name: r'agentObservationMessagesProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Fetch recent observation messages for an agent by [agentId].
  ///
  /// Returns only messages with kind [AgentMessageKind.observation], ordered
  /// most-recent first.

  AgentObservationMessagesProvider call(
    String agentId,
  ) =>
      AgentObservationMessagesProvider._(argument: agentId, from: this);

  @override
  String toString() => r'agentObservationMessagesProvider';
}

/// Fetch all report snapshots for an agent by [agentId], most-recent first.
///
/// Each wake overwrites the report, so older snapshots let the user trace
/// how the report evolved over time.

@ProviderFor(agentReportHistory)
final agentReportHistoryProvider = AgentReportHistoryFamily._();

/// Fetch all report snapshots for an agent by [agentId], most-recent first.
///
/// Each wake overwrites the report, so older snapshots let the user trace
/// how the report evolved over time.

final class AgentReportHistoryProvider extends $FunctionalProvider<
        AsyncValue<List<AgentDomainEntity>>,
        List<AgentDomainEntity>,
        FutureOr<List<AgentDomainEntity>>>
    with
        $FutureModifier<List<AgentDomainEntity>>,
        $FutureProvider<List<AgentDomainEntity>> {
  /// Fetch all report snapshots for an agent by [agentId], most-recent first.
  ///
  /// Each wake overwrites the report, so older snapshots let the user trace
  /// how the report evolved over time.
  AgentReportHistoryProvider._(
      {required AgentReportHistoryFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'agentReportHistoryProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$agentReportHistoryHash();

  @override
  String toString() {
    return r'agentReportHistoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<AgentDomainEntity>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<AgentDomainEntity>> create(Ref ref) {
    final argument = this.argument as String;
    return agentReportHistory(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AgentReportHistoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$agentReportHistoryHash() =>
    r'95dd6cf095f3d23687d372dc216cb29c4062845f';

/// Fetch all report snapshots for an agent by [agentId], most-recent first.
///
/// Each wake overwrites the report, so older snapshots let the user trace
/// how the report evolved over time.

final class AgentReportHistoryFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<AgentDomainEntity>>, String> {
  AgentReportHistoryFamily._()
      : super(
          retry: null,
          name: r'agentReportHistoryProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Fetch all report snapshots for an agent by [agentId], most-recent first.
  ///
  /// Each wake overwrites the report, so older snapshots let the user trace
  /// how the report evolved over time.

  AgentReportHistoryProvider call(
    String agentId,
  ) =>
      AgentReportHistoryProvider._(argument: agentId, from: this);

  @override
  String toString() => r'agentReportHistoryProvider';
}

/// Computed performance metrics for a template by [templateId].

@ProviderFor(templatePerformanceMetrics)
final templatePerformanceMetricsProvider = TemplatePerformanceMetricsFamily._();

/// Computed performance metrics for a template by [templateId].

final class TemplatePerformanceMetricsProvider extends $FunctionalProvider<
        AsyncValue<TemplatePerformanceMetrics>,
        TemplatePerformanceMetrics,
        FutureOr<TemplatePerformanceMetrics>>
    with
        $FutureModifier<TemplatePerformanceMetrics>,
        $FutureProvider<TemplatePerformanceMetrics> {
  /// Computed performance metrics for a template by [templateId].
  TemplatePerformanceMetricsProvider._(
      {required TemplatePerformanceMetricsFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'templatePerformanceMetricsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$templatePerformanceMetricsHash();

  @override
  String toString() {
    return r'templatePerformanceMetricsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<TemplatePerformanceMetrics> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<TemplatePerformanceMetrics> create(Ref ref) {
    final argument = this.argument as String;
    return templatePerformanceMetrics(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TemplatePerformanceMetricsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$templatePerformanceMetricsHash() =>
    r'982bec390cb2296af911ca1cdc540f140afe5e36';

/// Computed performance metrics for a template by [templateId].

final class TemplatePerformanceMetricsFamily extends $Family
    with
        $FunctionalFamilyOverride<FutureOr<TemplatePerformanceMetrics>,
            String> {
  TemplatePerformanceMetricsFamily._()
      : super(
          retry: null,
          name: r'templatePerformanceMetricsProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Computed performance metrics for a template by [templateId].

  TemplatePerformanceMetricsProvider call(
    String templateId,
  ) =>
      TemplatePerformanceMetricsProvider._(argument: templateId, from: this);

  @override
  String toString() => r'templatePerformanceMetricsProvider';
}

/// The template evolution workflow with all dependencies resolved.

@ProviderFor(templateEvolutionWorkflow)
final templateEvolutionWorkflowProvider = TemplateEvolutionWorkflowProvider._();

/// The template evolution workflow with all dependencies resolved.

final class TemplateEvolutionWorkflowProvider extends $FunctionalProvider<
    TemplateEvolutionWorkflow,
    TemplateEvolutionWorkflow,
    TemplateEvolutionWorkflow> with $Provider<TemplateEvolutionWorkflow> {
  /// The template evolution workflow with all dependencies resolved.
  TemplateEvolutionWorkflowProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'templateEvolutionWorkflowProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$templateEvolutionWorkflowHash();

  @$internal
  @override
  $ProviderElement<TemplateEvolutionWorkflow> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TemplateEvolutionWorkflow create(Ref ref) {
    return templateEvolutionWorkflow(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TemplateEvolutionWorkflow value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TemplateEvolutionWorkflow>(value),
    );
  }
}

String _$templateEvolutionWorkflowHash() =>
    r'f204e4ec087fdfb0a3fafac06a1f38d648eb94a6';

/// The task agent workflow with all dependencies resolved.

@ProviderFor(taskAgentWorkflow)
final taskAgentWorkflowProvider = TaskAgentWorkflowProvider._();

/// The task agent workflow with all dependencies resolved.

final class TaskAgentWorkflowProvider extends $FunctionalProvider<
    TaskAgentWorkflow,
    TaskAgentWorkflow,
    TaskAgentWorkflow> with $Provider<TaskAgentWorkflow> {
  /// The task agent workflow with all dependencies resolved.
  TaskAgentWorkflowProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'taskAgentWorkflowProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$taskAgentWorkflowHash();

  @$internal
  @override
  $ProviderElement<TaskAgentWorkflow> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TaskAgentWorkflow create(Ref ref) {
    return taskAgentWorkflow(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskAgentWorkflow value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskAgentWorkflow>(value),
    );
  }
}

String _$taskAgentWorkflowHash() => r'4e523ddb904093dc073b153f27b361d0e992d05b';

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
    r'987992e7e80752d4d42473f5ebd80c1f6d775b02';
