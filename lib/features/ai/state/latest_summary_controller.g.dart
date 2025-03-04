// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'latest_summary_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$latestSummaryControllerHash() =>
    r'440655e1ee0fe7017852c5430612279566096680';

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

  FutureOr<AiResponseEntry?> build({
    required String id,
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
  }) {
    return LatestSummaryControllerProvider(
      id: id,
    );
  }

  @override
  LatestSummaryControllerProvider getProviderOverride(
    covariant LatestSummaryControllerProvider provider,
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
  String? get name => r'latestSummaryControllerProvider';
}

/// See also [LatestSummaryController].
class LatestSummaryControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<LatestSummaryController,
        AiResponseEntry?> {
  /// See also [LatestSummaryController].
  LatestSummaryControllerProvider({
    required String id,
  }) : this._internal(
          () => LatestSummaryController()..id = id,
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
        );

  LatestSummaryControllerProvider._internal(
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
  FutureOr<AiResponseEntry?> runNotifierBuild(
    covariant LatestSummaryController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(LatestSummaryController Function() create) {
    return ProviderOverride(
      origin: this,
      override: LatestSummaryControllerProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<LatestSummaryController,
      AiResponseEntry?> createElement() {
    return _LatestSummaryControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LatestSummaryControllerProvider && other.id == id;
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
mixin LatestSummaryControllerRef
    on AutoDisposeAsyncNotifierProviderRef<AiResponseEntry?> {
  /// The parameter `id` of this provider.
  String get id;
}

class _LatestSummaryControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<LatestSummaryController,
        AiResponseEntry?> with LatestSummaryControllerRef {
  _LatestSummaryControllerProviderElement(super.provider);

  @override
  String get id => (origin as LatestSummaryControllerProvider).id;
}

String _$checklistItemSuggestionsControllerHash() =>
    r'25040a3ed7b8f13edf2b044792f34464e98d3cdc';

abstract class _$ChecklistItemSuggestionsController
    extends BuildlessAsyncNotifier<List<ChecklistItemData>> {
  late final String id;

  FutureOr<List<ChecklistItemData>> build({
    required String id,
  });
}

/// See also [ChecklistItemSuggestionsController].
@ProviderFor(ChecklistItemSuggestionsController)
const checklistItemSuggestionsControllerProvider =
    ChecklistItemSuggestionsControllerFamily();

/// See also [ChecklistItemSuggestionsController].
class ChecklistItemSuggestionsControllerFamily
    extends Family<AsyncValue<List<ChecklistItemData>>> {
  /// See also [ChecklistItemSuggestionsController].
  const ChecklistItemSuggestionsControllerFamily();

  /// See also [ChecklistItemSuggestionsController].
  ChecklistItemSuggestionsControllerProvider call({
    required String id,
  }) {
    return ChecklistItemSuggestionsControllerProvider(
      id: id,
    );
  }

  @override
  ChecklistItemSuggestionsControllerProvider getProviderOverride(
    covariant ChecklistItemSuggestionsControllerProvider provider,
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
  String? get name => r'checklistItemSuggestionsControllerProvider';
}

/// See also [ChecklistItemSuggestionsController].
class ChecklistItemSuggestionsControllerProvider
    extends AsyncNotifierProviderImpl<ChecklistItemSuggestionsController,
        List<ChecklistItemData>> {
  /// See also [ChecklistItemSuggestionsController].
  ChecklistItemSuggestionsControllerProvider({
    required String id,
  }) : this._internal(
          () => ChecklistItemSuggestionsController()..id = id,
          from: checklistItemSuggestionsControllerProvider,
          name: r'checklistItemSuggestionsControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$checklistItemSuggestionsControllerHash,
          dependencies: ChecklistItemSuggestionsControllerFamily._dependencies,
          allTransitiveDependencies: ChecklistItemSuggestionsControllerFamily
              ._allTransitiveDependencies,
          id: id,
        );

  ChecklistItemSuggestionsControllerProvider._internal(
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
  FutureOr<List<ChecklistItemData>> runNotifierBuild(
    covariant ChecklistItemSuggestionsController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(ChecklistItemSuggestionsController Function() create) {
    return ProviderOverride(
      origin: this,
      override: ChecklistItemSuggestionsControllerProvider._internal(
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
  AsyncNotifierProviderElement<ChecklistItemSuggestionsController,
      List<ChecklistItemData>> createElement() {
    return _ChecklistItemSuggestionsControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChecklistItemSuggestionsControllerProvider &&
        other.id == id;
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
mixin ChecklistItemSuggestionsControllerRef
    on AsyncNotifierProviderRef<List<ChecklistItemData>> {
  /// The parameter `id` of this provider.
  String get id;
}

class _ChecklistItemSuggestionsControllerProviderElement
    extends AsyncNotifierProviderElement<ChecklistItemSuggestionsController,
        List<ChecklistItemData>> with ChecklistItemSuggestionsControllerRef {
  _ChecklistItemSuggestionsControllerProviderElement(super.provider);

  @override
  String get id => (origin as ChecklistItemSuggestionsControllerProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
