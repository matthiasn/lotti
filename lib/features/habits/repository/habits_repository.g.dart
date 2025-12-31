// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habits_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the [HabitsRepository] instance.
///
/// This provider bridges the gap between getIt service locator and Riverpod,
/// allowing the repository to be easily overridden in tests.

@ProviderFor(habitsRepository)
final habitsRepositoryProvider = HabitsRepositoryProvider._();

/// Provides the [HabitsRepository] instance.
///
/// This provider bridges the gap between getIt service locator and Riverpod,
/// allowing the repository to be easily overridden in tests.

final class HabitsRepositoryProvider extends $FunctionalProvider<
    HabitsRepository,
    HabitsRepository,
    HabitsRepository> with $Provider<HabitsRepository> {
  /// Provides the [HabitsRepository] instance.
  ///
  /// This provider bridges the gap between getIt service locator and Riverpod,
  /// allowing the repository to be easily overridden in tests.
  HabitsRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'habitsRepositoryProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$habitsRepositoryHash();

  @$internal
  @override
  $ProviderElement<HabitsRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HabitsRepository create(Ref ref) {
    return habitsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HabitsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HabitsRepository>(value),
    );
  }
}

String _$habitsRepositoryHash() => r'a133f820ac786a068e2d5d1fb3ba2257aee6b1bb';
