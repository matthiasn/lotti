// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_completion_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$habitCompletionControllerHash() =>
    r'5655bcdd2c0d3997a640fc6fb4294b0f8d788f00';

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

abstract class _$HabitCompletionController
    extends BuildlessAutoDisposeAsyncNotifier<List<HabitResult>> {
  late final String habitId;
  late final DateTime rangeStart;
  late final DateTime rangeEnd;

  FutureOr<List<HabitResult>> build({
    required String habitId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  });
}

/// See also [HabitCompletionController].
@ProviderFor(HabitCompletionController)
const habitCompletionControllerProvider = HabitCompletionControllerFamily();

/// See also [HabitCompletionController].
class HabitCompletionControllerFamily
    extends Family<AsyncValue<List<HabitResult>>> {
  /// See also [HabitCompletionController].
  const HabitCompletionControllerFamily();

  /// See also [HabitCompletionController].
  HabitCompletionControllerProvider call({
    required String habitId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    return HabitCompletionControllerProvider(
      habitId: habitId,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }

  @override
  HabitCompletionControllerProvider getProviderOverride(
    covariant HabitCompletionControllerProvider provider,
  ) {
    return call(
      habitId: provider.habitId,
      rangeStart: provider.rangeStart,
      rangeEnd: provider.rangeEnd,
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
  String? get name => r'habitCompletionControllerProvider';
}

/// See also [HabitCompletionController].
class HabitCompletionControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<HabitCompletionController,
        List<HabitResult>> {
  /// See also [HabitCompletionController].
  HabitCompletionControllerProvider({
    required String habitId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) : this._internal(
          () => HabitCompletionController()
            ..habitId = habitId
            ..rangeStart = rangeStart
            ..rangeEnd = rangeEnd,
          from: habitCompletionControllerProvider,
          name: r'habitCompletionControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$habitCompletionControllerHash,
          dependencies: HabitCompletionControllerFamily._dependencies,
          allTransitiveDependencies:
              HabitCompletionControllerFamily._allTransitiveDependencies,
          habitId: habitId,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        );

  HabitCompletionControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.habitId,
    required this.rangeStart,
    required this.rangeEnd,
  }) : super.internal();

  final String habitId;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  @override
  FutureOr<List<HabitResult>> runNotifierBuild(
    covariant HabitCompletionController notifier,
  ) {
    return notifier.build(
      habitId: habitId,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }

  @override
  Override overrideWith(HabitCompletionController Function() create) {
    return ProviderOverride(
      origin: this,
      override: HabitCompletionControllerProvider._internal(
        () => create()
          ..habitId = habitId
          ..rangeStart = rangeStart
          ..rangeEnd = rangeEnd,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        habitId: habitId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<HabitCompletionController,
      List<HabitResult>> createElement() {
    return _HabitCompletionControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is HabitCompletionControllerProvider &&
        other.habitId == habitId &&
        other.rangeStart == rangeStart &&
        other.rangeEnd == rangeEnd;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, habitId.hashCode);
    hash = _SystemHash.combine(hash, rangeStart.hashCode);
    hash = _SystemHash.combine(hash, rangeEnd.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin HabitCompletionControllerRef
    on AutoDisposeAsyncNotifierProviderRef<List<HabitResult>> {
  /// The parameter `habitId` of this provider.
  String get habitId;

  /// The parameter `rangeStart` of this provider.
  DateTime get rangeStart;

  /// The parameter `rangeEnd` of this provider.
  DateTime get rangeEnd;
}

class _HabitCompletionControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<HabitCompletionController,
        List<HabitResult>> with HabitCompletionControllerRef {
  _HabitCompletionControllerProviderElement(super.provider);

  @override
  String get habitId => (origin as HabitCompletionControllerProvider).habitId;
  @override
  DateTime get rangeStart =>
      (origin as HabitCompletionControllerProvider).rangeStart;
  @override
  DateTime get rangeEnd =>
      (origin as HabitCompletionControllerProvider).rangeEnd;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
