// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ollama_task_checklist_summary.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$aiTaskChecklistSummaryControllerHash() =>
    r'97360e0a49694226499e0497d689e07990dce820';

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

abstract class _$AiTaskChecklistSummaryController
    extends BuildlessAutoDisposeNotifier<String> {
  late final String id;

  String build({
    required String id,
  });
}

/// See also [AiTaskChecklistSummaryController].
@ProviderFor(AiTaskChecklistSummaryController)
const aiTaskChecklistSummaryControllerProvider =
    AiTaskChecklistSummaryControllerFamily();

/// See also [AiTaskChecklistSummaryController].
class AiTaskChecklistSummaryControllerFamily extends Family<String> {
  /// See also [AiTaskChecklistSummaryController].
  const AiTaskChecklistSummaryControllerFamily();

  /// See also [AiTaskChecklistSummaryController].
  AiTaskChecklistSummaryControllerProvider call({
    required String id,
  }) {
    return AiTaskChecklistSummaryControllerProvider(
      id: id,
    );
  }

  @override
  AiTaskChecklistSummaryControllerProvider getProviderOverride(
    covariant AiTaskChecklistSummaryControllerProvider provider,
  ) {
    return call(
      id: provider.id,
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
  String? get name => r'aiTaskChecklistSummaryControllerProvider';
}

/// See also [AiTaskChecklistSummaryController].
class AiTaskChecklistSummaryControllerProvider
    extends AutoDisposeNotifierProviderImpl<AiTaskChecklistSummaryController,
        String> {
  /// See also [AiTaskChecklistSummaryController].
  AiTaskChecklistSummaryControllerProvider({
    required String id,
  }) : this._internal(
          () => AiTaskChecklistSummaryController()..id = id,
          from: aiTaskChecklistSummaryControllerProvider,
          name: r'aiTaskChecklistSummaryControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$aiTaskChecklistSummaryControllerHash,
          dependencies: AiTaskChecklistSummaryControllerFamily._dependencies,
          allTransitiveDependencies:
              AiTaskChecklistSummaryControllerFamily._allTransitiveDependencies,
          id: id,
        );

  AiTaskChecklistSummaryControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String id;

  @override
  String runNotifierBuild(
    covariant AiTaskChecklistSummaryController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(AiTaskChecklistSummaryController Function() create) {
    return ProviderOverride(
      origin: this,
      override: AiTaskChecklistSummaryControllerProvider._internal(
        () => create()..id = id,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<AiTaskChecklistSummaryController, String>
      createElement() {
    return _AiTaskChecklistSummaryControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AiTaskChecklistSummaryControllerProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin AiTaskChecklistSummaryControllerRef
    on AutoDisposeNotifierProviderRef<String> {
  /// The parameter `id` of this provider.
  String get id;
}

class _AiTaskChecklistSummaryControllerProviderElement
    extends AutoDisposeNotifierProviderElement<AiTaskChecklistSummaryController,
        String> with AiTaskChecklistSummaryControllerRef {
  _AiTaskChecklistSummaryControllerProviderElement(super.provider);

  @override
  String get id => (origin as AiTaskChecklistSummaryControllerProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
