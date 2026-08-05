import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:permission_handler/permission_handler.dart';

/// One row on the Health Import page: a family of health data the user can
/// import as a unit.
///
/// The grouping mirrors how Apple Health and Health Connect present the data
/// and how `HealthImport` fetches it — activity is aggregated per day, workouts
/// are their own entry kind, and the rest are discrete sample types imported by
/// list.
enum HealthImportCategory {
  activity,
  sleep,
  heartRate,
  bloodPressure,
  bodyMeasurement,
  workout,
}

/// Where one category currently stands.
///
/// [lastResult] is kept after a run finishes so the row can report what
/// happened — a sample count, a permission refusal, an error — instead of
/// silently returning to its resting state, which is what made the old page
/// feel like nothing had happened.
@immutable
class HealthImportCategoryState {
  const HealthImportCategoryState({
    this.isRunning = false,
    this.lastResult,
    this.dateFrom,
    this.dateTo,
  });

  final bool isRunning;
  final HealthImportResult? lastResult;

  /// The range the run covered, captured when it started. A result describes
  /// the range it was imported for, so the page shows it only while that range
  /// is still the selected one — see [HealthImportState.resultFor].
  final DateTime? dateFrom;
  final DateTime? dateTo;
}

/// The Health Import page's whole state: the chosen range plus per-category
/// progress.
@immutable
class HealthImportState {
  const HealthImportState({
    required this.dateFrom,
    required this.dateTo,
    required this.categories,
  });

  final DateTime dateFrom;
  final DateTime dateTo;
  final Map<HealthImportCategory, HealthImportCategoryState> categories;

  HealthImportCategoryState stateFor(HealthImportCategory category) =>
      categories[category] ?? const HealthImportCategoryState();

  /// [category]'s outcome, but only while it still describes the selected
  /// range.
  ///
  /// Leaving "42 samples imported" on a row while the dates above it change
  /// makes the count describe a range it never covered. Checking at render
  /// time rather than clearing on every edit also covers the harder case: a run
  /// already in flight when the range changes finishes against the *old* dates,
  /// and its result is simply never shown against the new ones.
  HealthImportResult? resultFor(HealthImportCategory category) {
    final categoryState = stateFor(category);
    if (categoryState.dateFrom != dateFrom || categoryState.dateTo != dateTo) {
      return null;
    }
    return categoryState.lastResult;
  }

  /// True while any category is importing. The page disables every trigger on
  /// this, because `HealthImport` serializes requests anyway: letting the user
  /// queue six imports would only stack six spinners in front of the same
  /// single-file pipeline.
  bool get isAnyRunning =>
      categories.values.any((category) => category.isRunning);

  /// True when a category's last run came back with nothing and read access is
  /// a plausible reason.
  ///
  /// Drives the page's access callout. Read from [resultFor] rather than
  /// [HealthImportCategoryState.lastResult] so an outcome that no longer
  /// describes the selected range stops raising it, exactly as the rows do.
  bool get needsAccessCheck => HealthImportCategory.values.any((category) {
    final status = resultFor(category)?.status;
    return status == HealthImportStatus.permissionDenied ||
        status == HealthImportStatus.noDataOrAccess;
  });

  HealthImportState copyWith({
    DateTime? dateFrom,
    DateTime? dateTo,
    Map<HealthImportCategory, HealthImportCategoryState>? categories,
  }) => HealthImportState(
    dateFrom: dateFrom ?? this.dateFrom,
    dateTo: dateTo ?? this.dateTo,
    categories: categories ?? this.categories,
  );
}

/// Selectable quick ranges, in days back from today.
const healthImportQuickRangeDays = <int>[7, 30, 90];

/// Drives the Health Import page: owns the date range and runs imports,
/// tracking each category's progress and outcome.
///
/// Kept out of the widget so the range arithmetic and the result bookkeeping
/// can be tested without pumping a tree, and so the page itself stays a pure
/// rendering of this state.
class HealthImportController extends Notifier<HealthImportState> {
  /// Default range: the last week, ending at the end of today.
  ///
  /// The end is the last millisecond of today rather than "tomorrow" (which is
  /// what the previous page defaulted to, and showed to the user as such).
  /// `HealthImport` caps every request at the current instant regardless, so a
  /// future end date only ever misrepresented the range in the UI.
  @override
  HealthImportState build() {
    final now = clock.now();
    return HealthImportState(
      dateFrom: startOfDay(now.subtract(const Duration(days: 7))),
      dateTo: endOfDay(now),
      categories: const {},
    );
  }

  static DateTime startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime endOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day, 23, 59, 59, 999);

  HealthImport get _healthImport => getIt<HealthImport>();

  /// Sets the range start, pulling the end forward if the user picked a start
  /// after it — an inverted range would silently import nothing.
  void setDateFrom(DateTime value) {
    final dateFrom = startOfDay(value);
    state = state.copyWith(
      dateFrom: dateFrom,
      dateTo: dateFrom.isAfter(state.dateTo) ? endOfDay(value) : state.dateTo,
    );
  }

  /// Sets the range end, pushing the start back if the user picked an end
  /// before it.
  void setDateTo(DateTime value) {
    final dateTo = endOfDay(value);
    state = state.copyWith(
      dateTo: dateTo,
      dateFrom: dateTo.isBefore(state.dateFrom)
          ? startOfDay(value)
          : state.dateFrom,
    );
  }

  /// Selects the last [days] days, ending at the end of today.
  void selectQuickRange(int days) {
    final now = clock.now();
    state = state.copyWith(
      dateFrom: startOfDay(now.subtract(Duration(days: days))),
      dateTo: endOfDay(now),
    );
  }

  /// Runs one category over the current range, recording its outcome.
  ///
  /// Refused while *any* category is importing, not merely this one.
  /// `HealthImport` serializes requests into the health store anyway, so a
  /// second request would only queue behind the first while its row spun; and
  /// starting one mid-`runAll` made that batch skip the category it reached
  /// later, so its combined result no longer described what it ran.
  Future<HealthImportResult?> runImport(HealthImportCategory category) async {
    if (state.isAnyRunning) {
      return null;
    }

    // No `lastResult`: a stale success count must not sit beside a spinner.
    final dateFrom = state.dateFrom;
    final dateTo = state.dateTo;
    _updateCategory(
      category,
      HealthImportCategoryState(
        isRunning: true,
        dateFrom: dateFrom,
        dateTo: dateTo,
      ),
    );

    // `HealthImport` returns outcomes rather than throwing, but that is a
    // contract held one layer down, and the failure mode if it ever breaks is
    // the worst one available: a row that spins forever and refuses taps while
    // it does. A run always ends in a rendered outcome, whatever happens below.
    final HealthImportResult result;
    try {
      result = await switch (category) {
        HealthImportCategory.activity => _healthImport.getActivityHealthData(
          dateFrom: dateFrom,
          dateTo: dateTo,
        ),
        HealthImportCategory.workout => _healthImport.getWorkoutsHealthData(
          dateFrom: dateFrom,
          dateTo: dateTo,
        ),
        HealthImportCategory.sleep => _healthImport.fetchHealthData(
          types: sleepTypes,
          dateFrom: dateFrom,
          dateTo: dateTo,
        ),
        HealthImportCategory.heartRate => _healthImport.fetchHealthData(
          types: heartRateTypes,
          dateFrom: dateFrom,
          dateTo: dateTo,
        ),
        HealthImportCategory.bloodPressure => _healthImport.fetchHealthData(
          types: bpTypes,
          dateFrom: dateFrom,
          dateTo: dateTo,
        ),
        HealthImportCategory.bodyMeasurement => _healthImport.fetchHealthData(
          types: bodyMeasurementTypes,
          dateFrom: dateFrom,
          dateTo: dateTo,
        ),
      };
    } catch (error) {
      // Converted rather than rethrown: the page calls this unawaited, so a
      // rethrow becomes an unhandled async error, and `runAll` would abandon
      // every category after this one.
      final failure = HealthImportResult.failed(error);
      if (ref.mounted) {
        _updateCategory(
          category,
          HealthImportCategoryState(
            lastResult: failure,
            dateFrom: dateFrom,
            dateTo: dateTo,
          ),
        );
      }
      return failure;
    }

    // The page is auto-disposed; a run that outlives the route must not write
    // to a disposed notifier.
    if (!ref.mounted) {
      return result;
    }

    _updateCategory(
      category,
      HealthImportCategoryState(
        lastResult: result,
        dateFrom: dateFrom,
        dateTo: dateTo,
      ),
    );
    return result;
  }

  /// Opens the operating system's settings page for Lotti, from which its
  /// health permissions can be reached.
  ///
  /// The escape hatch iOS makes necessary: once a data type has been answered
  /// for — at the first authorization sheet, or later in Settings → Privacy &
  /// Security → Health — HealthKit will not present it again, so no amount of
  /// re-requesting from inside the app can turn it back on. Only the user can,
  /// there.
  Future<bool> openHealthSettings() => openAppSettings();

  /// Runs every category in order, returning the combined outcome.
  ///
  /// Sequential by design: `HealthImport` serializes requests into the health
  /// store anyway, so firing them concurrently would only make six rows spin at
  /// once while the work still happened one at a time.
  Future<HealthImportResult> runAll() async {
    final results = <HealthImportResult>[];
    for (final category in HealthImportCategory.values) {
      final result = await runImport(category);
      if (result != null) {
        results.add(result);
      }
      if (!ref.mounted) break;
    }
    return HealthImportResult.combined(results);
  }

  void _updateCategory(
    HealthImportCategory category,
    HealthImportCategoryState categoryState,
  ) {
    state = state.copyWith(
      categories: {...state.categories, category: categoryState},
    );
  }
}

// ignore: specify_nonobvious_property_types
final healthImportControllerProvider =
    NotifierProvider.autoDispose<HealthImportController, HealthImportState>(
      HealthImportController.new,
      name: 'healthImportControllerProvider',
    );
