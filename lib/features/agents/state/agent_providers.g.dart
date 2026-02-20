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

String _$agentDatabaseHash() => r'34b868b283547e682cd5d6fc3129cbbeeb0b3600';

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

String _$wakeRunnerHash() => r'6272c9e1c8679202c52f774487a93d979713b61e';

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

String _$agentServiceHash() => r'b7c9b91f8ce7c5f41c20f632b73f34207062343f';

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

String _$agentReportHash() => r'3486a3f41e21d68715d5c5ebb1f01282a814c28e';

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

String _$agentStateHash() => r'dbd935967aadac6b9e3f362e56e121b6dea0608b';

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

String _$agentIdentityHash() => r'dd9c1bbef6f8172514ec1fda9e61d31bb226c72f';

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
    r'166acdef4acb84aabd89b74c550e7d4b4a555146';

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
