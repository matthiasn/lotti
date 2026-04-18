// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unified_suggestion_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Builds a [UnifiedSuggestionList] for a task.
///
/// Resolves the task agent, watches its update stream for reactive
/// invalidation, and queries both the pending change sets (so the UI can
/// dispatch confirm/reject through the existing
/// `ChangeSetConfirmationService` contract) and the proposal ledger (so
/// the activity strip can show recently-resolved / retracted items).

@ProviderFor(unifiedSuggestionList)
final unifiedSuggestionListProvider = UnifiedSuggestionListFamily._();

/// Builds a [UnifiedSuggestionList] for a task.
///
/// Resolves the task agent, watches its update stream for reactive
/// invalidation, and queries both the pending change sets (so the UI can
/// dispatch confirm/reject through the existing
/// `ChangeSetConfirmationService` contract) and the proposal ledger (so
/// the activity strip can show recently-resolved / retracted items).

final class UnifiedSuggestionListProvider
    extends
        $FunctionalProvider<
          AsyncValue<UnifiedSuggestionList>,
          UnifiedSuggestionList,
          FutureOr<UnifiedSuggestionList>
        >
    with
        $FutureModifier<UnifiedSuggestionList>,
        $FutureProvider<UnifiedSuggestionList> {
  /// Builds a [UnifiedSuggestionList] for a task.
  ///
  /// Resolves the task agent, watches its update stream for reactive
  /// invalidation, and queries both the pending change sets (so the UI can
  /// dispatch confirm/reject through the existing
  /// `ChangeSetConfirmationService` contract) and the proposal ledger (so
  /// the activity strip can show recently-resolved / retracted items).
  UnifiedSuggestionListProvider._({
    required UnifiedSuggestionListFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'unifiedSuggestionListProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$unifiedSuggestionListHash();

  @override
  String toString() {
    return r'unifiedSuggestionListProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<UnifiedSuggestionList> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<UnifiedSuggestionList> create(Ref ref) {
    final argument = this.argument as String;
    return unifiedSuggestionList(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is UnifiedSuggestionListProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$unifiedSuggestionListHash() =>
    r'7739a74b6a26b9f85557a4b630e9d82cfc7c87a8';

/// Builds a [UnifiedSuggestionList] for a task.
///
/// Resolves the task agent, watches its update stream for reactive
/// invalidation, and queries both the pending change sets (so the UI can
/// dispatch confirm/reject through the existing
/// `ChangeSetConfirmationService` contract) and the proposal ledger (so
/// the activity strip can show recently-resolved / retracted items).

final class UnifiedSuggestionListFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<UnifiedSuggestionList>, String> {
  UnifiedSuggestionListFamily._()
    : super(
        retry: null,
        name: r'unifiedSuggestionListProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Builds a [UnifiedSuggestionList] for a task.
  ///
  /// Resolves the task agent, watches its update stream for reactive
  /// invalidation, and queries both the pending change sets (so the UI can
  /// dispatch confirm/reject through the existing
  /// `ChangeSetConfirmationService` contract) and the proposal ledger (so
  /// the activity strip can show recently-resolved / retracted items).

  UnifiedSuggestionListProvider call(String taskId) =>
      UnifiedSuggestionListProvider._(argument: taskId, from: this);

  @override
  String toString() => r'unifiedSuggestionListProvider';
}
