// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_one_liner_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Fetches the AI-generated one-liner subtitle for a project from its agent
/// report.
///
/// Chains [projectAgentProvider] to resolve the project's agent, then watches
/// [agentReportProvider] for the latest report and extracts the [oneLiner]
/// field. Auto-disposes when the project card scrolls off-screen.

@ProviderFor(projectOneLiner)
final projectOneLinerProvider = ProjectOneLinerFamily._();

/// Fetches the AI-generated one-liner subtitle for a project from its agent
/// report.
///
/// Chains [projectAgentProvider] to resolve the project's agent, then watches
/// [agentReportProvider] for the latest report and extracts the [oneLiner]
/// field. Auto-disposes when the project card scrolls off-screen.

final class ProjectOneLinerProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// Fetches the AI-generated one-liner subtitle for a project from its agent
  /// report.
  ///
  /// Chains [projectAgentProvider] to resolve the project's agent, then watches
  /// [agentReportProvider] for the latest report and extracts the [oneLiner]
  /// field. Auto-disposes when the project card scrolls off-screen.
  ProjectOneLinerProvider._({
    required ProjectOneLinerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'projectOneLinerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$projectOneLinerHash();

  @override
  String toString() {
    return r'projectOneLinerProvider'
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
    return projectOneLiner(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ProjectOneLinerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$projectOneLinerHash() => r'1519ce99e2f0d63f7859ce894925307f26df9bab';

/// Fetches the AI-generated one-liner subtitle for a project from its agent
/// report.
///
/// Chains [projectAgentProvider] to resolve the project's agent, then watches
/// [agentReportProvider] for the latest report and extracts the [oneLiner]
/// field. Auto-disposes when the project card scrolls off-screen.

final class ProjectOneLinerFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, String> {
  ProjectOneLinerFamily._()
    : super(
        retry: null,
        name: r'projectOneLinerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Fetches the AI-generated one-liner subtitle for a project from its agent
  /// report.
  ///
  /// Chains [projectAgentProvider] to resolve the project's agent, then watches
  /// [agentReportProvider] for the latest report and extracts the [oneLiner]
  /// field. Auto-disposes when the project card scrolls off-screen.

  ProjectOneLinerProvider call(String projectId) =>
      ProjectOneLinerProvider._(argument: projectId, from: this);

  @override
  String toString() => r'projectOneLinerProvider';
}
