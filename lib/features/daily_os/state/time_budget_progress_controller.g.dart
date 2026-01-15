// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'time_budget_progress_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides aggregated budget progress for a day.
///
/// Combines the day's time budgets with actual recorded time entries
/// to calculate progress for each budget category.

@ProviderFor(TimeBudgetProgressController)
final timeBudgetProgressControllerProvider =
    TimeBudgetProgressControllerFamily._();

/// Provides aggregated budget progress for a day.
///
/// Combines the day's time budgets with actual recorded time entries
/// to calculate progress for each budget category.
final class TimeBudgetProgressControllerProvider extends $AsyncNotifierProvider<
    TimeBudgetProgressController, List<TimeBudgetProgress>> {
  /// Provides aggregated budget progress for a day.
  ///
  /// Combines the day's time budgets with actual recorded time entries
  /// to calculate progress for each budget category.
  TimeBudgetProgressControllerProvider._(
      {required TimeBudgetProgressControllerFamily super.from,
      required DateTime super.argument})
      : super(
          retry: null,
          name: r'timeBudgetProgressControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$timeBudgetProgressControllerHash();

  @override
  String toString() {
    return r'timeBudgetProgressControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TimeBudgetProgressController create() => TimeBudgetProgressController();

  @override
  bool operator ==(Object other) {
    return other is TimeBudgetProgressControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$timeBudgetProgressControllerHash() =>
    r'adf5d54e39ab90c473c8b0639919c9c8a2a50a01';

/// Provides aggregated budget progress for a day.
///
/// Combines the day's time budgets with actual recorded time entries
/// to calculate progress for each budget category.

final class TimeBudgetProgressControllerFamily extends $Family
    with
        $ClassFamilyOverride<
            TimeBudgetProgressController,
            AsyncValue<List<TimeBudgetProgress>>,
            List<TimeBudgetProgress>,
            FutureOr<List<TimeBudgetProgress>>,
            DateTime> {
  TimeBudgetProgressControllerFamily._()
      : super(
          retry: null,
          name: r'timeBudgetProgressControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Provides aggregated budget progress for a day.
  ///
  /// Combines the day's time budgets with actual recorded time entries
  /// to calculate progress for each budget category.

  TimeBudgetProgressControllerProvider call({
    required DateTime date,
  }) =>
      TimeBudgetProgressControllerProvider._(argument: date, from: this);

  @override
  String toString() => r'timeBudgetProgressControllerProvider';
}

/// Provides aggregated budget progress for a day.
///
/// Combines the day's time budgets with actual recorded time entries
/// to calculate progress for each budget category.

abstract class _$TimeBudgetProgressController
    extends $AsyncNotifier<List<TimeBudgetProgress>> {
  late final _$args = ref.$arg as DateTime;
  DateTime get date => _$args;

  FutureOr<List<TimeBudgetProgress>> build({
    required DateTime date,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref
        as $Ref<AsyncValue<List<TimeBudgetProgress>>, List<TimeBudgetProgress>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<TimeBudgetProgress>>,
            List<TimeBudgetProgress>>,
        AsyncValue<List<TimeBudgetProgress>>,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              date: _$args,
            ));
  }
}

/// Provides total stats for a day's budgets.

@ProviderFor(dayBudgetStats)
final dayBudgetStatsProvider = DayBudgetStatsFamily._();

/// Provides total stats for a day's budgets.

final class DayBudgetStatsProvider extends $FunctionalProvider<
        AsyncValue<DayBudgetStats>, DayBudgetStats, FutureOr<DayBudgetStats>>
    with $FutureModifier<DayBudgetStats>, $FutureProvider<DayBudgetStats> {
  /// Provides total stats for a day's budgets.
  DayBudgetStatsProvider._(
      {required DayBudgetStatsFamily super.from,
      required DateTime super.argument})
      : super(
          retry: null,
          name: r'dayBudgetStatsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$dayBudgetStatsHash();

  @override
  String toString() {
    return r'dayBudgetStatsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<DayBudgetStats> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<DayBudgetStats> create(Ref ref) {
    final argument = this.argument as DateTime;
    return dayBudgetStats(
      ref,
      date: argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DayBudgetStatsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$dayBudgetStatsHash() => r'88329ea0a3d893732a63faaa1531a79757e2652c';

/// Provides total stats for a day's budgets.

final class DayBudgetStatsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<DayBudgetStats>, DateTime> {
  DayBudgetStatsFamily._()
      : super(
          retry: null,
          name: r'dayBudgetStatsProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Provides total stats for a day's budgets.

  DayBudgetStatsProvider call({
    required DateTime date,
  }) =>
      DayBudgetStatsProvider._(argument: date, from: this);

  @override
  String toString() => r'dayBudgetStatsProvider';
}
