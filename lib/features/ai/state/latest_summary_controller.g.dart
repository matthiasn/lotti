// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'latest_summary_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$latestSummaryControllerHash() =>
    r'a990e73435dddd699c4bb87454070674879e9892';

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

abstract class _$LatestSummaryController
    extends BuildlessAutoDisposeAsyncNotifier<AiResponseEntry?> {
  late final String id;
  late final String aiResponseType;

  FutureOr<AiResponseEntry?> build({
    required String id,
    required String aiResponseType,
  });
}

/// See also [LatestSummaryController].
@ProviderFor(LatestSummaryController)
const latestSummaryControllerProvider = LatestSummaryControllerFamily();

/// See also [LatestSummaryController].
class LatestSummaryControllerFamily
    extends Family<AsyncValue<AiResponseEntry?>> {
  /// See also [LatestSummaryController].
  const LatestSummaryControllerFamily();

  /// See also [LatestSummaryController].
  LatestSummaryControllerProvider call({
    required String id,
    required String aiResponseType,
  }) {
    return LatestSummaryControllerProvider(
      id: id,
      aiResponseType: aiResponseType,
    );
  }

  @override
  LatestSummaryControllerProvider getProviderOverride(
    covariant LatestSummaryControllerProvider provider,
  ) {
    return call(
      id: provider.id,
      aiResponseType: provider.aiResponseType,
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
  String? get name => r'latestSummaryControllerProvider';
}

/// See also [LatestSummaryController].
class LatestSummaryControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<LatestSummaryController,
        AiResponseEntry?> {
  /// See also [LatestSummaryController].
  LatestSummaryControllerProvider({
    required String id,
    required String aiResponseType,
  }) : this._internal(
          () => LatestSummaryController()
            ..id = id
            ..aiResponseType = aiResponseType,
          from: latestSummaryControllerProvider,
          name: r'latestSummaryControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$latestSummaryControllerHash,
          dependencies: LatestSummaryControllerFamily._dependencies,
          allTransitiveDependencies:
              LatestSummaryControllerFamily._allTransitiveDependencies,
          id: id,
          aiResponseType: aiResponseType,
        );

  LatestSummaryControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
    required this.aiResponseType,
  }) : super.internal();

  final String id;
  final String aiResponseType;

  @override
  FutureOr<AiResponseEntry?> runNotifierBuild(
    covariant LatestSummaryController notifier,
  ) {
    return notifier.build(
      id: id,
      aiResponseType: aiResponseType,
    );
  }

  @override
  Override overrideWith(LatestSummaryController Function() create) {
    return ProviderOverride(
      origin: this,
      override: LatestSummaryControllerProvider._internal(
        () => create()
          ..id = id
          ..aiResponseType = aiResponseType,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
        aiResponseType: aiResponseType,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<LatestSummaryController,
      AiResponseEntry?> createElement() {
    return _LatestSummaryControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LatestSummaryControllerProvider &&
        other.id == id &&
        other.aiResponseType == aiResponseType;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);
    hash = _SystemHash.combine(hash, aiResponseType.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin LatestSummaryControllerRef
    on AutoDisposeAsyncNotifierProviderRef<AiResponseEntry?> {
  /// The parameter `id` of this provider.
  String get id;

  /// The parameter `aiResponseType` of this provider.
  String get aiResponseType;
}

class _LatestSummaryControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<LatestSummaryController,
        AiResponseEntry?> with LatestSummaryControllerRef {
  _LatestSummaryControllerProviderElement(super.provider);

  @override
  String get id => (origin as LatestSummaryControllerProvider).id;
  @override
  String get aiResponseType =>
      (origin as LatestSummaryControllerProvider).aiResponseType;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
