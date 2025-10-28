// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checkbox_visibility_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$checkboxVisibilityHash() =>
    r'aa5b6d2d21b12cd086f7a79723d96a1b81c19cd0';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Provider that computes which automatic prompt checkboxes should be visible
/// in the audio recording modal based on:
/// - Category configuration (automatic prompts)
/// - Whether a Task is linked (not just any entity)
/// - User's speech recognition preference
///
/// This extracts the business logic from the widget, making it testable
/// independently without widget build cycles or timing issues.
///
/// Copied from [checkboxVisibility].
@ProviderFor(checkboxVisibility)
const checkboxVisibilityProvider = CheckboxVisibilityFamily();

/// Provider that computes which automatic prompt checkboxes should be visible
/// in the audio recording modal based on:
/// - Category configuration (automatic prompts)
/// - Whether a Task is linked (not just any entity)
/// - User's speech recognition preference
///
/// This extracts the business logic from the widget, making it testable
/// independently without widget build cycles or timing issues.
///
/// Copied from [checkboxVisibility].
class CheckboxVisibilityFamily extends Family<AutomaticPromptVisibility> {
  /// Provider that computes which automatic prompt checkboxes should be visible
  /// in the audio recording modal based on:
  /// - Category configuration (automatic prompts)
  /// - Whether a Task is linked (not just any entity)
  /// - User's speech recognition preference
  ///
  /// This extracts the business logic from the widget, making it testable
  /// independently without widget build cycles or timing issues.
  ///
  /// Copied from [checkboxVisibility].
  const CheckboxVisibilityFamily();

  /// Provider that computes which automatic prompt checkboxes should be visible
  /// in the audio recording modal based on:
  /// - Category configuration (automatic prompts)
  /// - Whether a Task is linked (not just any entity)
  /// - User's speech recognition preference
  ///
  /// This extracts the business logic from the widget, making it testable
  /// independently without widget build cycles or timing issues.
  ///
  /// Copied from [checkboxVisibility].
  CheckboxVisibilityProvider call({
    required String? categoryId,
    required String? linkedId,
    required bool? userSpeechPreference,
  }) {
    return CheckboxVisibilityProvider(
      categoryId: categoryId,
      linkedId: linkedId,
      userSpeechPreference: userSpeechPreference,
    );
  }

  @override
  CheckboxVisibilityProvider getProviderOverride(
    covariant CheckboxVisibilityProvider provider,
  ) {
    return call(
      categoryId: provider.categoryId,
      linkedId: provider.linkedId,
      userSpeechPreference: provider.userSpeechPreference,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'checkboxVisibilityProvider';
}

/// Provider that computes which automatic prompt checkboxes should be visible
/// in the audio recording modal based on:
/// - Category configuration (automatic prompts)
/// - Whether a Task is linked (not just any entity)
/// - User's speech recognition preference
///
/// This extracts the business logic from the widget, making it testable
/// independently without widget build cycles or timing issues.
///
/// Copied from [checkboxVisibility].
class CheckboxVisibilityProvider
    extends AutoDisposeProvider<AutomaticPromptVisibility> {
  /// Provider that computes which automatic prompt checkboxes should be visible
  /// in the audio recording modal based on:
  /// - Category configuration (automatic prompts)
  /// - Whether a Task is linked (not just any entity)
  /// - User's speech recognition preference
  ///
  /// This extracts the business logic from the widget, making it testable
  /// independently without widget build cycles or timing issues.
  ///
  /// Copied from [checkboxVisibility].
  CheckboxVisibilityProvider({
    required String? categoryId,
    required String? linkedId,
    required bool? userSpeechPreference,
  }) : this._internal(
          (ref) => checkboxVisibility(
            ref as CheckboxVisibilityRef,
            categoryId: categoryId,
            linkedId: linkedId,
            userSpeechPreference: userSpeechPreference,
          ),
          from: checkboxVisibilityProvider,
          name: r'checkboxVisibilityProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$checkboxVisibilityHash,
          dependencies: CheckboxVisibilityFamily._dependencies,
          allTransitiveDependencies:
              CheckboxVisibilityFamily._allTransitiveDependencies,
          categoryId: categoryId,
          linkedId: linkedId,
          userSpeechPreference: userSpeechPreference,
        );

  CheckboxVisibilityProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.categoryId,
    required this.linkedId,
    required this.userSpeechPreference,
  }) : super.internal();

  final String? categoryId;
  final String? linkedId;
  final bool? userSpeechPreference;

  @override
  Override overrideWith(
    AutomaticPromptVisibility Function(CheckboxVisibilityRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CheckboxVisibilityProvider._internal(
        (ref) => create(ref as CheckboxVisibilityRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        categoryId: categoryId,
        linkedId: linkedId,
        userSpeechPreference: userSpeechPreference,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<AutomaticPromptVisibility> createElement() {
    return _CheckboxVisibilityProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CheckboxVisibilityProvider &&
        other.categoryId == categoryId &&
        other.linkedId == linkedId &&
        other.userSpeechPreference == userSpeechPreference;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, categoryId.hashCode);
    hash = _SystemHash.combine(hash, linkedId.hashCode);
    hash = _SystemHash.combine(hash, userSpeechPreference.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CheckboxVisibilityRef
    on AutoDisposeProviderRef<AutomaticPromptVisibility> {
  /// The parameter `categoryId` of this provider.
  String? get categoryId;

  /// The parameter `linkedId` of this provider.
  String? get linkedId;

  /// The parameter `userSpeechPreference` of this provider.
  bool? get userSpeechPreference;
}

class _CheckboxVisibilityProviderElement
    extends AutoDisposeProviderElement<AutomaticPromptVisibility>
    with CheckboxVisibilityRef {
  _CheckboxVisibilityProviderElement(super.provider);

  @override
  String? get categoryId => (origin as CheckboxVisibilityProvider).categoryId;
  @override
  String? get linkedId => (origin as CheckboxVisibilityProvider).linkedId;
  @override
  bool? get userSpeechPreference =>
      (origin as CheckboxVisibilityProvider).userSpeechPreference;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
