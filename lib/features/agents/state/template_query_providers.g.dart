// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'template_query_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// List all non-deleted agent templates.

@ProviderFor(agentTemplates)
final agentTemplatesProvider = AgentTemplatesProvider._();

/// List all non-deleted agent templates.

final class AgentTemplatesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AgentDomainEntity>>,
          List<AgentDomainEntity>,
          FutureOr<List<AgentDomainEntity>>
        >
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
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AgentDomainEntity>> create(Ref ref) {
    return agentTemplates(ref);
  }
}

String _$agentTemplatesHash() => r'11181589ced963f8f4bbf169e06f8d82e1667045';

/// List all evolution sessions across all templates.
///
/// Uses a single DB query instead of N per-template lookups.
/// Reactively rebuilds when any agent data changes.

@ProviderFor(allEvolutionSessions)
final allEvolutionSessionsProvider = AllEvolutionSessionsProvider._();

/// List all evolution sessions across all templates.
///
/// Uses a single DB query instead of N per-template lookups.
/// Reactively rebuilds when any agent data changes.

final class AllEvolutionSessionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AgentDomainEntity>>,
          List<AgentDomainEntity>,
          FutureOr<List<AgentDomainEntity>>
        >
    with
        $FutureModifier<List<AgentDomainEntity>>,
        $FutureProvider<List<AgentDomainEntity>> {
  /// List all evolution sessions across all templates.
  ///
  /// Uses a single DB query instead of N per-template lookups.
  /// Reactively rebuilds when any agent data changes.
  AllEvolutionSessionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allEvolutionSessionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allEvolutionSessionsHash();

  @$internal
  @override
  $FutureProviderElement<List<AgentDomainEntity>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AgentDomainEntity>> create(Ref ref) {
    return allEvolutionSessions(ref);
  }
}

String _$allEvolutionSessionsHash() =>
    r'153c4d3836856ce6a7a3d1a0a1492066e1cc5468';

/// Fetch a single agent template by [templateId].
///
/// The returned entity is an [AgentTemplateEntity] (or `null`).

@ProviderFor(agentTemplate)
final agentTemplateProvider = AgentTemplateFamily._();

/// Fetch a single agent template by [templateId].
///
/// The returned entity is an [AgentTemplateEntity] (or `null`).

final class AgentTemplateProvider
    extends
        $FunctionalProvider<
          AsyncValue<AgentDomainEntity?>,
          AgentDomainEntity?,
          FutureOr<AgentDomainEntity?>
        >
    with
        $FutureModifier<AgentDomainEntity?>,
        $FutureProvider<AgentDomainEntity?> {
  /// Fetch a single agent template by [templateId].
  ///
  /// The returned entity is an [AgentTemplateEntity] (or `null`).
  AgentTemplateProvider._({
    required AgentTemplateFamily super.from,
    required String super.argument,
  }) : super(
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
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AgentDomainEntity?> create(Ref ref) {
    final argument = this.argument as String;
    return agentTemplate(ref, argument);
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

  AgentTemplateProvider call(String templateId) =>
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

final class ActiveTemplateVersionProvider
    extends
        $FunctionalProvider<
          AsyncValue<AgentDomainEntity?>,
          AgentDomainEntity?,
          FutureOr<AgentDomainEntity?>
        >
    with
        $FutureModifier<AgentDomainEntity?>,
        $FutureProvider<AgentDomainEntity?> {
  /// Fetch the active version for a template by [templateId].
  ///
  /// The returned entity is an [AgentTemplateVersionEntity] (or `null`).
  ActiveTemplateVersionProvider._({
    required ActiveTemplateVersionFamily super.from,
    required String super.argument,
  }) : super(
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
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AgentDomainEntity?> create(Ref ref) {
    final argument = this.argument as String;
    return activeTemplateVersion(ref, argument);
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

  ActiveTemplateVersionProvider call(String templateId) =>
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

final class TemplateVersionHistoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AgentDomainEntity>>,
          List<AgentDomainEntity>,
          FutureOr<List<AgentDomainEntity>>
        >
    with
        $FutureModifier<List<AgentDomainEntity>>,
        $FutureProvider<List<AgentDomainEntity>> {
  /// Fetch the version history for a template by [templateId].
  ///
  /// Each element is an [AgentTemplateVersionEntity].
  TemplateVersionHistoryProvider._({
    required TemplateVersionHistoryFamily super.from,
    required String super.argument,
  }) : super(
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
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AgentDomainEntity>> create(Ref ref) {
    final argument = this.argument as String;
    return templateVersionHistory(ref, argument);
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

  TemplateVersionHistoryProvider call(String templateId) =>
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

final class TemplateForAgentProvider
    extends
        $FunctionalProvider<
          AsyncValue<AgentDomainEntity?>,
          AgentDomainEntity?,
          FutureOr<AgentDomainEntity?>
        >
    with
        $FutureModifier<AgentDomainEntity?>,
        $FutureProvider<AgentDomainEntity?> {
  /// Resolve the template assigned to an agent by [agentId].
  ///
  /// The returned entity is an [AgentTemplateEntity] (or `null`).
  TemplateForAgentProvider._({
    required TemplateForAgentFamily super.from,
    required String super.argument,
  }) : super(
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
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AgentDomainEntity?> create(Ref ref) {
    final argument = this.argument as String;
    return templateForAgent(ref, argument);
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

  TemplateForAgentProvider call(String agentId) =>
      TemplateForAgentProvider._(argument: agentId, from: this);

  @override
  String toString() => r'templateForAgentProvider';
}

/// Raw token usage records for all instances of a template.
///
/// Uses a SQL JOIN via `template_assignment` links to fetch all
/// [WakeTokenUsageEntity] records across every instance in a single query.

@ProviderFor(templateTokenUsageRecords)
final templateTokenUsageRecordsProvider = TemplateTokenUsageRecordsFamily._();

/// Raw token usage records for all instances of a template.
///
/// Uses a SQL JOIN via `template_assignment` links to fetch all
/// [WakeTokenUsageEntity] records across every instance in a single query.

final class TemplateTokenUsageRecordsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AgentDomainEntity>>,
          List<AgentDomainEntity>,
          FutureOr<List<AgentDomainEntity>>
        >
    with
        $FutureModifier<List<AgentDomainEntity>>,
        $FutureProvider<List<AgentDomainEntity>> {
  /// Raw token usage records for all instances of a template.
  ///
  /// Uses a SQL JOIN via `template_assignment` links to fetch all
  /// [WakeTokenUsageEntity] records across every instance in a single query.
  TemplateTokenUsageRecordsProvider._({
    required TemplateTokenUsageRecordsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'templateTokenUsageRecordsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$templateTokenUsageRecordsHash();

  @override
  String toString() {
    return r'templateTokenUsageRecordsProvider'
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
    return templateTokenUsageRecords(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TemplateTokenUsageRecordsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$templateTokenUsageRecordsHash() =>
    r'c6dcc9098d271f94adea512ee30854ff46e2c6aa';

/// Raw token usage records for all instances of a template.
///
/// Uses a SQL JOIN via `template_assignment` links to fetch all
/// [WakeTokenUsageEntity] records across every instance in a single query.

final class TemplateTokenUsageRecordsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<AgentDomainEntity>>, String> {
  TemplateTokenUsageRecordsFamily._()
    : super(
        retry: null,
        name: r'templateTokenUsageRecordsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Raw token usage records for all instances of a template.
  ///
  /// Uses a SQL JOIN via `template_assignment` links to fetch all
  /// [WakeTokenUsageEntity] records across every instance in a single query.

  TemplateTokenUsageRecordsProvider call(String templateId) =>
      TemplateTokenUsageRecordsProvider._(argument: templateId, from: this);

  @override
  String toString() => r'templateTokenUsageRecordsProvider';
}

/// Aggregated token usage summaries for a template, grouped by model ID.
///
/// Derives from [templateTokenUsageRecordsProvider] and aggregates into
/// per-model summaries sorted by total tokens descending.

@ProviderFor(templateTokenUsageSummaries)
final templateTokenUsageSummariesProvider =
    TemplateTokenUsageSummariesFamily._();

/// Aggregated token usage summaries for a template, grouped by model ID.
///
/// Derives from [templateTokenUsageRecordsProvider] and aggregates into
/// per-model summaries sorted by total tokens descending.

final class TemplateTokenUsageSummariesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AgentTokenUsageSummary>>,
          List<AgentTokenUsageSummary>,
          FutureOr<List<AgentTokenUsageSummary>>
        >
    with
        $FutureModifier<List<AgentTokenUsageSummary>>,
        $FutureProvider<List<AgentTokenUsageSummary>> {
  /// Aggregated token usage summaries for a template, grouped by model ID.
  ///
  /// Derives from [templateTokenUsageRecordsProvider] and aggregates into
  /// per-model summaries sorted by total tokens descending.
  TemplateTokenUsageSummariesProvider._({
    required TemplateTokenUsageSummariesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'templateTokenUsageSummariesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$templateTokenUsageSummariesHash();

  @override
  String toString() {
    return r'templateTokenUsageSummariesProvider'
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
    return templateTokenUsageSummaries(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TemplateTokenUsageSummariesProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$templateTokenUsageSummariesHash() =>
    r'6354f57d4f13e37d05bcacc2f753060a4965bfd6';

/// Aggregated token usage summaries for a template, grouped by model ID.
///
/// Derives from [templateTokenUsageRecordsProvider] and aggregates into
/// per-model summaries sorted by total tokens descending.

final class TemplateTokenUsageSummariesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<AgentTokenUsageSummary>>,
          String
        > {
  TemplateTokenUsageSummariesFamily._()
    : super(
        retry: null,
        name: r'templateTokenUsageSummariesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Aggregated token usage summaries for a template, grouped by model ID.
  ///
  /// Derives from [templateTokenUsageRecordsProvider] and aggregates into
  /// per-model summaries sorted by total tokens descending.

  TemplateTokenUsageSummariesProvider call(String templateId) =>
      TemplateTokenUsageSummariesProvider._(argument: templateId, from: this);

  @override
  String toString() => r'templateTokenUsageSummariesProvider';
}

/// Per-instance token usage breakdown for a template.
///
/// Groups token records by instance, then by model within each instance.
/// Returns full per-model summaries so each instance can render a
/// `TokenUsageTable` identical in structure to the aggregate view.

@ProviderFor(templateInstanceTokenBreakdown)
final templateInstanceTokenBreakdownProvider =
    TemplateInstanceTokenBreakdownFamily._();

/// Per-instance token usage breakdown for a template.
///
/// Groups token records by instance, then by model within each instance.
/// Returns full per-model summaries so each instance can render a
/// `TokenUsageTable` identical in structure to the aggregate view.

final class TemplateInstanceTokenBreakdownProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<InstanceTokenBreakdown>>,
          List<InstanceTokenBreakdown>,
          FutureOr<List<InstanceTokenBreakdown>>
        >
    with
        $FutureModifier<List<InstanceTokenBreakdown>>,
        $FutureProvider<List<InstanceTokenBreakdown>> {
  /// Per-instance token usage breakdown for a template.
  ///
  /// Groups token records by instance, then by model within each instance.
  /// Returns full per-model summaries so each instance can render a
  /// `TokenUsageTable` identical in structure to the aggregate view.
  TemplateInstanceTokenBreakdownProvider._({
    required TemplateInstanceTokenBreakdownFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'templateInstanceTokenBreakdownProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$templateInstanceTokenBreakdownHash();

  @override
  String toString() {
    return r'templateInstanceTokenBreakdownProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<InstanceTokenBreakdown>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<InstanceTokenBreakdown>> create(Ref ref) {
    final argument = this.argument as String;
    return templateInstanceTokenBreakdown(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TemplateInstanceTokenBreakdownProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$templateInstanceTokenBreakdownHash() =>
    r'b430e57d8f1a1a9c4ab11f624a31256280010a25';

/// Per-instance token usage breakdown for a template.
///
/// Groups token records by instance, then by model within each instance.
/// Returns full per-model summaries so each instance can render a
/// `TokenUsageTable` identical in structure to the aggregate view.

final class TemplateInstanceTokenBreakdownFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<InstanceTokenBreakdown>>,
          String
        > {
  TemplateInstanceTokenBreakdownFamily._()
    : super(
        retry: null,
        name: r'templateInstanceTokenBreakdownProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Per-instance token usage breakdown for a template.
  ///
  /// Groups token records by instance, then by model within each instance.
  /// Returns full per-model summaries so each instance can render a
  /// `TokenUsageTable` identical in structure to the aggregate view.

  TemplateInstanceTokenBreakdownProvider call(String templateId) =>
      TemplateInstanceTokenBreakdownProvider._(
        argument: templateId,
        from: this,
      );

  @override
  String toString() => r'templateInstanceTokenBreakdownProvider';
}

/// Recent reports from all instances of a template, newest-first.

@ProviderFor(templateRecentReports)
final templateRecentReportsProvider = TemplateRecentReportsFamily._();

/// Recent reports from all instances of a template, newest-first.

final class TemplateRecentReportsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AgentDomainEntity>>,
          List<AgentDomainEntity>,
          FutureOr<List<AgentDomainEntity>>
        >
    with
        $FutureModifier<List<AgentDomainEntity>>,
        $FutureProvider<List<AgentDomainEntity>> {
  /// Recent reports from all instances of a template, newest-first.
  TemplateRecentReportsProvider._({
    required TemplateRecentReportsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'templateRecentReportsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$templateRecentReportsHash();

  @override
  String toString() {
    return r'templateRecentReportsProvider'
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
    return templateRecentReports(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TemplateRecentReportsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$templateRecentReportsHash() =>
    r'f535575fd5cb3d47a105258226b9ca7c0a1c8c45';

/// Recent reports from all instances of a template, newest-first.

final class TemplateRecentReportsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<AgentDomainEntity>>, String> {
  TemplateRecentReportsFamily._()
    : super(
        retry: null,
        name: r'templateRecentReportsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Recent reports from all instances of a template, newest-first.

  TemplateRecentReportsProvider call(String templateId) =>
      TemplateRecentReportsProvider._(argument: templateId, from: this);

  @override
  String toString() => r'templateRecentReportsProvider';
}

/// Computed performance metrics for a template by [templateId].

@ProviderFor(templatePerformanceMetrics)
final templatePerformanceMetricsProvider = TemplatePerformanceMetricsFamily._();

/// Computed performance metrics for a template by [templateId].

final class TemplatePerformanceMetricsProvider
    extends
        $FunctionalProvider<
          AsyncValue<TemplatePerformanceMetrics>,
          TemplatePerformanceMetrics,
          FutureOr<TemplatePerformanceMetrics>
        >
    with
        $FutureModifier<TemplatePerformanceMetrics>,
        $FutureProvider<TemplatePerformanceMetrics> {
  /// Computed performance metrics for a template by [templateId].
  TemplatePerformanceMetricsProvider._({
    required TemplatePerformanceMetricsFamily super.from,
    required String super.argument,
  }) : super(
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
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TemplatePerformanceMetrics> create(Ref ref) {
    final argument = this.argument as String;
    return templatePerformanceMetrics(ref, argument);
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
        $FunctionalFamilyOverride<
          FutureOr<TemplatePerformanceMetrics>,
          String
        > {
  TemplatePerformanceMetricsFamily._()
    : super(
        retry: null,
        name: r'templatePerformanceMetricsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Computed performance metrics for a template by [templateId].

  TemplatePerformanceMetricsProvider call(String templateId) =>
      TemplatePerformanceMetricsProvider._(argument: templateId, from: this);

  @override
  String toString() => r'templatePerformanceMetricsProvider';
}

/// Fetch evolution sessions for a template, newest-first.
///
/// Each element is an [EvolutionSessionEntity].

@ProviderFor(evolutionSessions)
final evolutionSessionsProvider = EvolutionSessionsFamily._();

/// Fetch evolution sessions for a template, newest-first.
///
/// Each element is an [EvolutionSessionEntity].

final class EvolutionSessionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AgentDomainEntity>>,
          List<AgentDomainEntity>,
          FutureOr<List<AgentDomainEntity>>
        >
    with
        $FutureModifier<List<AgentDomainEntity>>,
        $FutureProvider<List<AgentDomainEntity>> {
  /// Fetch evolution sessions for a template, newest-first.
  ///
  /// Each element is an [EvolutionSessionEntity].
  EvolutionSessionsProvider._({
    required EvolutionSessionsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'evolutionSessionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$evolutionSessionsHash();

  @override
  String toString() {
    return r'evolutionSessionsProvider'
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
    return evolutionSessions(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is EvolutionSessionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$evolutionSessionsHash() => r'ef8a181ac6caa5ef8b25bfc0da4b6906abd78704';

/// Fetch evolution sessions for a template, newest-first.
///
/// Each element is an [EvolutionSessionEntity].

final class EvolutionSessionsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<AgentDomainEntity>>, String> {
  EvolutionSessionsFamily._()
    : super(
        retry: null,
        name: r'evolutionSessionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Fetch evolution sessions for a template, newest-first.
  ///
  /// Each element is an [EvolutionSessionEntity].

  EvolutionSessionsProvider call(String templateId) =>
      EvolutionSessionsProvider._(argument: templateId, from: this);

  @override
  String toString() => r'evolutionSessionsProvider';
}

/// Fetch evolution notes for a template, newest-first.
///
/// Each element is an [EvolutionNoteEntity].

@ProviderFor(evolutionNotes)
final evolutionNotesProvider = EvolutionNotesFamily._();

/// Fetch evolution notes for a template, newest-first.
///
/// Each element is an [EvolutionNoteEntity].

final class EvolutionNotesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AgentDomainEntity>>,
          List<AgentDomainEntity>,
          FutureOr<List<AgentDomainEntity>>
        >
    with
        $FutureModifier<List<AgentDomainEntity>>,
        $FutureProvider<List<AgentDomainEntity>> {
  /// Fetch evolution notes for a template, newest-first.
  ///
  /// Each element is an [EvolutionNoteEntity].
  EvolutionNotesProvider._({
    required EvolutionNotesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'evolutionNotesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$evolutionNotesHash();

  @override
  String toString() {
    return r'evolutionNotesProvider'
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
    return evolutionNotes(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is EvolutionNotesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$evolutionNotesHash() => r'642ee87e1dffe4d6a44e65b21a651c902eeb99ae';

/// Fetch evolution notes for a template, newest-first.
///
/// Each element is an [EvolutionNoteEntity].

final class EvolutionNotesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<AgentDomainEntity>>, String> {
  EvolutionNotesFamily._()
    : super(
        retry: null,
        name: r'evolutionNotesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Fetch evolution notes for a template, newest-first.
  ///
  /// Each element is an [EvolutionNoteEntity].

  EvolutionNotesProvider call(String templateId) =>
      EvolutionNotesProvider._(argument: templateId, from: this);

  @override
  String toString() => r'evolutionNotesProvider';
}
