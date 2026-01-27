// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'time_budget_progress_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides total stats for a day's budgets.
///
/// Uses the unified controller to ensure consistent updates when entries change.

@ProviderFor(dayBudgetStats)
final dayBudgetStatsProvider = DayBudgetStatsFamily._();

/// Provides total stats for a day's budgets.
///
/// Uses the unified controller to ensure consistent updates when entries change.

final class DayBudgetStatsProvider extends $FunctionalProvider<
        AsyncValue<DayBudgetStats>, DayBudgetStats, FutureOr<DayBudgetStats>>
    with $FutureModifier<DayBudgetStats>, $FutureProvider<DayBudgetStats> {
  /// Provides total stats for a day's budgets.
  ///
  /// Uses the unified controller to ensure consistent updates when entries change.
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

String _$dayBudgetStatsHash() => r'7b66ec7fef611199e17e687a40d5469cf3bb2b49';

/// Provides total stats for a day's budgets.
///
/// Uses the unified controller to ensure consistent updates when entries change.

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
  ///
  /// Uses the unified controller to ensure consistent updates when entries change.

  DayBudgetStatsProvider call({
    required DateTime date,
  }) =>
      DayBudgetStatsProvider._(argument: date, from: this);

  @override
  String toString() => r'dayBudgetStatsProvider';
}
