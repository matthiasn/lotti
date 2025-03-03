// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ollama_task_summary.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$aiTaskSummaryControllerHash() =>
    r'6253b67eb63b845c8c3bfb022acc4ba30331cc62';

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

abstract class _$AiTaskSummaryController
    extends BuildlessAutoDisposeNotifier<String> {
  late final String id;

  String build({
    required String id,
  });
}

/// See also [AiTaskSummaryController].
@ProviderFor(AiTaskSummaryController)
const aiTaskSummaryControllerProvider = AiTaskSummaryControllerFamily();

/// See also [AiTaskSummaryController].
class AiTaskSummaryControllerFamily extends Family<String> {
  /// See also [AiTaskSummaryController].
  const AiTaskSummaryControllerFamily();

  /// See also [AiTaskSummaryController].
  AiTaskSummaryControllerProvider call({
    required String id,
  }) {
    return AiTaskSummaryControllerProvider(
      id: id,
    );
  }

  @override
  AiTaskSummaryControllerProvider getProviderOverride(
    covariant AiTaskSummaryControllerProvider provider,
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
  String? get name => r'aiTaskSummaryControllerProvider';
}

/// See also [AiTaskSummaryController].
class AiTaskSummaryControllerProvider
    extends AutoDisposeNotifierProviderImpl<AiTaskSummaryController, String> {
  /// See also [AiTaskSummaryController].
  AiTaskSummaryControllerProvider({
    required String id,
  }) : this._internal(
          () => AiTaskSummaryController()..id = id,
          from: aiTaskSummaryControllerProvider,
          name: r'aiTaskSummaryControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$aiTaskSummaryControllerHash,
          dependencies: AiTaskSummaryControllerFamily._dependencies,
          allTransitiveDependencies:
              AiTaskSummaryControllerFamily._allTransitiveDependencies,
          id: id,
        );

  AiTaskSummaryControllerProvider._internal(
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
    covariant AiTaskSummaryController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(AiTaskSummaryController Function() create) {
    return ProviderOverride(
      origin: this,
      override: AiTaskSummaryControllerProvider._internal(
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
  AutoDisposeNotifierProviderElement<AiTaskSummaryController, String>
      createElement() {
    return _AiTaskSummaryControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AiTaskSummaryControllerProvider && other.id == id;
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
mixin AiTaskSummaryControllerRef on AutoDisposeNotifierProviderRef<String> {
  /// The parameter `id` of this provider.
  String get id;
}

class _AiTaskSummaryControllerProviderElement
    extends AutoDisposeNotifierProviderElement<AiTaskSummaryController, String>
    with AiTaskSummaryControllerRef {
  _AiTaskSummaryControllerProviderElement(super.provider);

  @override
  String get id => (origin as AiTaskSummaryControllerProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
