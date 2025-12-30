// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$habitByIdHash() => r'b2fecd5e5320f9a48221af203927cc3d0808a2e6';

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

/// Stream provider for watching a habit by ID.
///
/// Copied from [habitById].
@ProviderFor(habitById)
const habitByIdProvider = HabitByIdFamily();

/// Stream provider for watching a habit by ID.
///
/// Copied from [habitById].
class HabitByIdFamily extends Family<AsyncValue<HabitDefinition?>> {
  /// Stream provider for watching a habit by ID.
  ///
  /// Copied from [habitById].
  const HabitByIdFamily();

  /// Stream provider for watching a habit by ID.
  ///
  /// Copied from [habitById].
  HabitByIdProvider call(
    String habitId,
  ) {
    return HabitByIdProvider(
      habitId,
    );
  }

  @override
  HabitByIdProvider getProviderOverride(
    covariant HabitByIdProvider provider,
  ) {
    return call(
      provider.habitId,
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
  String? get name => r'habitByIdProvider';
}

/// Stream provider for watching a habit by ID.
///
/// Copied from [habitById].
class HabitByIdProvider extends AutoDisposeStreamProvider<HabitDefinition?> {
  /// Stream provider for watching a habit by ID.
  ///
  /// Copied from [habitById].
  HabitByIdProvider(
    String habitId,
  ) : this._internal(
          (ref) => habitById(
            ref as HabitByIdRef,
            habitId,
          ),
          from: habitByIdProvider,
          name: r'habitByIdProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$habitByIdHash,
          dependencies: HabitByIdFamily._dependencies,
          allTransitiveDependencies: HabitByIdFamily._allTransitiveDependencies,
          habitId: habitId,
        );

  HabitByIdProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.habitId,
  }) : super.internal();

  final String habitId;

  @override
  Override overrideWith(
    Stream<HabitDefinition?> Function(HabitByIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: HabitByIdProvider._internal(
        (ref) => create(ref as HabitByIdRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        habitId: habitId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<HabitDefinition?> createElement() {
    return _HabitByIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is HabitByIdProvider && other.habitId == habitId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, habitId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin HabitByIdRef on AutoDisposeStreamProviderRef<HabitDefinition?> {
  /// The parameter `habitId` of this provider.
  String get habitId;
}

class _HabitByIdProviderElement
    extends AutoDisposeStreamProviderElement<HabitDefinition?>
    with HabitByIdRef {
  _HabitByIdProviderElement(super.provider);

  @override
  String get habitId => (origin as HabitByIdProvider).habitId;
}

String _$habitDashboardsHash() => r'1ca36922087ac2502d2ca26c2c48e683797cd4d7';

/// Stream provider for dashboards used in habit settings.
///
/// Copied from [habitDashboards].
@ProviderFor(habitDashboards)
final habitDashboardsProvider =
    AutoDisposeStreamProvider<List<DashboardDefinition>>.internal(
  habitDashboards,
  name: r'habitDashboardsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$habitDashboardsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef HabitDashboardsRef
    = AutoDisposeStreamProviderRef<List<DashboardDefinition>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
