// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'change_set_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Fetches pending (and partially resolved) change sets for a given task.
///
/// Resolves the task's agent via [taskAgentProvider], then watches the
/// [agentUpdateStreamProvider] for reactive invalidation, and finally
/// queries the repository.

@ProviderFor(pendingChangeSets)
final pendingChangeSetsProvider = PendingChangeSetsFamily._();

/// Fetches pending (and partially resolved) change sets for a given task.
///
/// Resolves the task's agent via [taskAgentProvider], then watches the
/// [agentUpdateStreamProvider] for reactive invalidation, and finally
/// queries the repository.

final class PendingChangeSetsProvider extends $FunctionalProvider<
        AsyncValue<List<AgentDomainEntity>>,
        List<AgentDomainEntity>,
        FutureOr<List<AgentDomainEntity>>>
    with
        $FutureModifier<List<AgentDomainEntity>>,
        $FutureProvider<List<AgentDomainEntity>> {
  /// Fetches pending (and partially resolved) change sets for a given task.
  ///
  /// Resolves the task's agent via [taskAgentProvider], then watches the
  /// [agentUpdateStreamProvider] for reactive invalidation, and finally
  /// queries the repository.
  PendingChangeSetsProvider._(
      {required PendingChangeSetsFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'pendingChangeSetsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$pendingChangeSetsHash();

  @override
  String toString() {
    return r'pendingChangeSetsProvider'
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
    return pendingChangeSets(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PendingChangeSetsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pendingChangeSetsHash() => r'dd6bb4fde81b742c3f2736fd38ebe63fcf1c9db9';

/// Fetches pending (and partially resolved) change sets for a given task.
///
/// Resolves the task's agent via [taskAgentProvider], then watches the
/// [agentUpdateStreamProvider] for reactive invalidation, and finally
/// queries the repository.

final class PendingChangeSetsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<AgentDomainEntity>>, String> {
  PendingChangeSetsFamily._()
      : super(
          retry: null,
          name: r'pendingChangeSetsProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Fetches pending (and partially resolved) change sets for a given task.
  ///
  /// Resolves the task's agent via [taskAgentProvider], then watches the
  /// [agentUpdateStreamProvider] for reactive invalidation, and finally
  /// queries the repository.

  PendingChangeSetsProvider call(
    String taskId,
  ) =>
      PendingChangeSetsProvider._(argument: taskId, from: this);

  @override
  String toString() => r'pendingChangeSetsProvider';
}

/// Provides a [ChangeSetConfirmationService] with all dependencies resolved.

@ProviderFor(changeSetConfirmationService)
final changeSetConfirmationServiceProvider =
    ChangeSetConfirmationServiceProvider._();

/// Provides a [ChangeSetConfirmationService] with all dependencies resolved.

final class ChangeSetConfirmationServiceProvider extends $FunctionalProvider<
    ChangeSetConfirmationService,
    ChangeSetConfirmationService,
    ChangeSetConfirmationService> with $Provider<ChangeSetConfirmationService> {
  /// Provides a [ChangeSetConfirmationService] with all dependencies resolved.
  ChangeSetConfirmationServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'changeSetConfirmationServiceProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$changeSetConfirmationServiceHash();

  @$internal
  @override
  $ProviderElement<ChangeSetConfirmationService> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ChangeSetConfirmationService create(Ref ref) {
    return changeSetConfirmationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChangeSetConfirmationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChangeSetConfirmationService>(value),
    );
  }
}

String _$changeSetConfirmationServiceHash() =>
    r'3d2d94bda7f748554325bcb71d37e80e082e5d51';
