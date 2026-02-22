// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_agent_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The task-agent-specific service.

@ProviderFor(taskAgentService)
final taskAgentServiceProvider = TaskAgentServiceProvider._();

/// The task-agent-specific service.

final class TaskAgentServiceProvider extends $FunctionalProvider<
    TaskAgentService,
    TaskAgentService,
    TaskAgentService> with $Provider<TaskAgentService> {
  /// The task-agent-specific service.
  TaskAgentServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'taskAgentServiceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$taskAgentServiceHash();

  @$internal
  @override
  $ProviderElement<TaskAgentService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TaskAgentService create(Ref ref) {
    return taskAgentService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskAgentService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskAgentService>(value),
    );
  }
}

String _$taskAgentServiceHash() => r'116d3e8c09ae3f50db6ad730aa54712739aee7be';

/// Fetch the Task Agent for a given journal-domain [taskId].
///
/// Returns [AgentDomainEntity] (variant: [AgentIdentityEntity]) or `null`.

@ProviderFor(taskAgent)
final taskAgentProvider = TaskAgentFamily._();

/// Fetch the Task Agent for a given journal-domain [taskId].
///
/// Returns [AgentDomainEntity] (variant: [AgentIdentityEntity]) or `null`.

final class TaskAgentProvider extends $FunctionalProvider<
        AsyncValue<AgentDomainEntity?>,
        AgentDomainEntity?,
        FutureOr<AgentDomainEntity?>>
    with
        $FutureModifier<AgentDomainEntity?>,
        $FutureProvider<AgentDomainEntity?> {
  /// Fetch the Task Agent for a given journal-domain [taskId].
  ///
  /// Returns [AgentDomainEntity] (variant: [AgentIdentityEntity]) or `null`.
  TaskAgentProvider._(
      {required TaskAgentFamily super.from, required String super.argument})
      : super(
          retry: null,
          name: r'taskAgentProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$taskAgentHash();

  @override
  String toString() {
    return r'taskAgentProvider'
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
    return taskAgent(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TaskAgentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$taskAgentHash() => r'cf4be5f17f0c44bab656fd99881bf918b6b4b356';

/// Fetch the Task Agent for a given journal-domain [taskId].
///
/// Returns [AgentDomainEntity] (variant: [AgentIdentityEntity]) or `null`.

final class TaskAgentFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<AgentDomainEntity?>, String> {
  TaskAgentFamily._()
      : super(
          retry: null,
          name: r'taskAgentProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Fetch the Task Agent for a given journal-domain [taskId].
  ///
  /// Returns [AgentDomainEntity] (variant: [AgentIdentityEntity]) or `null`.

  TaskAgentProvider call(
    String taskId,
  ) =>
      TaskAgentProvider._(argument: taskId, from: this);

  @override
  String toString() => r'taskAgentProvider';
}
