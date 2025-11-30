// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checklist_item_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$checklistItemControllerHash() =>
    r'00bee3c0e85d8430cf8480cde7f2247bc2f8c20a';

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

abstract class _$ChecklistItemController
    extends BuildlessAutoDisposeAsyncNotifier<ChecklistItem?> {
  late final String id;
  late final String? taskId;

  FutureOr<ChecklistItem?> build({
    required String id,
    required String? taskId,
  });
}

/// See also [ChecklistItemController].
@ProviderFor(ChecklistItemController)
const checklistItemControllerProvider = ChecklistItemControllerFamily();

/// See also [ChecklistItemController].
class ChecklistItemControllerFamily extends Family<AsyncValue<ChecklistItem?>> {
  /// See also [ChecklistItemController].
  const ChecklistItemControllerFamily();

  /// See also [ChecklistItemController].
  ChecklistItemControllerProvider call({
    required String id,
    required String? taskId,
  }) {
    return ChecklistItemControllerProvider(
      id: id,
      taskId: taskId,
    );
  }

  @override
  ChecklistItemControllerProvider getProviderOverride(
    covariant ChecklistItemControllerProvider provider,
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
  String? get name => r'checklistItemControllerProvider';
}

/// See also [ChecklistItemController].
class ChecklistItemControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<ChecklistItemController,
        ChecklistItem?> {
  /// See also [ChecklistItemController].
  ChecklistItemControllerProvider({
    required String id,
    required String? taskId,
  }) : this._internal(
          () => ChecklistItemController()
            ..id = id
            ..taskId = taskId,
          from: checklistItemControllerProvider,
          name: r'checklistItemControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$checklistItemControllerHash,
          dependencies: ChecklistItemControllerFamily._dependencies,
          allTransitiveDependencies:
              ChecklistItemControllerFamily._allTransitiveDependencies,
          id: id,
          taskId: taskId,
        );

  ChecklistItemControllerProvider._internal(
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
  FutureOr<ChecklistItem?> runNotifierBuild(
    covariant ChecklistItemController notifier,
  ) {
    return notifier.build(
      id: id,
      taskId: taskId,
    );
  }

  @override
  Override overrideWith(ChecklistItemController Function() create) {
    return ProviderOverride(
      origin: this,
      override: ChecklistItemControllerProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<ChecklistItemController,
      ChecklistItem?> createElement() {
    return _ChecklistItemControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChecklistItemControllerProvider &&
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
mixin ChecklistItemControllerRef
    on AutoDisposeAsyncNotifierProviderRef<ChecklistItem?> {
  /// The parameter `id` of this provider.
  String get id;

  /// The parameter `taskId` of this provider.
  String? get taskId;
}

class _ChecklistItemControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<ChecklistItemController,
        ChecklistItem?> with ChecklistItemControllerRef {
  _ChecklistItemControllerProviderElement(super.provider);

  @override
  String get id => (origin as ChecklistItemControllerProvider).id;
  @override
  String? get taskId => (origin as ChecklistItemControllerProvider).taskId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
