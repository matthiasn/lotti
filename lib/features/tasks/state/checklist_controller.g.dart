// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checklist_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$checklistControllerHash() =>
    r'e5606c6c07ca14baedfe713701fc0ae770359031';

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

abstract class _$ChecklistController
    extends BuildlessAutoDisposeAsyncNotifier<Checklist?> {
  late final String id;

  FutureOr<Checklist?> build({
    required String id,
  });
}

/// See also [ChecklistController].
@ProviderFor(ChecklistController)
const checklistControllerProvider = ChecklistControllerFamily();

/// See also [ChecklistController].
class ChecklistControllerFamily extends Family<AsyncValue<Checklist?>> {
  /// See also [ChecklistController].
  const ChecklistControllerFamily();

  /// See also [ChecklistController].
  ChecklistControllerProvider call({
    required String id,
  }) {
    return ChecklistControllerProvider(
      id: id,
    );
  }

  @override
  ChecklistControllerProvider getProviderOverride(
    covariant ChecklistControllerProvider provider,
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
  String? get name => r'checklistControllerProvider';
}

/// See also [ChecklistController].
class ChecklistControllerProvider extends AutoDisposeAsyncNotifierProviderImpl<
    ChecklistController, Checklist?> {
  /// See also [ChecklistController].
  ChecklistControllerProvider({
    required String id,
  }) : this._internal(
          () => ChecklistController()..id = id,
          from: checklistControllerProvider,
          name: r'checklistControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$checklistControllerHash,
          dependencies: ChecklistControllerFamily._dependencies,
          allTransitiveDependencies:
              ChecklistControllerFamily._allTransitiveDependencies,
          id: id,
        );

  ChecklistControllerProvider._internal(
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
  FutureOr<Checklist?> runNotifierBuild(
    covariant ChecklistController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(ChecklistController Function() create) {
    return ProviderOverride(
      origin: this,
      override: ChecklistControllerProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<ChecklistController, Checklist?>
      createElement() {
    return _ChecklistControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChecklistControllerProvider && other.id == id;
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
mixin ChecklistControllerRef
    on AutoDisposeAsyncNotifierProviderRef<Checklist?> {
  /// The parameter `id` of this provider.
  String get id;
}

class _ChecklistControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<ChecklistController,
        Checklist?> with ChecklistControllerRef {
  _ChecklistControllerProviderElement(super.provider);

  @override
  String get id => (origin as ChecklistControllerProvider).id;
}

String _$checklistCompletionControllerHash() =>
    r'd796843fda52a555c99a80012d0c5cab4a839329';

abstract class _$ChecklistCompletionController
    extends BuildlessAutoDisposeAsyncNotifier<
        ({int completedCount, int totalCount})> {
  late final String id;

  FutureOr<({int completedCount, int totalCount})> build({
    required String id,
  });
}

/// See also [ChecklistCompletionController].
@ProviderFor(ChecklistCompletionController)
const checklistCompletionControllerProvider =
    ChecklistCompletionControllerFamily();

/// See also [ChecklistCompletionController].
class ChecklistCompletionControllerFamily
    extends Family<AsyncValue<({int completedCount, int totalCount})>> {
  /// See also [ChecklistCompletionController].
  const ChecklistCompletionControllerFamily();

  /// See also [ChecklistCompletionController].
  ChecklistCompletionControllerProvider call({
    required String id,
  }) {
    return ChecklistCompletionControllerProvider(
      id: id,
    );
  }

  @override
  ChecklistCompletionControllerProvider getProviderOverride(
    covariant ChecklistCompletionControllerProvider provider,
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
  String? get name => r'checklistCompletionControllerProvider';
}

/// See also [ChecklistCompletionController].
class ChecklistCompletionControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<ChecklistCompletionController,
        ({int completedCount, int totalCount})> {
  /// See also [ChecklistCompletionController].
  ChecklistCompletionControllerProvider({
    required String id,
  }) : this._internal(
          () => ChecklistCompletionController()..id = id,
          from: checklistCompletionControllerProvider,
          name: r'checklistCompletionControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$checklistCompletionControllerHash,
          dependencies: ChecklistCompletionControllerFamily._dependencies,
          allTransitiveDependencies:
              ChecklistCompletionControllerFamily._allTransitiveDependencies,
          id: id,
        );

  ChecklistCompletionControllerProvider._internal(
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
  FutureOr<({int completedCount, int totalCount})> runNotifierBuild(
    covariant ChecklistCompletionController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(ChecklistCompletionController Function() create) {
    return ProviderOverride(
      origin: this,
      override: ChecklistCompletionControllerProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<ChecklistCompletionController,
      ({int completedCount, int totalCount})> createElement() {
    return _ChecklistCompletionControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChecklistCompletionControllerProvider && other.id == id;
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
mixin ChecklistCompletionControllerRef on AutoDisposeAsyncNotifierProviderRef<
    ({int completedCount, int totalCount})> {
  /// The parameter `id` of this provider.
  String get id;
}

class _ChecklistCompletionControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<
        ChecklistCompletionController, ({int completedCount, int totalCount})>
    with ChecklistCompletionControllerRef {
  _ChecklistCompletionControllerProviderElement(super.provider);

  @override
  String get id => (origin as ChecklistCompletionControllerProvider).id;
}

String _$checklistCompletionRateControllerHash() =>
    r'9913f84d9b1bd4500b1bdb772334d69796aed242';

abstract class _$ChecklistCompletionRateController
    extends BuildlessAutoDisposeAsyncNotifier<double> {
  late final String id;

  FutureOr<double> build({
    required String id,
  });
}

/// See also [ChecklistCompletionRateController].
@ProviderFor(ChecklistCompletionRateController)
const checklistCompletionRateControllerProvider =
    ChecklistCompletionRateControllerFamily();

/// See also [ChecklistCompletionRateController].
class ChecklistCompletionRateControllerFamily
    extends Family<AsyncValue<double>> {
  /// See also [ChecklistCompletionRateController].
  const ChecklistCompletionRateControllerFamily();

  /// See also [ChecklistCompletionRateController].
  ChecklistCompletionRateControllerProvider call({
    required String id,
  }) {
    return ChecklistCompletionRateControllerProvider(
      id: id,
    );
  }

  @override
  ChecklistCompletionRateControllerProvider getProviderOverride(
    covariant ChecklistCompletionRateControllerProvider provider,
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
  String? get name => r'checklistCompletionRateControllerProvider';
}

/// See also [ChecklistCompletionRateController].
class ChecklistCompletionRateControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<
        ChecklistCompletionRateController, double> {
  /// See also [ChecklistCompletionRateController].
  ChecklistCompletionRateControllerProvider({
    required String id,
  }) : this._internal(
          () => ChecklistCompletionRateController()..id = id,
          from: checklistCompletionRateControllerProvider,
          name: r'checklistCompletionRateControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$checklistCompletionRateControllerHash,
          dependencies: ChecklistCompletionRateControllerFamily._dependencies,
          allTransitiveDependencies: ChecklistCompletionRateControllerFamily
              ._allTransitiveDependencies,
          id: id,
        );

  ChecklistCompletionRateControllerProvider._internal(
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
  FutureOr<double> runNotifierBuild(
    covariant ChecklistCompletionRateController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(ChecklistCompletionRateController Function() create) {
    return ProviderOverride(
      origin: this,
      override: ChecklistCompletionRateControllerProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<ChecklistCompletionRateController,
      double> createElement() {
    return _ChecklistCompletionRateControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChecklistCompletionRateControllerProvider && other.id == id;
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
mixin ChecklistCompletionRateControllerRef
    on AutoDisposeAsyncNotifierProviderRef<double> {
  /// The parameter `id` of this provider.
  String get id;
}

class _ChecklistCompletionRateControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<
        ChecklistCompletionRateController,
        double> with ChecklistCompletionRateControllerRef {
  _ChecklistCompletionRateControllerProviderElement(super.provider);

  @override
  String get id => (origin as ChecklistCompletionRateControllerProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
