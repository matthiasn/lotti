// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_query_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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
  AgentIsRunningProvider._({
    required AgentIsRunningFamily super.from,
    required String super.argument,
  }) : super(
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
    return agentIsRunning(ref, argument);
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

  AgentIsRunningProvider call(String agentId) =>
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

final class AgentUpdateStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<Set<String>>,
          Set<String>,
          Stream<Set<String>>
        >
    with $FutureModifier<Set<String>>, $StreamProvider<Set<String>> {
  /// Stream that emits when a specific agent's data changes (from sync or local
  /// wake). Detail providers watch this to self-invalidate.
  ///
  /// Returns the raw `Set<String>` from `UpdateNotifications` rather than `void`
  /// because Riverpod deduplicates `AsyncData` values using `==`. Since
  /// `null == null`, a `Stream<void>` would only notify watchers on the first
  /// emission. Each `Set` instance is identity-distinct, ensuring every
  /// notification triggers a provider rebuild.
  AgentUpdateStreamProvider._({
    required AgentUpdateStreamFamily super.from,
    required String super.argument,
  }) : super(
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
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Set<String>> create(Ref ref) {
    final argument = this.argument as String;
    return agentUpdateStream(ref, argument);
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

String _$agentUpdateStreamHash() => r'8f0b1579fbb78e4e89484e27e667756a64987f52';

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

  AgentUpdateStreamProvider call(String agentId) =>
      AgentUpdateStreamProvider._(argument: agentId, from: this);

  @override
  String toString() => r'agentUpdateStreamProvider';
}

/// Fetch the latest report for an agent by [agentId].
///
/// Returns [AgentDomainEntity] (variant: [AgentReportEntity]) or `null`.

@ProviderFor(agentReport)
final agentReportProvider = AgentReportFamily._();

/// Fetch the latest report for an agent by [agentId].
///
/// Returns [AgentDomainEntity] (variant: [AgentReportEntity]) or `null`.

final class AgentReportProvider
    extends
        $FunctionalProvider<
          AsyncValue<AgentDomainEntity?>,
          AgentDomainEntity?,
          FutureOr<AgentDomainEntity?>
        >
    with
        $FutureModifier<AgentDomainEntity?>,
        $FutureProvider<AgentDomainEntity?> {
  /// Fetch the latest report for an agent by [agentId].
  ///
  /// Returns [AgentDomainEntity] (variant: [AgentReportEntity]) or `null`.
  AgentReportProvider._({
    required AgentReportFamily super.from,
    required String super.argument,
  }) : super(
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
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AgentDomainEntity?> create(Ref ref) {
    final argument = this.argument as String;
    return agentReport(ref, argument);
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

  AgentReportProvider call(String agentId) =>
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

final class AgentStateProvider
    extends
        $FunctionalProvider<
          AsyncValue<AgentDomainEntity?>,
          AgentDomainEntity?,
          FutureOr<AgentDomainEntity?>
        >
    with
        $FutureModifier<AgentDomainEntity?>,
        $FutureProvider<AgentDomainEntity?> {
  /// Fetch agent state for an agent by [agentId].
  ///
  /// Returns [AgentDomainEntity] (variant: [AgentStateEntity]) or `null`.
  AgentStateProvider._({
    required AgentStateFamily super.from,
    required String super.argument,
  }) : super(
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
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AgentDomainEntity?> create(Ref ref) {
    final argument = this.argument as String;
    return agentState(ref, argument);
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

  AgentStateProvider call(String agentId) =>
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

final class AgentIdentityProvider
    extends
        $FunctionalProvider<
          AsyncValue<AgentDomainEntity?>,
          AgentDomainEntity?,
          FutureOr<AgentDomainEntity?>
        >
    with
        $FutureModifier<AgentDomainEntity?>,
        $FutureProvider<AgentDomainEntity?> {
  /// Fetch agent identity by [agentId].
  ///
  /// Returns [AgentDomainEntity] (variant: [AgentIdentityEntity]) or `null`.
  AgentIdentityProvider._({
    required AgentIdentityFamily super.from,
    required String super.argument,
  }) : super(
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
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AgentDomainEntity?> create(Ref ref) {
    final argument = this.argument as String;
    return agentIdentity(ref, argument);
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

  AgentIdentityProvider call(String agentId) =>
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

final class AgentRecentMessagesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AgentDomainEntity>>,
          List<AgentDomainEntity>,
          FutureOr<List<AgentDomainEntity>>
        >
    with
        $FutureModifier<List<AgentDomainEntity>>,
        $FutureProvider<List<AgentDomainEntity>> {
  /// Fetch recent messages for an agent by [agentId].
  ///
  /// Returns up to 50 of the most recent message entities (all kinds),
  /// ordered most-recent first. Each element is an [AgentDomainEntity] of
  /// variant [AgentMessageEntity].
  AgentRecentMessagesProvider._({
    required AgentRecentMessagesFamily super.from,
    required String super.argument,
  }) : super(
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
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AgentDomainEntity>> create(Ref ref) {
    final argument = this.argument as String;
    return agentRecentMessages(ref, argument);
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
    r'80b0b758f267eba8aba8bf2597338c4547cdf71e';

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

  AgentRecentMessagesProvider call(String agentId) =>
      AgentRecentMessagesProvider._(argument: agentId, from: this);

  @override
  String toString() => r'agentRecentMessagesProvider';
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

final class AgentMessagesByThreadProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, List<AgentDomainEntity>>>,
          Map<String, List<AgentDomainEntity>>,
          FutureOr<Map<String, List<AgentDomainEntity>>>
        >
    with
        $FutureModifier<Map<String, List<AgentDomainEntity>>>,
        $FutureProvider<Map<String, List<AgentDomainEntity>>> {
  /// Fetch recent messages grouped by thread ID for an agent.
  ///
  /// Returns a map of threadId → list of [AgentMessageEntity] sorted
  /// chronologically within each thread. Threads are sorted most-recent-first
  /// (by the latest message in each thread).
  AgentMessagesByThreadProvider._({
    required AgentMessagesByThreadFamily super.from,
    required String super.argument,
  }) : super(
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
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, List<AgentDomainEntity>>> create(Ref ref) {
    final argument = this.argument as String;
    return agentMessagesByThread(ref, argument);
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
    r'61afa9ccae181277496e1c17a9e3af536d49a3ef';

/// Fetch recent messages grouped by thread ID for an agent.
///
/// Returns a map of threadId → list of [AgentMessageEntity] sorted
/// chronologically within each thread. Threads are sorted most-recent-first
/// (by the latest message in each thread).

final class AgentMessagesByThreadFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<Map<String, List<AgentDomainEntity>>>,
          String
        > {
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

  AgentMessagesByThreadProvider call(String agentId) =>
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

final class AgentObservationMessagesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AgentDomainEntity>>,
          List<AgentDomainEntity>,
          FutureOr<List<AgentDomainEntity>>
        >
    with
        $FutureModifier<List<AgentDomainEntity>>,
        $FutureProvider<List<AgentDomainEntity>> {
  /// Fetch recent observation messages for an agent by [agentId].
  ///
  /// Returns only messages with kind [AgentMessageKind.observation], ordered
  /// most-recent first.
  AgentObservationMessagesProvider._({
    required AgentObservationMessagesFamily super.from,
    required String super.argument,
  }) : super(
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
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AgentDomainEntity>> create(Ref ref) {
    final argument = this.argument as String;
    return agentObservationMessages(ref, argument);
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
    r'09bbd3427f7387fb44d098430be0ba3d7e654d12';

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

  AgentObservationMessagesProvider call(String agentId) =>
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

final class AgentReportHistoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AgentDomainEntity>>,
          List<AgentDomainEntity>,
          FutureOr<List<AgentDomainEntity>>
        >
    with
        $FutureModifier<List<AgentDomainEntity>>,
        $FutureProvider<List<AgentDomainEntity>> {
  /// Fetch all report snapshots for an agent by [agentId], most-recent first.
  ///
  /// Each wake overwrites the report, so older snapshots let the user trace
  /// how the report evolved over time.
  AgentReportHistoryProvider._({
    required AgentReportHistoryFamily super.from,
    required String super.argument,
  }) : super(
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
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AgentDomainEntity>> create(Ref ref) {
    final argument = this.argument as String;
    return agentReportHistory(ref, argument);
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
    r'0819f2713626430d6116a56bd898f91adae882ea';

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

  AgentReportHistoryProvider call(String agentId) =>
      AgentReportHistoryProvider._(argument: agentId, from: this);

  @override
  String toString() => r'agentReportHistoryProvider';
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
  AgentMessagePayloadTextProvider._({
    required AgentMessagePayloadTextFamily super.from,
    required String super.argument,
  }) : super(
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
    return agentMessagePayloadText(ref, argument);
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

  AgentMessagePayloadTextProvider call(String payloadId) =>
      AgentMessagePayloadTextProvider._(argument: payloadId, from: this);

  @override
  String toString() => r'agentMessagePayloadTextProvider';
}

/// List all agent identity instances.

@ProviderFor(allAgentInstances)
final allAgentInstancesProvider = AllAgentInstancesProvider._();

/// List all agent identity instances.

final class AllAgentInstancesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AgentDomainEntity>>,
          List<AgentDomainEntity>,
          FutureOr<List<AgentDomainEntity>>
        >
    with
        $FutureModifier<List<AgentDomainEntity>>,
        $FutureProvider<List<AgentDomainEntity>> {
  /// List all agent identity instances.
  AllAgentInstancesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allAgentInstancesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allAgentInstancesHash();

  @$internal
  @override
  $FutureProviderElement<List<AgentDomainEntity>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AgentDomainEntity>> create(Ref ref) {
    return allAgentInstances(ref);
  }
}

String _$allAgentInstancesHash() => r'2def9e6a157e7a074a0e8144ec20ebcee741d8b2';

/// Raw token usage records for an agent.
///
/// Shared base provider that fetches `WakeTokenUsageEntity` records once;
/// both [agentTokenUsageSummariesProvider] and [tokenUsageForThreadProvider]
/// derive their state from this to avoid redundant database queries.

@ProviderFor(agentTokenUsageRecords)
final agentTokenUsageRecordsProvider = AgentTokenUsageRecordsFamily._();

/// Raw token usage records for an agent.
///
/// Shared base provider that fetches `WakeTokenUsageEntity` records once;
/// both [agentTokenUsageSummariesProvider] and [tokenUsageForThreadProvider]
/// derive their state from this to avoid redundant database queries.

final class AgentTokenUsageRecordsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AgentDomainEntity>>,
          List<AgentDomainEntity>,
          FutureOr<List<AgentDomainEntity>>
        >
    with
        $FutureModifier<List<AgentDomainEntity>>,
        $FutureProvider<List<AgentDomainEntity>> {
  /// Raw token usage records for an agent.
  ///
  /// Shared base provider that fetches `WakeTokenUsageEntity` records once;
  /// both [agentTokenUsageSummariesProvider] and [tokenUsageForThreadProvider]
  /// derive their state from this to avoid redundant database queries.
  AgentTokenUsageRecordsProvider._({
    required AgentTokenUsageRecordsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'agentTokenUsageRecordsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$agentTokenUsageRecordsHash();

  @override
  String toString() {
    return r'agentTokenUsageRecordsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<AgentDomainEntity>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AgentDomainEntity>> create(Ref ref) {
    final argument = this.argument as String;
    return agentTokenUsageRecords(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AgentTokenUsageRecordsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$agentTokenUsageRecordsHash() =>
    r'97cb53f775d436d32ee05d210e6ccbe49f73ff92';

/// Raw token usage records for an agent.
///
/// Shared base provider that fetches `WakeTokenUsageEntity` records once;
/// both [agentTokenUsageSummariesProvider] and [tokenUsageForThreadProvider]
/// derive their state from this to avoid redundant database queries.

final class AgentTokenUsageRecordsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<AgentDomainEntity>>, String> {
  AgentTokenUsageRecordsFamily._()
    : super(
        retry: null,
        name: r'agentTokenUsageRecordsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Raw token usage records for an agent.
  ///
  /// Shared base provider that fetches `WakeTokenUsageEntity` records once;
  /// both [agentTokenUsageSummariesProvider] and [tokenUsageForThreadProvider]
  /// derive their state from this to avoid redundant database queries.

  AgentTokenUsageRecordsProvider call(String agentId) =>
      AgentTokenUsageRecordsProvider._(argument: agentId, from: this);

  @override
  String toString() => r'agentTokenUsageRecordsProvider';
}

/// Aggregated token usage summaries for an agent, grouped by model ID.
///
/// Derives from [agentTokenUsageRecordsProvider] and aggregates into
/// per-model summaries sorted by total tokens descending.

@ProviderFor(agentTokenUsageSummaries)
final agentTokenUsageSummariesProvider = AgentTokenUsageSummariesFamily._();

/// Aggregated token usage summaries for an agent, grouped by model ID.
///
/// Derives from [agentTokenUsageRecordsProvider] and aggregates into
/// per-model summaries sorted by total tokens descending.

final class AgentTokenUsageSummariesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AgentTokenUsageSummary>>,
          List<AgentTokenUsageSummary>,
          FutureOr<List<AgentTokenUsageSummary>>
        >
    with
        $FutureModifier<List<AgentTokenUsageSummary>>,
        $FutureProvider<List<AgentTokenUsageSummary>> {
  /// Aggregated token usage summaries for an agent, grouped by model ID.
  ///
  /// Derives from [agentTokenUsageRecordsProvider] and aggregates into
  /// per-model summaries sorted by total tokens descending.
  AgentTokenUsageSummariesProvider._({
    required AgentTokenUsageSummariesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'agentTokenUsageSummariesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$agentTokenUsageSummariesHash();

  @override
  String toString() {
    return r'agentTokenUsageSummariesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<AgentTokenUsageSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AgentTokenUsageSummary>> create(Ref ref) {
    final argument = this.argument as String;
    return agentTokenUsageSummaries(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AgentTokenUsageSummariesProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$agentTokenUsageSummariesHash() =>
    r'aa9171f9720a3cde05502ae56c2165fe5e8d3629';

/// Aggregated token usage summaries for an agent, grouped by model ID.
///
/// Derives from [agentTokenUsageRecordsProvider] and aggregates into
/// per-model summaries sorted by total tokens descending.

final class AgentTokenUsageSummariesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<AgentTokenUsageSummary>>,
          String
        > {
  AgentTokenUsageSummariesFamily._()
    : super(
        retry: null,
        name: r'agentTokenUsageSummariesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Aggregated token usage summaries for an agent, grouped by model ID.
  ///
  /// Derives from [agentTokenUsageRecordsProvider] and aggregates into
  /// per-model summaries sorted by total tokens descending.

  AgentTokenUsageSummariesProvider call(String agentId) =>
      AgentTokenUsageSummariesProvider._(argument: agentId, from: this);

  @override
  String toString() => r'agentTokenUsageSummariesProvider';
}

/// Aggregated token usage summary for a specific thread.
///
/// Derives from [agentTokenUsageRecordsProvider], filters by [threadId],
/// and folds into a single [AgentTokenUsageSummary].
/// Returns `null` if no records match.

@ProviderFor(tokenUsageForThread)
final tokenUsageForThreadProvider = TokenUsageForThreadFamily._();

/// Aggregated token usage summary for a specific thread.
///
/// Derives from [agentTokenUsageRecordsProvider], filters by [threadId],
/// and folds into a single [AgentTokenUsageSummary].
/// Returns `null` if no records match.

final class TokenUsageForThreadProvider
    extends
        $FunctionalProvider<
          AsyncValue<AgentTokenUsageSummary?>,
          AgentTokenUsageSummary?,
          FutureOr<AgentTokenUsageSummary?>
        >
    with
        $FutureModifier<AgentTokenUsageSummary?>,
        $FutureProvider<AgentTokenUsageSummary?> {
  /// Aggregated token usage summary for a specific thread.
  ///
  /// Derives from [agentTokenUsageRecordsProvider], filters by [threadId],
  /// and folds into a single [AgentTokenUsageSummary].
  /// Returns `null` if no records match.
  TokenUsageForThreadProvider._({
    required TokenUsageForThreadFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'tokenUsageForThreadProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$tokenUsageForThreadHash();

  @override
  String toString() {
    return r'tokenUsageForThreadProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<AgentTokenUsageSummary?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AgentTokenUsageSummary?> create(Ref ref) {
    final argument = this.argument as (String, String);
    return tokenUsageForThread(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is TokenUsageForThreadProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$tokenUsageForThreadHash() =>
    r'fec033cc79833df4fe232a60a0de55574b0fa3a8';

/// Aggregated token usage summary for a specific thread.
///
/// Derives from [agentTokenUsageRecordsProvider], filters by [threadId],
/// and folds into a single [AgentTokenUsageSummary].
/// Returns `null` if no records match.

final class TokenUsageForThreadFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<AgentTokenUsageSummary?>,
          (String, String)
        > {
  TokenUsageForThreadFamily._()
    : super(
        retry: null,
        name: r'tokenUsageForThreadProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Aggregated token usage summary for a specific thread.
  ///
  /// Derives from [agentTokenUsageRecordsProvider], filters by [threadId],
  /// and folds into a single [AgentTokenUsageSummary].
  /// Returns `null` if no records match.

  TokenUsageForThreadProvider call(String agentId, String threadId) =>
      TokenUsageForThreadProvider._(argument: (agentId, threadId), from: this);

  @override
  String toString() => r'tokenUsageForThreadProvider';
}

/// Resolve the model ID used for a specific wake thread.
///
/// Resolution order:
/// 1. [WakeTokenUsageEntity] — the actual model used at runtime, persisted
///    when the wake completes. Authoritative for completed threads.
/// 2. `resolvedModelId` on the wake-run log — the model ID persisted at
///    wake start after profile resolution. Accurate for failed/incomplete
///    wakes that never recorded token usage.
/// 3. Wake-run template version — the `profileId` or `modelId` snapshot
///    captured when the wake started. Fallback for older wake runs that
///    predate the `resolvedModelId` column.
/// 4. Live agent config — `profile.thinkingModelId` or `config.modelId` from
///    the agent instance's current config. Only used for in-flight
///    threads where the wake run hasn't been created yet.

@ProviderFor(modelIdForThread)
final modelIdForThreadProvider = ModelIdForThreadFamily._();

/// Resolve the model ID used for a specific wake thread.
///
/// Resolution order:
/// 1. [WakeTokenUsageEntity] — the actual model used at runtime, persisted
///    when the wake completes. Authoritative for completed threads.
/// 2. `resolvedModelId` on the wake-run log — the model ID persisted at
///    wake start after profile resolution. Accurate for failed/incomplete
///    wakes that never recorded token usage.
/// 3. Wake-run template version — the `profileId` or `modelId` snapshot
///    captured when the wake started. Fallback for older wake runs that
///    predate the `resolvedModelId` column.
/// 4. Live agent config — `profile.thinkingModelId` or `config.modelId` from
///    the agent instance's current config. Only used for in-flight
///    threads where the wake run hasn't been created yet.

final class ModelIdForThreadProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// Resolve the model ID used for a specific wake thread.
  ///
  /// Resolution order:
  /// 1. [WakeTokenUsageEntity] — the actual model used at runtime, persisted
  ///    when the wake completes. Authoritative for completed threads.
  /// 2. `resolvedModelId` on the wake-run log — the model ID persisted at
  ///    wake start after profile resolution. Accurate for failed/incomplete
  ///    wakes that never recorded token usage.
  /// 3. Wake-run template version — the `profileId` or `modelId` snapshot
  ///    captured when the wake started. Fallback for older wake runs that
  ///    predate the `resolvedModelId` column.
  /// 4. Live agent config — `profile.thinkingModelId` or `config.modelId` from
  ///    the agent instance's current config. Only used for in-flight
  ///    threads where the wake run hasn't been created yet.
  ModelIdForThreadProvider._({
    required ModelIdForThreadFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'modelIdForThreadProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$modelIdForThreadHash();

  @override
  String toString() {
    return r'modelIdForThreadProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    final argument = this.argument as (String, String);
    return modelIdForThread(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is ModelIdForThreadProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$modelIdForThreadHash() => r'52b5a54c860d7ceee7102634afece192f094a606';

/// Resolve the model ID used for a specific wake thread.
///
/// Resolution order:
/// 1. [WakeTokenUsageEntity] — the actual model used at runtime, persisted
///    when the wake completes. Authoritative for completed threads.
/// 2. `resolvedModelId` on the wake-run log — the model ID persisted at
///    wake start after profile resolution. Accurate for failed/incomplete
///    wakes that never recorded token usage.
/// 3. Wake-run template version — the `profileId` or `modelId` snapshot
///    captured when the wake started. Fallback for older wake runs that
///    predate the `resolvedModelId` column.
/// 4. Live agent config — `profile.thinkingModelId` or `config.modelId` from
///    the agent instance's current config. Only used for in-flight
///    threads where the wake run hasn't been created yet.

final class ModelIdForThreadFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, (String, String)> {
  ModelIdForThreadFamily._()
    : super(
        retry: null,
        name: r'modelIdForThreadProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Resolve the model ID used for a specific wake thread.
  ///
  /// Resolution order:
  /// 1. [WakeTokenUsageEntity] — the actual model used at runtime, persisted
  ///    when the wake completes. Authoritative for completed threads.
  /// 2. `resolvedModelId` on the wake-run log — the model ID persisted at
  ///    wake start after profile resolution. Accurate for failed/incomplete
  ///    wakes that never recorded token usage.
  /// 3. Wake-run template version — the `profileId` or `modelId` snapshot
  ///    captured when the wake started. Fallback for older wake runs that
  ///    predate the `resolvedModelId` column.
  /// 4. Live agent config — `profile.thinkingModelId` or `config.modelId` from
  ///    the agent instance's current config. Only used for in-flight
  ///    threads where the wake run hasn't been created yet.

  ModelIdForThreadProvider call(String agentId, String threadId) =>
      ModelIdForThreadProvider._(argument: (agentId, threadId), from: this);

  @override
  String toString() => r'modelIdForThreadProvider';
}
