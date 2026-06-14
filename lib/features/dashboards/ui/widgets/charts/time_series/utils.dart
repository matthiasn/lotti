import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/charts/utils.dart';

typedef ColorByValue = Color Function(Observation);

/// Width of the value (left) axis gutter reserved inside every time-series
/// chart. The shared [DashboardChartDateAxis] left-pads by exactly this much so
/// its labels line up under the plot, not under the y-axis numbers.
const double kChartLeftAxisWidth = 52;

/// Shared, controlled date-axis row rendered *below* a time-series chart.
///
/// fl_chart's per-chart bottom axis clipped/dropped the leading date label on
/// bar charts at narrow widths (the ~480px desktop detail pane) while line
/// charts kept it, so adjacent cards disagreed on their start date. We render
/// the date labels ourselves instead: four evenly-spaced ticks (start, +1/3,
/// +2/3, end) that align with the charts' linear time axis, left-padded by
/// [kChartLeftAxisWidth] so they sit under the plot. Every bar and line card
/// now shows identical, aligned dates at all widths.
class DashboardChartDateAxis extends StatelessWidget {
  const DashboardChartDateAxis({
    required this.rangeStart,
    required this.rangeEnd,
    super.key,
  });

  final DateTime rangeStart;
  final DateTime rangeEnd;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final startMs = rangeStart.millisecondsSinceEpoch;
    final endMs = rangeEnd.millisecondsSinceEpoch;
    const count = 4; // start, +1/3, +2/3, end — aligns with the linear axis.
    final labels = [
      for (var i = 0; i < count; i++)
        chartDateFormatterMmDd(startMs + (endMs - startMs) * i / (count - 1)),
    ];
    return Padding(
      padding: EdgeInsets.only(
        left: kChartLeftAxisWidth,
        right: tokens.spacing.step2,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [for (final l in labels) ChartLabel(l)],
      ),
    );
  }
}

/// Axis label used for both the value (left) and date (bottom) axes.
///
/// Pulls colour and type from the design system (caption type at
/// medium-emphasis) instead of the legacy half-opacity grey, so axis numbers
/// stay legible — including for low-vision readers — in both themes.
class ChartLabel extends StatelessWidget {
  const ChartLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Text(
      text,
      // body-small (not the smaller caption) at medium emphasis keeps axis
      // numbers and dates legible — including for low-vision readers.
      style: tokens.typography.styles.body.bodySmall.copyWith(
        color: tokens.colors.text.mediumEmphasis,
      ),
      textAlign: TextAlign.center,
      maxLines: 1,
    );
  }
}

/// Formats a value-axis tick: thousands separators for plain integers, compact
/// notation (e.g. `2.4K`, `14K`) once values reach the thousands so labels stay
/// short and never clip the reserved gutter, and a single decimal otherwise.
String formatAxisValue(double value) {
  if (value.abs() >= 1000) {
    return NumberFormat.compact().format(value);
  }
  if (value == value.roundToDouble()) {
    return NumberFormat('#,###').format(value);
  }
  return NumberFormat('#,##0.#').format(value);
}

Widget leftTitleWidgets(double value, TitleMeta meta) {
  return ChartLabel(formatAxisValue(value));
}

/// A "nice" axis range and tick interval for a data range.
///
/// Uses the Heckbert nice-numbers algorithm so ticks land on rounded,
/// evenly-spaced values (0/5k/10k/15k rather than the raw data max), which is
/// what makes the value axis trustworthy and readable.
class NiceAxis {
  const NiceAxis({
    required this.min,
    required this.max,
    required this.interval,
  });

  final double min;
  final double max;
  final double interval;
}

NiceAxis niceAxis(
  num dataMin,
  num dataMax, {
  int targetTicks = 4,
  bool zeroBased = false,
}) {
  final lo = (zeroBased ? 0 : dataMin).toDouble();
  var hi = dataMax.toDouble();
  if (hi <= lo) {
    hi = lo + 1;
  }
  final range = _niceNum(hi - lo, round: false);
  final step = _niceNum(range / targetTicks, round: true);
  final niceMin = (lo / step).floorToDouble() * step;
  final niceMax = (hi / step).ceilToDouble() * step;
  return NiceAxis(min: niceMin, max: niceMax, interval: step);
}

double _niceNum(double range, {required bool round}) {
  if (range <= 0) {
    return 1;
  }
  final exponent = (math.log(range) / math.ln10).floor();
  final fraction = range / math.pow(10, exponent);
  final double niceFraction;
  if (round) {
    if (fraction < 1.5) {
      niceFraction = 1;
    } else if (fraction < 3) {
      niceFraction = 2;
    } else if (fraction < 7) {
      niceFraction = 5;
    } else {
      niceFraction = 10;
    }
  } else {
    if (fraction <= 1) {
      niceFraction = 1;
    } else if (fraction <= 2) {
      niceFraction = 2;
    } else if (fraction <= 5) {
      niceFraction = 5;
    } else {
      niceFraction = 10;
    }
  }
  return niceFraction * math.pow(10, exponent).toDouble();
}

/// Subtle horizontal gridline tuned to the active theme via the
/// `decorative.level01` token.
FlLine chartGridLine(BuildContext context) {
  return FlLine(
    color: context.designTokens.colors.decorative.level01,
    strokeWidth: 1,
  );
}

/// Emphasised dashed gridline (e.g. the systolic/diastolic reference lines on
/// the blood-pressure chart), tinted by the caller.
FlLine chartEmphasisLine(Color color) {
  return FlLine(
    color: color,
    dashArray: [5, 3],
  );
}
