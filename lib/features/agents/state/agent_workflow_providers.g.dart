// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_workflow_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The template evolution workflow with all dependencies resolved.
///
/// Includes the multi-turn session dependencies (AgentTemplateService,
/// AgentSyncService) alongside the legacy single-turn dependencies.

@ProviderFor(templateEvolutionWorkflow)
final templateEvolutionWorkflowProvider = TemplateEvolutionWorkflowProvider._();

/// The template evolution workflow with all dependencies resolved.
///
/// Includes the multi-turn session dependencies (AgentTemplateService,
/// AgentSyncService) alongside the legacy single-turn dependencies.

final class TemplateEvolutionWorkflowProvider
    extends
        $FunctionalProvider<
          TemplateEvolutionWorkflow,
          TemplateEvolutionWorkflow,
          TemplateEvolutionWorkflow
        >
    with $Provider<TemplateEvolutionWorkflow> {
  /// The template evolution workflow with all dependencies resolved.
  ///
  /// Includes the multi-turn session dependencies (AgentTemplateService,
  /// AgentSyncService) alongside the legacy single-turn dependencies.
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
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

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
    r'32ca88370788579d0525b0aab76ae846ec6c0d37';

/// The improver agent workflow with all dependencies resolved.

@ProviderFor(improverAgentWorkflow)
final improverAgentWorkflowProvider = ImproverAgentWorkflowProvider._();

/// The improver agent workflow with all dependencies resolved.

final class ImproverAgentWorkflowProvider
    extends
        $FunctionalProvider<
          ImproverAgentWorkflow,
          ImproverAgentWorkflow,
          ImproverAgentWorkflow
        >
    with $Provider<ImproverAgentWorkflow> {
  /// The improver agent workflow with all dependencies resolved.
  ImproverAgentWorkflowProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'improverAgentWorkflowProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$improverAgentWorkflowHash();

  @$internal
  @override
  $ProviderElement<ImproverAgentWorkflow> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ImproverAgentWorkflow create(Ref ref) {
    return improverAgentWorkflow(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImproverAgentWorkflow value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImproverAgentWorkflow>(value),
    );
  }
}

String _$improverAgentWorkflowHash() =>
    r'aebcb692a46b2ad9d8e1460fcbbeba38fe49ec95';

/// The task agent workflow with all dependencies resolved.

@ProviderFor(taskAgentWorkflow)
final taskAgentWorkflowProvider = TaskAgentWorkflowProvider._();

/// The task agent workflow with all dependencies resolved.

final class TaskAgentWorkflowProvider
    extends
        $FunctionalProvider<
          TaskAgentWorkflow,
          TaskAgentWorkflow,
          TaskAgentWorkflow
        >
    with $Provider<TaskAgentWorkflow> {
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
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

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

String _$taskAgentWorkflowHash() => r'bd974a11188e1783248763437a94e15a5adf8a4f';

/// The project agent workflow with all dependencies resolved.

@ProviderFor(projectAgentWorkflow)
final projectAgentWorkflowProvider = ProjectAgentWorkflowProvider._();

/// The project agent workflow with all dependencies resolved.

final class ProjectAgentWorkflowProvider
    extends
        $FunctionalProvider<
          ProjectAgentWorkflow,
          ProjectAgentWorkflow,
          ProjectAgentWorkflow
        >
    with $Provider<ProjectAgentWorkflow> {
  /// The project agent workflow with all dependencies resolved.
  ProjectAgentWorkflowProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectAgentWorkflowProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectAgentWorkflowHash();

  @$internal
  @override
  $ProviderElement<ProjectAgentWorkflow> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProjectAgentWorkflow create(Ref ref) {
    return projectAgentWorkflow(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProjectAgentWorkflow value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProjectAgentWorkflow>(value),
    );
  }
}

String _$projectAgentWorkflowHash() =>
    r'514d729a91fdf599b4e7fc23e7473e1cc3a3c26b';
