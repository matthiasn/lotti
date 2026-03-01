// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ritual_review_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Returns the most recent active [EvolutionSessionEntity] for a template,
/// or `null` if there is no active session pending review.

@ProviderFor(pendingRitualReview)
final pendingRitualReviewProvider = PendingRitualReviewFamily._();

/// Returns the most recent active [EvolutionSessionEntity] for a template,
/// or `null` if there is no active session pending review.

final class PendingRitualReviewProvider extends $FunctionalProvider<
        AsyncValue<AgentDomainEntity?>,
        AgentDomainEntity?,
        FutureOr<AgentDomainEntity?>>
    with
        $FutureModifier<AgentDomainEntity?>,
        $FutureProvider<AgentDomainEntity?> {
  /// Returns the most recent active [EvolutionSessionEntity] for a template,
  /// or `null` if there is no active session pending review.
  PendingRitualReviewProvider._(
      {required PendingRitualReviewFamily super.from,
      required String super.argument})
      : super(
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
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<AgentDomainEntity?> create(Ref ref) {
    final argument = this.argument as String;
    return pendingRitualReview(
      ref,
      argument,
    );
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
    r'11052e3bca9e543937ca5ebbc9925199d8a4e109';

/// Returns the most recent active [EvolutionSessionEntity] for a template,
/// or `null` if there is no active session pending review.

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

  PendingRitualReviewProvider call(
    String templateId,
  ) =>
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

final class RitualFeedbackProvider extends $FunctionalProvider<
        AsyncValue<ClassifiedFeedback?>,
        ClassifiedFeedback?,
        FutureOr<ClassifiedFeedback?>>
    with
        $FutureModifier<ClassifiedFeedback?>,
        $FutureProvider<ClassifiedFeedback?> {
  /// Extracts classified feedback for a template's review window.
  ///
  /// Uses the feedback extraction service to scan the default 7-day window.
  RitualFeedbackProvider._(
      {required RitualFeedbackFamily super.from,
      required String super.argument})
      : super(
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
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<ClassifiedFeedback?> create(Ref ref) {
    final argument = this.argument as String;
    return ritualFeedback(
      ref,
      argument,
    );
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

String _$ritualFeedbackHash() => r'369634fcae8f0187162159be9056f6817fa723f5';

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

  RitualFeedbackProvider call(
    String templateId,
  ) =>
      RitualFeedbackProvider._(argument: templateId, from: this);

  @override
  String toString() => r'ritualFeedbackProvider';
}

/// Count of templates with active evolution sessions (for badges).
///
/// Uses the single-query [allEvolutionSessionsProvider] to avoid N+1.

@ProviderFor(pendingRitualCount)
final pendingRitualCountProvider = PendingRitualCountProvider._();

/// Count of templates with active evolution sessions (for badges).
///
/// Uses the single-query [allEvolutionSessionsProvider] to avoid N+1.

final class PendingRitualCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// Count of templates with active evolution sessions (for badges).
  ///
  /// Uses the single-query [allEvolutionSessionsProvider] to avoid N+1.
  PendingRitualCountProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'pendingRitualCountProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$pendingRitualCountHash();

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    return pendingRitualCount(ref);
  }
}

String _$pendingRitualCountHash() =>
    r'4874b13c2cf17461a8d53499283f7b9c942b622d';

/// List of template IDs with pending rituals.

@ProviderFor(templatesPendingReview)
final templatesPendingReviewProvider = TemplatesPendingReviewProvider._();

/// List of template IDs with pending rituals.

final class TemplatesPendingReviewProvider extends $FunctionalProvider<
        AsyncValue<Set<String>>, Set<String>, FutureOr<Set<String>>>
    with $FutureModifier<Set<String>>, $FutureProvider<Set<String>> {
  /// List of template IDs with pending rituals.
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
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

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

final class EvolutionSessionStatsProvider extends $FunctionalProvider<
        AsyncValue<EvolutionSessionStats>,
        EvolutionSessionStats,
        FutureOr<EvolutionSessionStats>>
    with
        $FutureModifier<EvolutionSessionStats>,
        $FutureProvider<EvolutionSessionStats> {
  /// Aggregate stats for evolution sessions of a template.
  EvolutionSessionStatsProvider._(
      {required EvolutionSessionStatsFamily super.from,
      required String super.argument})
      : super(
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
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<EvolutionSessionStats> create(Ref ref) {
    final argument = this.argument as String;
    return evolutionSessionStats(
      ref,
      argument,
    );
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

  EvolutionSessionStatsProvider call(
    String templateId,
  ) =>
      EvolutionSessionStatsProvider._(argument: templateId, from: this);

  @override
  String toString() => r'evolutionSessionStatsProvider';
}
