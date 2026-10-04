import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Builds a dashboard's chart card for one habit over a date range.
typedef DashboardHabitChartBuilder =
    Widget Function({
      required String habitId,
      required DateTime rangeStart,
      required DateTime rangeEnd,
    });

/// The habit chart a dashboard shows for a habit item, or null to show none.
///
/// The composition root wires the habits feature's completion card: habits
/// depends on dashboards, so dashboards cannot import it.
final dashboardHabitChartBuilderProvider =
    Provider<DashboardHabitChartBuilder?>(
      (ref) => null,
      name: 'dashboardHabitChartBuilderProvider',
    );
