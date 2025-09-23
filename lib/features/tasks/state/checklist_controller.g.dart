// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checklist_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$checklistControllerHash() =>
    r'1fb979f081189d7486b8119a883b24db5113b9a0';

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
  late final String? taskId;

  FutureOr<Checklist?> build({
    required String id,
    required String? taskId,
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
    required String? taskId,
  }) {
    return ChecklistControllerProvider(
      id: id,
      taskId: taskId,
    );
  }

  @override
  ChecklistControllerProvider getProviderOverride(
    covariant ChecklistControllerProvider provider,
  ) {
    return call(
      id: provider.id,
      taskId: provider.taskId,
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
    required String? taskId,
  }) : this._internal(
          () => ChecklistController()
            ..id = id
            ..taskId = taskId,
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
          taskId: taskId,
        );

  ChecklistControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
    required this.taskId,
  }) : super.internal();

  final String id;
  final String? taskId;

  @override
  FutureOr<Checklist?> runNotifierBuild(
    covariant ChecklistController notifier,
  ) {
    return notifier.build(
      id: id,
      taskId: taskId,
    );
  }

  @override
  Override overrideWith(ChecklistController Function() create) {
    return ProviderOverride(
      origin: this,
      override: ChecklistControllerProvider._internal(
        () => create()
          ..id = id
          ..taskId = taskId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
        taskId: taskId,
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
    return other is ChecklistControllerProvider &&
        other.id == id &&
        other.taskId == taskId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);
    hash = _SystemHash.combine(hash, taskId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ChecklistControllerRef
    on AutoDisposeAsyncNotifierProviderRef<Checklist?> {
  /// The parameter `id` of this provider.
  String get id;

  /// The parameter `taskId` of this provider.
  String? get taskId;
}

class _ChecklistControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<ChecklistController,
        Checklist?> with ChecklistControllerRef {
  _ChecklistControllerProviderElement(super.provider);

  @override
  String get id => (origin as ChecklistControllerProvider).id;
  @override
  String? get taskId => (origin as ChecklistControllerProvider).taskId;
}

String _$checklistCompletionControllerHash() =>
    r'ccffcfc070594b1e0d55163ac4f90ce2cbcb64fa';

abstract class _$ChecklistCompletionController
    extends BuildlessAutoDisposeAsyncNotifier<
        ({int completedCount, int totalCount})> {
  late final String id;
  late final String? taskId;

  FutureOr<({int completedCount, int totalCount})> build({
    required String id,
    required String? taskId,
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
    required String? taskId,
  }) {
    return ChecklistCompletionControllerProvider(
      id: id,
      taskId: taskId,
    );
  }

  @override
  ChecklistCompletionControllerProvider getProviderOverride(
    covariant ChecklistCompletionControllerProvider provider,
  ) {
    return call(
      id: provider.id,
      taskId: provider.taskId,
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
    required String? taskId,
  }) : this._internal(
          () => ChecklistCompletionController()
            ..id = id
            ..taskId = taskId,
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
          taskId: taskId,
        );

  ChecklistCompletionControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
    required this.taskId,
  }) : super.internal();

  final String id;
  final String? taskId;

  @override
  FutureOr<({int completedCount, int totalCount})> runNotifierBuild(
    covariant ChecklistCompletionController notifier,
  ) {
    return notifier.build(
      id: id,
      taskId: taskId,
    );
  }

  @override
  Override overrideWith(ChecklistCompletionController Function() create) {
    return ProviderOverride(
      origin: this,
      override: ChecklistCompletionControllerProvider._internal(
        () => create()
          ..id = id
          ..taskId = taskId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
        taskId: taskId,
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
    return other is ChecklistCompletionControllerProvider &&
        other.id == id &&
        other.taskId == taskId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);
    hash = _SystemHash.combine(hash, taskId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ChecklistCompletionControllerRef on AutoDisposeAsyncNotifierProviderRef<
    ({int completedCount, int totalCount})> {
  /// The parameter `id` of this provider.
  String get id;

  /// The parameter `taskId` of this provider.
  String? get taskId;
}

class _ChecklistCompletionControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<
        ChecklistCompletionController, ({int completedCount, int totalCount})>
    with ChecklistCompletionControllerRef {
  _ChecklistCompletionControllerProviderElement(super.provider);

  @override
  String get id => (origin as ChecklistCompletionControllerProvider).id;
  @override
  String? get taskId =>
      (origin as ChecklistCompletionControllerProvider).taskId;
}

String _$checklistCompletionRateControllerHash() =>
    r'59be08483780e4180f6751755a9734a2a80333e5';

abstract class _$ChecklistCompletionRateController
    extends BuildlessAutoDisposeAsyncNotifier<double> {
  late final String id;
  late final String? taskId;

  FutureOr<double> build({
    required String id,
    required String? taskId,
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
    required String? taskId,
  }) {
    return ChecklistCompletionRateControllerProvider(
      id: id,
      taskId: taskId,
    );
  }

  @override
  ChecklistCompletionRateControllerProvider getProviderOverride(
    covariant ChecklistCompletionRateControllerProvider provider,
  ) {
    return call(
      id: provider.id,
      taskId: provider.taskId,
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
    required String? taskId,
  }) : this._internal(
          () => ChecklistCompletionRateController()
            ..id = id
            ..taskId = taskId,
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
          taskId: taskId,
        );

  ChecklistCompletionRateControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
    required this.taskId,
  }) : super.internal();

  final String id;
  final String? taskId;

  @override
  FutureOr<double> runNotifierBuild(
    covariant ChecklistCompletionRateController notifier,
  ) {
    return notifier.build(
      id: id,
      taskId: taskId,
    );
  }

  @override
  Override overrideWith(ChecklistCompletionRateController Function() create) {
    return ProviderOverride(
      origin: this,
      override: ChecklistCompletionRateControllerProvider._internal(
        () => create()
          ..id = id
          ..taskId = taskId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
        taskId: taskId,
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
    return other is ChecklistCompletionRateControllerProvider &&
        other.id == id &&
        other.taskId == taskId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);
    hash = _SystemHash.combine(hash, taskId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ChecklistCompletionRateControllerRef
    on AutoDisposeAsyncNotifierProviderRef<double> {
  /// The parameter `id` of this provider.
  String get id;

  /// The parameter `taskId` of this provider.
  String? get taskId;
}

class _ChecklistCompletionRateControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<
        ChecklistCompletionRateController,
        double> with ChecklistCompletionRateControllerRef {
  _ChecklistCompletionRateControllerProviderElement(super.provider);

  @override
  String get id => (origin as ChecklistCompletionRateControllerProvider).id;
  @override
  String? get taskId =>
      (origin as ChecklistCompletionRateControllerProvider).taskId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
