// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_agent_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The project-agent-specific service.

@ProviderFor(projectAgentService)
final projectAgentServiceProvider = ProjectAgentServiceProvider._();

/// The project-agent-specific service.

final class ProjectAgentServiceProvider
    extends
        $FunctionalProvider<
          ProjectAgentService,
          ProjectAgentService,
          ProjectAgentService
        >
    with $Provider<ProjectAgentService> {
  /// The project-agent-specific service.
  ProjectAgentServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectAgentServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectAgentServiceHash();

  @$internal
  @override
  $ProviderElement<ProjectAgentService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProjectAgentService create(Ref ref) {
    return projectAgentService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProjectAgentService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProjectAgentService>(value),
    );
  }
}

String _$projectAgentServiceHash() =>
    r'f55f3d97fcf83a838be37b352e84aa046f539334';

/// Fetch the Project Agent for a given journal-domain [projectId].
///
/// Returns [AgentDomainEntity] (variant: [AgentIdentityEntity]) or `null`.
/// Watches the update stream so the UI rebuilds when an agent-project link
/// arrives via sync.

@ProviderFor(projectAgent)
final projectAgentProvider = ProjectAgentFamily._();

/// Fetch the Project Agent for a given journal-domain [projectId].
///
/// Returns [AgentDomainEntity] (variant: [AgentIdentityEntity]) or `null`.
/// Watches the update stream so the UI rebuilds when an agent-project link
/// arrives via sync.

final class ProjectAgentProvider
    extends
        $FunctionalProvider<
          AsyncValue<AgentDomainEntity?>,
          AgentDomainEntity?,
          FutureOr<AgentDomainEntity?>
        >
    with
        $FutureModifier<AgentDomainEntity?>,
        $FutureProvider<AgentDomainEntity?> {
  /// Fetch the Project Agent for a given journal-domain [projectId].
  ///
  /// Returns [AgentDomainEntity] (variant: [AgentIdentityEntity]) or `null`.
  /// Watches the update stream so the UI rebuilds when an agent-project link
  /// arrives via sync.
  ProjectAgentProvider._({
    required ProjectAgentFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'projectAgentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$projectAgentHash();

  @override
  String toString() {
    return r'projectAgentProvider'
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
    return projectAgent(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ProjectAgentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$projectAgentHash() => r'a7826aee3ba61d21398f9e465ac3c06439022a2c';

/// Fetch the Project Agent for a given journal-domain [projectId].
///
/// Returns [AgentDomainEntity] (variant: [AgentIdentityEntity]) or `null`.
/// Watches the update stream so the UI rebuilds when an agent-project link
/// arrives via sync.

final class ProjectAgentFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<AgentDomainEntity?>, String> {
  ProjectAgentFamily._()
    : super(
        retry: null,
        name: r'projectAgentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Fetch the Project Agent for a given journal-domain [projectId].
  ///
  /// Returns [AgentDomainEntity] (variant: [AgentIdentityEntity]) or `null`.
  /// Watches the update stream so the UI rebuilds when an agent-project link
  /// arrives via sync.

  ProjectAgentProvider call(String projectId) =>
      ProjectAgentProvider._(argument: projectId, from: this);

  @override
  String toString() => r'projectAgentProvider';
}
