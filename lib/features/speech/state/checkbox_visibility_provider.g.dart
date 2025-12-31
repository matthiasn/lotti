// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checkbox_visibility_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider that computes which automatic prompt checkboxes should be visible
/// in the audio recording modal based on:
/// - Category configuration (automatic prompts)
/// - Whether a Task is linked (not just any entity)
/// - User's speech recognition preference
///
/// This extracts the business logic from the widget, making it testable
/// independently without widget build cycles or timing issues.

@ProviderFor(checkboxVisibility)
final checkboxVisibilityProvider = CheckboxVisibilityFamily._();

/// Provider that computes which automatic prompt checkboxes should be visible
/// in the audio recording modal based on:
/// - Category configuration (automatic prompts)
/// - Whether a Task is linked (not just any entity)
/// - User's speech recognition preference
///
/// This extracts the business logic from the widget, making it testable
/// independently without widget build cycles or timing issues.

final class CheckboxVisibilityProvider extends $FunctionalProvider<
    AutomaticPromptVisibility,
    AutomaticPromptVisibility,
    AutomaticPromptVisibility> with $Provider<AutomaticPromptVisibility> {
  /// Provider that computes which automatic prompt checkboxes should be visible
  /// in the audio recording modal based on:
  /// - Category configuration (automatic prompts)
  /// - Whether a Task is linked (not just any entity)
  /// - User's speech recognition preference
  ///
  /// This extracts the business logic from the widget, making it testable
  /// independently without widget build cycles or timing issues.
  CheckboxVisibilityProvider._(
      {required CheckboxVisibilityFamily super.from,
      required ({
        String? categoryId,
        String? linkedId,
        bool? userSpeechPreference,
      })
          super.argument})
      : super(
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
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AutomaticPromptVisibility create(Ref ref) {
    final argument = this.argument as ({
      String? categoryId,
      String? linkedId,
      bool? userSpeechPreference,
    });
    return checkboxVisibility(
      ref,
      categoryId: argument.categoryId,
      linkedId: argument.linkedId,
      userSpeechPreference: argument.userSpeechPreference,
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
    r'9ff4db5a2e21b5517746b48e71687a621af0beb3';

/// Provider that computes which automatic prompt checkboxes should be visible
/// in the audio recording modal based on:
/// - Category configuration (automatic prompts)
/// - Whether a Task is linked (not just any entity)
/// - User's speech recognition preference
///
/// This extracts the business logic from the widget, making it testable
/// independently without widget build cycles or timing issues.

final class CheckboxVisibilityFamily extends $Family
    with
        $FunctionalFamilyOverride<
            AutomaticPromptVisibility,
            ({
              String? categoryId,
              String? linkedId,
              bool? userSpeechPreference,
            })> {
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
  /// - Whether a Task is linked (not just any entity)
  /// - User's speech recognition preference
  ///
  /// This extracts the business logic from the widget, making it testable
  /// independently without widget build cycles or timing issues.

  CheckboxVisibilityProvider call({
    required String? categoryId,
    required String? linkedId,
    required bool? userSpeechPreference,
  }) =>
      CheckboxVisibilityProvider._(argument: (
        categoryId: categoryId,
        linkedId: linkedId,
        userSpeechPreference: userSpeechPreference,
      ), from: this);

  @override
  String toString() => r'checkboxVisibilityProvider';
}
