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
///
/// This extracts the business logic from the widget, making it testable
/// independently without widget build cycles or timing issues.

@ProviderFor(checkboxVisibility)
final checkboxVisibilityProvider = CheckboxVisibilityFamily._();

/// Provider that computes which automatic prompt checkboxes should be visible
/// in the audio recording modal based on:
/// - Category configuration (automatic prompts)
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
  ///
  /// This extracts the business logic from the widget, making it testable
  /// independently without widget build cycles or timing issues.
  CheckboxVisibilityProvider._(
      {required CheckboxVisibilityFamily super.from,
      required String? super.argument})
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
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<AutomaticPromptVisibility> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AutomaticPromptVisibility create(Ref ref) {
    final argument = this.argument as String?;
    return checkboxVisibility(
      ref,
      categoryId: argument,
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
    r'52dcd2580910c6937a0047f2c0b9bf24e4e1d0eb';

/// Provider that computes which automatic prompt checkboxes should be visible
/// in the audio recording modal based on:
/// - Category configuration (automatic prompts)
///
/// This extracts the business logic from the widget, making it testable
/// independently without widget build cycles or timing issues.

final class CheckboxVisibilityFamily extends $Family
    with $FunctionalFamilyOverride<AutomaticPromptVisibility, String?> {
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
  ///
  /// This extracts the business logic from the widget, making it testable
  /// independently without widget build cycles or timing issues.

  CheckboxVisibilityProvider call({
    required String? categoryId,
  }) =>
      CheckboxVisibilityProvider._(argument: categoryId, from: this);

  @override
  String toString() => r'checkboxVisibilityProvider';
}
