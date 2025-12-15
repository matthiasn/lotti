// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'linked_ai_responses_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$linkedAiResponsesControllerHash() =>
    r'4bc977940f5749fe98de0df87faecceb55651e16';

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

abstract class _$LinkedAiResponsesController
    extends BuildlessAutoDisposeAsyncNotifier<List<AiResponseEntry>> {
  late final String entryId;

  FutureOr<List<AiResponseEntry>> build({
    required String entryId,
  });
}

/// Controller for fetching AI responses linked to a specific entry (e.g., audio).
///
/// This is used to display nested AI responses under audio entries in the task view,
/// showing generated prompts and other AI responses directly where they are relevant.
///
/// Copied from [LinkedAiResponsesController].
@ProviderFor(LinkedAiResponsesController)
const linkedAiResponsesControllerProvider = LinkedAiResponsesControllerFamily();

/// Controller for fetching AI responses linked to a specific entry (e.g., audio).
///
/// This is used to display nested AI responses under audio entries in the task view,
/// showing generated prompts and other AI responses directly where they are relevant.
///
/// Copied from [LinkedAiResponsesController].
class LinkedAiResponsesControllerFamily
    extends Family<AsyncValue<List<AiResponseEntry>>> {
  /// Controller for fetching AI responses linked to a specific entry (e.g., audio).
  ///
  /// This is used to display nested AI responses under audio entries in the task view,
  /// showing generated prompts and other AI responses directly where they are relevant.
  ///
  /// Copied from [LinkedAiResponsesController].
  const LinkedAiResponsesControllerFamily();

  /// Controller for fetching AI responses linked to a specific entry (e.g., audio).
  ///
  /// This is used to display nested AI responses under audio entries in the task view,
  /// showing generated prompts and other AI responses directly where they are relevant.
  ///
  /// Copied from [LinkedAiResponsesController].
  LinkedAiResponsesControllerProvider call({
    required String entryId,
  }) {
    return LinkedAiResponsesControllerProvider(
      entryId: entryId,
    );
  }

  @override
  LinkedAiResponsesControllerProvider getProviderOverride(
    covariant LinkedAiResponsesControllerProvider provider,
  ) {
    return call(
      entryId: provider.entryId,
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
  String? get name => r'linkedAiResponsesControllerProvider';
}

/// Controller for fetching AI responses linked to a specific entry (e.g., audio).
///
/// This is used to display nested AI responses under audio entries in the task view,
/// showing generated prompts and other AI responses directly where they are relevant.
///
/// Copied from [LinkedAiResponsesController].
class LinkedAiResponsesControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<LinkedAiResponsesController,
        List<AiResponseEntry>> {
  /// Controller for fetching AI responses linked to a specific entry (e.g., audio).
  ///
  /// This is used to display nested AI responses under audio entries in the task view,
  /// showing generated prompts and other AI responses directly where they are relevant.
  ///
  /// Copied from [LinkedAiResponsesController].
  LinkedAiResponsesControllerProvider({
    required String entryId,
  }) : this._internal(
          () => LinkedAiResponsesController()..entryId = entryId,
          from: linkedAiResponsesControllerProvider,
          name: r'linkedAiResponsesControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$linkedAiResponsesControllerHash,
          dependencies: LinkedAiResponsesControllerFamily._dependencies,
          allTransitiveDependencies:
              LinkedAiResponsesControllerFamily._allTransitiveDependencies,
          entryId: entryId,
        );

  LinkedAiResponsesControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.entryId,
  }) : super.internal();

  final String entryId;

  @override
  FutureOr<List<AiResponseEntry>> runNotifierBuild(
    covariant LinkedAiResponsesController notifier,
  ) {
    return notifier.build(
      entryId: entryId,
    );
  }

  @override
  Override overrideWith(LinkedAiResponsesController Function() create) {
    return ProviderOverride(
      origin: this,
      override: LinkedAiResponsesControllerProvider._internal(
        () => create()..entryId = entryId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        entryId: entryId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<LinkedAiResponsesController,
      List<AiResponseEntry>> createElement() {
    return _LinkedAiResponsesControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LinkedAiResponsesControllerProvider &&
        other.entryId == entryId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, entryId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin LinkedAiResponsesControllerRef
    on AutoDisposeAsyncNotifierProviderRef<List<AiResponseEntry>> {
  /// The parameter `entryId` of this provider.
  String get entryId;
}

class _LinkedAiResponsesControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<LinkedAiResponsesController,
        List<AiResponseEntry>> with LinkedAiResponsesControllerRef {
  _LinkedAiResponsesControllerProviderElement(super.provider);

  @override
  String get entryId => (origin as LinkedAiResponsesControllerProvider).entryId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
