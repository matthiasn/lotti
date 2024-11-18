// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checklist_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$checklistControllerHash() =>
    r'baec5f2ff72d531e038bf7e1b746806b4691f83a';

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
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
