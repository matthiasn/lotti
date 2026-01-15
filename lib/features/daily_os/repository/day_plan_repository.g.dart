// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'day_plan_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the [DayPlanRepository] instance.

@ProviderFor(dayPlanRepository)
final dayPlanRepositoryProvider = DayPlanRepositoryProvider._();

/// Provides the [DayPlanRepository] instance.

final class DayPlanRepositoryProvider extends $FunctionalProvider<
    DayPlanRepository,
    DayPlanRepository,
    DayPlanRepository> with $Provider<DayPlanRepository> {
  /// Provides the [DayPlanRepository] instance.
  DayPlanRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'dayPlanRepositoryProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$dayPlanRepositoryHash();

  @$internal
  @override
  $ProviderElement<DayPlanRepository> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DayPlanRepository create(Ref ref) {
    return dayPlanRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DayPlanRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DayPlanRepository>(value),
    );
  }
}

String _$dayPlanRepositoryHash() => r'7bff98c9e0d4e8f7679adbcce94140e77ec1499d';
