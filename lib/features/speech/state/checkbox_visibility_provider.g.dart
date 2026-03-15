// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checkbox_visibility_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Checks whether a task has profile-driven transcription available.
///
/// Re-evaluates when profiles change (via [inferenceProfileControllerProvider])
/// so that edits to automation toggles are immediately reflected in the UI.
/// Uses the pure capability check rather than the execution path to avoid
/// side effects during render-time reads.

@ProviderFor(hasProfileTranscription)
final hasProfileTranscriptionProvider = HasProfileTranscriptionFamily._();

/// Checks whether a task has profile-driven transcription available.
///
/// Re-evaluates when profiles change (via [inferenceProfileControllerProvider])
/// so that edits to automation toggles are immediately reflected in the UI.
/// Uses the pure capability check rather than the execution path to avoid
/// side effects during render-time reads.

final class HasProfileTranscriptionProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Checks whether a task has profile-driven transcription available.
  ///
  /// Re-evaluates when profiles change (via [inferenceProfileControllerProvider])
  /// so that edits to automation toggles are immediately reflected in the UI.
  /// Uses the pure capability check rather than the execution path to avoid
  /// side effects during render-time reads.
  HasProfileTranscriptionProvider._({
    required HasProfileTranscriptionFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'hasProfileTranscriptionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$hasProfileTranscriptionHash();

  @override
  String toString() {
    return r'hasProfileTranscriptionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as String;
    return hasProfileTranscription(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is HasProfileTranscriptionProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$hasProfileTranscriptionHash() =>
    r'51cd808d14f8bf5859ea70069e65b2743ae12432';

/// Checks whether a task has profile-driven transcription available.
///
/// Re-evaluates when profiles change (via [inferenceProfileControllerProvider])
/// so that edits to automation toggles are immediately reflected in the UI.
/// Uses the pure capability check rather than the execution path to avoid
/// side effects during render-time reads.

final class HasProfileTranscriptionFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, String> {
  HasProfileTranscriptionFamily._()
    : super(
        retry: null,
        name: r'hasProfileTranscriptionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Checks whether a task has profile-driven transcription available.
  ///
  /// Re-evaluates when profiles change (via [inferenceProfileControllerProvider])
  /// so that edits to automation toggles are immediately reflected in the UI.
  /// Uses the pure capability check rather than the execution path to avoid
  /// side effects during render-time reads.

  HasProfileTranscriptionProvider call(String taskId) =>
      HasProfileTranscriptionProvider._(argument: taskId, from: this);

  @override
  String toString() => r'hasProfileTranscriptionProvider';
}

/// Provider that computes which automatic prompt checkboxes should be visible
/// in the audio recording modal based on:
/// - Category configuration (automatic prompts)
/// - Profile-driven transcription availability (when linked to a task)
///
/// This extracts the business logic from the widget, making it testable
/// independently without widget build cycles or timing issues.

@ProviderFor(checkboxVisibility)
final checkboxVisibilityProvider = CheckboxVisibilityFamily._();

/// Provider that computes which automatic prompt checkboxes should be visible
/// in the audio recording modal based on:
/// - Category configuration (automatic prompts)
/// - Profile-driven transcription availability (when linked to a task)
///
/// This extracts the business logic from the widget, making it testable
/// independently without widget build cycles or timing issues.

final class CheckboxVisibilityProvider
    extends
        $FunctionalProvider<
          AutomaticPromptVisibility,
          AutomaticPromptVisibility,
          AutomaticPromptVisibility
        >
    with $Provider<AutomaticPromptVisibility> {
  /// Provider that computes which automatic prompt checkboxes should be visible
  /// in the audio recording modal based on:
  /// - Category configuration (automatic prompts)
  /// - Profile-driven transcription availability (when linked to a task)
  ///
  /// This extracts the business logic from the widget, making it testable
  /// independently without widget build cycles or timing issues.
  CheckboxVisibilityProvider._({
    required CheckboxVisibilityFamily super.from,
    required ({String? categoryId, String? linkedId}) super.argument,
  }) : super(
         retry: null,
         name: r'checkboxVisibilityProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$checkboxVisibilityHash();

  @override
  String toString() {
    return r'checkboxVisibilityProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $ProviderElement<AutomaticPromptVisibility> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AutomaticPromptVisibility create(Ref ref) {
    final argument = this.argument as ({String? categoryId, String? linkedId});
    return checkboxVisibility(
      ref,
      categoryId: argument.categoryId,
      linkedId: argument.linkedId,
    );
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AutomaticPromptVisibility value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AutomaticPromptVisibility>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CheckboxVisibilityProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$checkboxVisibilityHash() =>
    r'8917cdbe1b23809bb099c19a9230008ced858ca2';

/// Provider that computes which automatic prompt checkboxes should be visible
/// in the audio recording modal based on:
/// - Category configuration (automatic prompts)
/// - Profile-driven transcription availability (when linked to a task)
///
/// This extracts the business logic from the widget, making it testable
/// independently without widget build cycles or timing issues.

final class CheckboxVisibilityFamily extends $Family
    with
        $FunctionalFamilyOverride<
          AutomaticPromptVisibility,
          ({String? categoryId, String? linkedId})
        > {
  CheckboxVisibilityFamily._()
    : super(
        retry: null,
        name: r'checkboxVisibilityProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider that computes which automatic prompt checkboxes should be visible
  /// in the audio recording modal based on:
  /// - Category configuration (automatic prompts)
  /// - Profile-driven transcription availability (when linked to a task)
  ///
  /// This extracts the business logic from the widget, making it testable
  /// independently without widget build cycles or timing issues.

  CheckboxVisibilityProvider call({
    required String? categoryId,
    String? linkedId,
  }) => CheckboxVisibilityProvider._(
    argument: (categoryId: categoryId, linkedId: linkedId),
    from: this,
  );

  @override
  String toString() => r'checkboxVisibilityProvider';
}
