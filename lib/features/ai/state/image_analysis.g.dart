// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_analysis.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$aiImageAnalysisControllerHash() =>
    r'ad20c9695be14476256d96a4b92b4dba6ddf0bdf';

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

abstract class _$AiImageAnalysisController
    extends BuildlessAutoDisposeNotifier<String> {
  late final String id;

  String build({
    required String id,
  });
}

/// See also [AiImageAnalysisController].
@ProviderFor(AiImageAnalysisController)
const aiImageAnalysisControllerProvider = AiImageAnalysisControllerFamily();

/// See also [AiImageAnalysisController].
class AiImageAnalysisControllerFamily extends Family<String> {
  /// See also [AiImageAnalysisController].
  const AiImageAnalysisControllerFamily();

  /// See also [AiImageAnalysisController].
  AiImageAnalysisControllerProvider call({
    required String id,
  }) {
    return AiImageAnalysisControllerProvider(
      id: id,
    );
  }

  @override
  AiImageAnalysisControllerProvider getProviderOverride(
    covariant AiImageAnalysisControllerProvider provider,
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
  String? get name => r'aiImageAnalysisControllerProvider';
}

/// See also [AiImageAnalysisController].
class AiImageAnalysisControllerProvider
    extends AutoDisposeNotifierProviderImpl<AiImageAnalysisController, String> {
  /// See also [AiImageAnalysisController].
  AiImageAnalysisControllerProvider({
    required String id,
  }) : this._internal(
          () => AiImageAnalysisController()..id = id,
          from: aiImageAnalysisControllerProvider,
          name: r'aiImageAnalysisControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$aiImageAnalysisControllerHash,
          dependencies: AiImageAnalysisControllerFamily._dependencies,
          allTransitiveDependencies:
              AiImageAnalysisControllerFamily._allTransitiveDependencies,
          id: id,
        );

  AiImageAnalysisControllerProvider._internal(
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
    covariant AiImageAnalysisController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(AiImageAnalysisController Function() create) {
    return ProviderOverride(
      origin: this,
      override: AiImageAnalysisControllerProvider._internal(
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
  AutoDisposeNotifierProviderElement<AiImageAnalysisController, String>
      createElement() {
    return _AiImageAnalysisControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AiImageAnalysisControllerProvider && other.id == id;
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
mixin AiImageAnalysisControllerRef on AutoDisposeNotifierProviderRef<String> {
  /// The parameter `id` of this provider.
  String get id;
}

class _AiImageAnalysisControllerProviderElement
    extends AutoDisposeNotifierProviderElement<AiImageAnalysisController,
        String> with AiImageAnalysisControllerRef {
  _AiImageAnalysisControllerProviderElement(super.provider);

  @override
  String get id => (origin as AiImageAnalysisControllerProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
