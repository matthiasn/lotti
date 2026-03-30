// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ritual_review_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Returns the most recent active [EvolutionSessionEntity] for a template,
/// or `null` if there is no active session pending review.
///
/// Only the newest session is considered: if a newer completed or abandoned
/// session exists, older active sessions are treated as stale and ignored.
/// Actual DB reconciliation (marking stale sessions as abandoned) happens
/// in `TemplateEvolutionWorkflow` during startSession/approveProposal.
///
/// Reuses the cached [evolutionSessionsProvider] to avoid extra DB queries.

@ProviderFor(pendingRitualReview)
final pendingRitualReviewProvider = PendingRitualReviewFamily._();

/// Returns the most recent active [EvolutionSessionEntity] for a template,
/// or `null` if there is no active session pending review.
///
/// Only the newest session is considered: if a newer completed or abandoned
/// session exists, older active sessions are treated as stale and ignored.
/// Actual DB reconciliation (marking stale sessions as abandoned) happens
/// in `TemplateEvolutionWorkflow` during startSession/approveProposal.
///
/// Reuses the cached [evolutionSessionsProvider] to avoid extra DB queries.

final class PendingRitualReviewProvider
    extends
        $FunctionalProvider<
          AsyncValue<AgentDomainEntity?>,
          AgentDomainEntity?,
          FutureOr<AgentDomainEntity?>
        >
    with
        $FutureModifier<AgentDomainEntity?>,
        $FutureProvider<AgentDomainEntity?> {
  /// Returns the most recent active [EvolutionSessionEntity] for a template,
  /// or `null` if there is no active session pending review.
  ///
  /// Only the newest session is considered: if a newer completed or abandoned
  /// session exists, older active sessions are treated as stale and ignored.
  /// Actual DB reconciliation (marking stale sessions as abandoned) happens
  /// in `TemplateEvolutionWorkflow` during startSession/approveProposal.
  ///
  /// Reuses the cached [evolutionSessionsProvider] to avoid extra DB queries.
  PendingRitualReviewProvider._({
    required PendingRitualReviewFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'pendingRitualReviewProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$pendingRitualReviewHash();

  @override
  String toString() {
    return r'pendingRitualReviewProvider'
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
    return pendingRitualReview(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PendingRitualReviewProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pendingRitualReviewHash() =>
    r'ed6c31af16a65acf2b44a343793c81efca486905';

/// Returns the most recent active [EvolutionSessionEntity] for a template,
/// or `null` if there is no active session pending review.
///
/// Only the newest session is considered: if a newer completed or abandoned
/// session exists, older active sessions are treated as stale and ignored.
/// Actual DB reconciliation (marking stale sessions as abandoned) happens
/// in `TemplateEvolutionWorkflow` during startSession/approveProposal.
///
/// Reuses the cached [evolutionSessionsProvider] to avoid extra DB queries.

final class PendingRitualReviewFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<AgentDomainEntity?>, String> {
  PendingRitualReviewFamily._()
    : super(
        retry: null,
        name: r'pendingRitualReviewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Returns the most recent active [EvolutionSessionEntity] for a template,
  /// or `null` if there is no active session pending review.
  ///
  /// Only the newest session is considered: if a newer completed or abandoned
  /// session exists, older active sessions are treated as stale and ignored.
  /// Actual DB reconciliation (marking stale sessions as abandoned) happens
  /// in `TemplateEvolutionWorkflow` during startSession/approveProposal.
  ///
  /// Reuses the cached [evolutionSessionsProvider] to avoid extra DB queries.

  PendingRitualReviewProvider call(String templateId) =>
      PendingRitualReviewProvider._(argument: templateId, from: this);

  @override
  String toString() => r'pendingRitualReviewProvider';
}

/// Extracts classified feedback for a template's review window.
///
/// Uses the feedback extraction service to scan the default 7-day window.

@ProviderFor(ritualFeedback)
final ritualFeedbackProvider = RitualFeedbackFamily._();

/// Extracts classified feedback for a template's review window.
///
/// Uses the feedback extraction service to scan the default 7-day window.

final class RitualFeedbackProvider
    extends
        $FunctionalProvider<
          AsyncValue<ClassifiedFeedback?>,
          ClassifiedFeedback?,
          FutureOr<ClassifiedFeedback?>
        >
    with
        $FutureModifier<ClassifiedFeedback?>,
        $FutureProvider<ClassifiedFeedback?> {
  /// Extracts classified feedback for a template's review window.
  ///
  /// Uses the feedback extraction service to scan the default 7-day window.
  RitualFeedbackProvider._({
    required RitualFeedbackFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'ritualFeedbackProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$ritualFeedbackHash();

  @override
  String toString() {
    return r'ritualFeedbackProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ClassifiedFeedback?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ClassifiedFeedback?> create(Ref ref) {
    final argument = this.argument as String;
    return ritualFeedback(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RitualFeedbackProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$ritualFeedbackHash() => r'd3e42e53d99d0f7d6534e2b8f620bfc37122ed69';

/// Extracts classified feedback for a template's review window.
///
/// Uses the feedback extraction service to scan the default 7-day window.

final class RitualFeedbackFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ClassifiedFeedback?>, String> {
  RitualFeedbackFamily._()
    : super(
        retry: null,
        name: r'ritualFeedbackProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Extracts classified feedback for a template's review window.
  ///
  /// Uses the feedback extraction service to scan the default 7-day window.

  RitualFeedbackProvider call(String templateId) =>
      RitualFeedbackProvider._(argument: templateId, from: this);

  @override
  String toString() => r'ritualFeedbackProvider';
}

/// Set of template IDs with pending rituals.

@ProviderFor(templatesPendingReview)
final templatesPendingReviewProvider = TemplatesPendingReviewProvider._();

/// Set of template IDs with pending rituals.

final class TemplatesPendingReviewProvider
    extends
        $FunctionalProvider<
          AsyncValue<Set<String>>,
          Set<String>,
          FutureOr<Set<String>>
        >
    with $FutureModifier<Set<String>>, $FutureProvider<Set<String>> {
  /// Set of template IDs with pending rituals.
  TemplatesPendingReviewProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'templatesPendingReviewProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$templatesPendingReviewHash();

  @$internal
  @override
  $FutureProviderElement<Set<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Set<String>> create(Ref ref) {
    return templatesPendingReview(ref);
  }
}

String _$templatesPendingReviewHash() =>
    r'dab44fe4ff0524f11d581ac9b6b1fd2a728d4373';

/// Aggregate stats for evolution sessions of a template.

@ProviderFor(evolutionSessionStats)
final evolutionSessionStatsProvider = EvolutionSessionStatsFamily._();

/// Aggregate stats for evolution sessions of a template.

final class EvolutionSessionStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<EvolutionSessionStats>,
          EvolutionSessionStats,
          FutureOr<EvolutionSessionStats>
        >
    with
        $FutureModifier<EvolutionSessionStats>,
        $FutureProvider<EvolutionSessionStats> {
  /// Aggregate stats for evolution sessions of a template.
  EvolutionSessionStatsProvider._({
    required EvolutionSessionStatsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'evolutionSessionStatsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$evolutionSessionStatsHash();

  @override
  String toString() {
    return r'evolutionSessionStatsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<EvolutionSessionStats> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<EvolutionSessionStats> create(Ref ref) {
    final argument = this.argument as String;
    return evolutionSessionStats(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is EvolutionSessionStatsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$evolutionSessionStatsHash() =>
    r'494f006a3c961bd0d493b2de57bedb1afca8e582';

/// Aggregate stats for evolution sessions of a template.

final class EvolutionSessionStatsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<EvolutionSessionStats>, String> {
  EvolutionSessionStatsFamily._()
    : super(
        retry: null,
        name: r'evolutionSessionStatsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Aggregate stats for evolution sessions of a template.

  EvolutionSessionStatsProvider call(String templateId) =>
      EvolutionSessionStatsProvider._(argument: templateId, from: this);

  @override
  String toString() => r'evolutionSessionStatsProvider';
}

/// Returns the completion timestamp of the newest completed ritual session
/// for a template, if any.

@ProviderFor(latestCompletedRitualTimestamp)
final latestCompletedRitualTimestampProvider =
    LatestCompletedRitualTimestampFamily._();

/// Returns the completion timestamp of the newest completed ritual session
/// for a template, if any.

final class LatestCompletedRitualTimestampProvider
    extends
        $FunctionalProvider<
          AsyncValue<DateTime?>,
          DateTime?,
          FutureOr<DateTime?>
        >
    with $FutureModifier<DateTime?>, $FutureProvider<DateTime?> {
  /// Returns the completion timestamp of the newest completed ritual session
  /// for a template, if any.
  LatestCompletedRitualTimestampProvider._({
    required LatestCompletedRitualTimestampFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'latestCompletedRitualTimestampProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$latestCompletedRitualTimestampHash();

  @override
  String toString() {
    return r'latestCompletedRitualTimestampProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<DateTime?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<DateTime?> create(Ref ref) {
    final argument = this.argument as String;
    return latestCompletedRitualTimestamp(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LatestCompletedRitualTimestampProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$latestCompletedRitualTimestampHash() =>
    r'e7a2b14bb69384d39eb59c085deccf9d33870f3b';

/// Returns the completion timestamp of the newest completed ritual session
/// for a template, if any.

final class LatestCompletedRitualTimestampFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<DateTime?>, String> {
  LatestCompletedRitualTimestampFamily._()
    : super(
        retry: null,
        name: r'latestCompletedRitualTimestampProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Returns the completion timestamp of the newest completed ritual session
  /// for a template, if any.

  LatestCompletedRitualTimestampProvider call(String templateId) =>
      LatestCompletedRitualTimestampProvider._(
        argument: templateId,
        from: this,
      );

  @override
  String toString() => r'latestCompletedRitualTimestampProvider';
}

/// History entries for past ritual sessions, backed by persisted recap data.

@ProviderFor(ritualSessionHistory)
final ritualSessionHistoryProvider = RitualSessionHistoryFamily._();

/// History entries for past ritual sessions, backed by persisted recap data.

final class RitualSessionHistoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RitualSessionHistoryEntry>>,
          List<RitualSessionHistoryEntry>,
          FutureOr<List<RitualSessionHistoryEntry>>
        >
    with
        $FutureModifier<List<RitualSessionHistoryEntry>>,
        $FutureProvider<List<RitualSessionHistoryEntry>> {
  /// History entries for past ritual sessions, backed by persisted recap data.
  RitualSessionHistoryProvider._({
    required RitualSessionHistoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'ritualSessionHistoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$ritualSessionHistoryHash();

  @override
  String toString() {
    return r'ritualSessionHistoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<RitualSessionHistoryEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RitualSessionHistoryEntry>> create(Ref ref) {
    final argument = this.argument as String;
    return ritualSessionHistory(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RitualSessionHistoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$ritualSessionHistoryHash() =>
    r'a0f7adba77f65234158556742af9f3be0ab0a19d';

/// History entries for past ritual sessions, backed by persisted recap data.

final class RitualSessionHistoryFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<RitualSessionHistoryEntry>>,
          String
        > {
  RitualSessionHistoryFamily._()
    : super(
        retry: null,
        name: r'ritualSessionHistoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// History entries for past ritual sessions, backed by persisted recap data.

  RitualSessionHistoryProvider call(String templateId) =>
      RitualSessionHistoryProvider._(argument: templateId, from: this);

  @override
  String toString() => r'ritualSessionHistoryProvider';
}

/// Compact summary metrics for ritual home and chat header surfaces.

@ProviderFor(ritualSummaryMetrics)
final ritualSummaryMetricsProvider = RitualSummaryMetricsFamily._();

/// Compact summary metrics for ritual home and chat header surfaces.

final class RitualSummaryMetricsProvider
    extends
        $FunctionalProvider<
          AsyncValue<RitualSummaryMetrics>,
          RitualSummaryMetrics,
          FutureOr<RitualSummaryMetrics>
        >
    with
        $FutureModifier<RitualSummaryMetrics>,
        $FutureProvider<RitualSummaryMetrics> {
  /// Compact summary metrics for ritual home and chat header surfaces.
  RitualSummaryMetricsProvider._({
    required RitualSummaryMetricsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'ritualSummaryMetricsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$ritualSummaryMetricsHash();

  @override
  String toString() {
    return r'ritualSummaryMetricsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<RitualSummaryMetrics> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<RitualSummaryMetrics> create(Ref ref) {
    final argument = this.argument as String;
    return ritualSummaryMetrics(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RitualSummaryMetricsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$ritualSummaryMetricsHash() =>
    r'2682d0439e4b7f9028b82d9e2cdba9f3d9adfa1d';

/// Compact summary metrics for ritual home and chat header surfaces.

final class RitualSummaryMetricsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<RitualSummaryMetrics>, String> {
  RitualSummaryMetricsFamily._()
    : super(
        retry: null,
        name: r'ritualSummaryMetricsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Compact summary metrics for ritual home and chat header surfaces.

  RitualSummaryMetricsProvider call(String templateId) =>
      RitualSummaryMetricsProvider._(argument: templateId, from: this);

  @override
  String toString() => r'ritualSummaryMetricsProvider';
}
