import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/charts/utils.dart';

typedef ColorByValue = Color Function(Observation);

/// Fallback width of the value (left) axis gutter, used where the tick labels
/// are not known ahead of time. The shared [DashboardChartDateAxis] left-pads
/// by exactly this much so its labels line up under the plot, not under the
/// y-axis numbers.
///
/// Prefer [chartLeftAxisWidth], which measures the axis the chart will actually
/// draw: a fixed 52 was sized for the widest label any chart might ever carry,
/// which left every three-character axis ("140", "15K", "96") paying for four
/// digits it never renders and squeezed the plot to the right of it.
const double kChartLeftAxisWidth = 40;

/// Floor and ceiling for a measured gutter. The floor keeps a one-character
/// axis from pulling the plot flush against the card edge; the ceiling stops a
/// pathological range from eating the plot.
const double _kChartLeftAxisMinWidth = 28;
const double _kChartLeftAxisMaxWidth = 64;

/// The gutter [axis]'s own tick labels actually need, in the ambient text
/// scale.
///
/// Charts call this for their `reservedSize`; callers that render their own
/// [DashboardChartDateAxis] or day track beside the plot pass the same value
/// so both stay on one grid.
double chartLeftAxisWidth(BuildContext context, NiceAxis axis) {
  if (!axis.interval.isFinite || axis.interval <= 0) {
    return kChartLeftAxisWidth;
  }
  final style = chartAxisLabelStyle(context);
  final scaler = MediaQuery.textScalerOf(context);
  final direction = Directionality.of(context);
  var widest = 0.0;
  // Bounded: a degenerate min/max/interval combination must not spin here.
  for (var tick = 0; tick < 16; tick++) {
    final value = axis.min + axis.interval * tick;
    if (value > axis.max + axis.interval / 2) break;
    final painter = TextPainter(
      text: TextSpan(text: formatAxisValue(value), style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    widest = math.max(widest, painter.width);
  }
  return (widest + context.designTokens.spacing.step3).clamp(
    _kChartLeftAxisMinWidth,
    _kChartLeftAxisMaxWidth,
  );
}

/// The type both axes are drawn in — extracted so [chartLeftAxisWidth] can
/// measure exactly what [ChartLabel] will paint.
TextStyle chartAxisLabelStyle(BuildContext context) {
  final tokens = context.designTokens;
  // body-small (not the smaller caption) at medium emphasis keeps axis
  // numbers and dates legible — including for low-vision readers.
  return tokens.typography.styles.body.bodySmall.copyWith(
    color: tokens.colors.text.mediumEmphasis,
  );
}

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
    this.dateOnly = false,
    this.leftAxisWidth,
    super.key,
  });

  final DateTime rangeStart;
  final DateTime rangeEnd;
  final bool dateOnly;

  /// The plot's own left gutter, when the caller measured it with
  /// [chartLeftAxisWidth]. Null keeps the [kChartLeftAxisWidth] fallback.
  final double? leftAxisWidth;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final startMs = rangeStart.millisecondsSinceEpoch;
    final endMs = rangeEnd.millisecondsSinceEpoch;
    const count = 4; // start, +1/3, +2/3, end — aligns with the linear axis.
    final raw = [
      for (var i = 0; i < count; i++)
        if (dateOnly)
          chartDateFormatterMmDdUtc(
            context,
            startMs + (endMs - startMs) * i / (count - 1),
          )
        else
          chartDateFormatterMmDd(
            startMs + (endMs - startMs) * i / (count - 1),
          ),
    ];
    // Short ranges make adjacent ticks land on the same calendar day; a
    // repeated "Aug 11 Aug 11" reads as a rendering bug, so consecutive
    // duplicates render as empty slots (spacing stays stable).
    final labels = [
      for (var i = 0; i < raw.length; i++)
        if (i > 0 && raw[i] == raw[i - 1]) '' else raw[i],
    ];
    return Padding(
      padding: EdgeInsets.only(
        left: leftAxisWidth ?? kChartLeftAxisWidth,
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
    return Text(
      text,
      style: chartAxisLabelStyle(context),
      textAlign: TextAlign.center,
      maxLines: 1,
    );
  }
}

/// One value row inside a chart tooltip: what the number is, and the number.
///
/// The label is optional — a single-series chart has nothing to disambiguate
/// and prints the value alone.
typedef ChartTooltipEntry = ({String? label, String value});

/// The tooltip's date header: the ONE line naming the day every value row
/// below it belongs to.
///
/// Quiet and small on purpose. It frames the rows; it is not one of them.
TextStyle chartTooltipDateStyle(BuildContext context) {
  final tokens = context.designTokens;
  return tokens.typography.styles.others.caption.copyWith(
    color: tokens.colors.text.mediumEmphasis,
  );
}

/// The series name above a value: smaller and lighter than the number, so a
/// tooltip reads as "this number, of this kind" rather than as two equally
/// loud lines.
TextStyle chartTooltipLabelStyle(BuildContext context) {
  final tokens = context.designTokens;
  return tokens.typography.styles.others.caption.copyWith(
    color: tokens.colors.text.lowEmphasis,
  );
}

/// The value itself — the one thing a tooltip exists to say, so it keeps the
/// bold weight.
TextStyle chartTooltipValueStyle(BuildContext context) {
  final tokens = context.designTokens;
  return tokens.typography.styles.subtitle.subtitle2.copyWith(
    color: tokens.colors.text.highEmphasis,
  );
}

/// Builds one fl_chart tooltip out of [entries], with [date] rendered exactly
/// ONCE as a header above the value rows.
///
/// fl_chart paints one text block per touched spot, so a per-spot date meant a
/// two-series tooltip printed "Aug 14" twice — once under each value. The
/// header rides the first block instead; every later block carries only its
/// own label and value.
///
/// The returned list is index-matched to [entries], which is the length
/// fl_chart requires it to have.
List<LineTooltipItem> chartTooltipItems(
  BuildContext context, {
  required String date,
  required List<ChartTooltipEntry> entries,
}) {
  final valueStyle = chartTooltipValueStyle(context);
  return [
    for (var index = 0; index < entries.length; index++)
      LineTooltipItem(
        '',
        valueStyle,
        textAlign: TextAlign.start,
        children: [
          if (index == 0)
            TextSpan(text: '$date\n', style: chartTooltipDateStyle(context)),
          if (entries[index].label case final label?
              when label.trim().isNotEmpty)
            TextSpan(text: '$label\n', style: chartTooltipLabelStyle(context)),
          TextSpan(text: entries[index].value, style: valueStyle),
        ],
      ),
  ];
}

/// The same tooltip content as [chartTooltipItems], as one rich message for a
/// Material [Tooltip].
///
/// Charts that paint their own bars (the goal cards' day-grid series) cannot
/// use fl_chart's tooltip, and were silently untappable as a result. This keeps
/// their popup identical in wording, order and type to the fl_chart ones.
InlineSpan chartTooltipMessage(
  BuildContext context, {
  required String date,
  required List<ChartTooltipEntry> entries,
}) => TextSpan(
  children: [
    TextSpan(text: date, style: chartTooltipDateStyle(context)),
    for (final entry in entries) ...[
      if (entry.label case final label? when label.trim().isNotEmpty)
        TextSpan(text: '\n$label', style: chartTooltipLabelStyle(context)),
      TextSpan(
        text: '\n${entry.value}',
        style: chartTooltipValueStyle(context),
      ),
    ],
  ],
);

/// Shared tooltip surface for a chart, so a hand-painted series' Material
/// tooltip matches the fl_chart ones it sits beside.
BoxDecoration chartTooltipDecoration(BuildContext context) {
  final tokens = context.designTokens;
  return BoxDecoration(
    color: tokens.colors.background.level03,
    borderRadius: BorderRadius.circular(tokens.radii.s),
  );
}

/// The bar-chart twin of [chartTooltipItems]: a bar chart shows one rod at a
/// time, so the date header and the single value row live in one item.
BarTooltipItem chartBarTooltipItem(
  BuildContext context, {
  required String date,
  required String value,
  String? label,
}) {
  final valueStyle = chartTooltipValueStyle(context);
  return BarTooltipItem(
    '',
    valueStyle,
    textAlign: TextAlign.start,
    children: [
      TextSpan(text: '$date\n', style: chartTooltipDateStyle(context)),
      if (label != null && label.trim().isNotEmpty)
        TextSpan(text: '$label\n', style: chartTooltipLabelStyle(context)),
      TextSpan(text: value, style: valueStyle),
    ],
  );
}

/// [chartTouchTooltipData] for bar charts — same surface, same fit-inside
/// guarantee, same padding.
BarTouchTooltipData chartBarTouchTooltipData(
  BuildContext context, {
  required GetBarTooltipItem getTooltipItem,
}) {
  final tokens = context.designTokens;
  return BarTouchTooltipData(
    tooltipMargin: isMobile ? tokens.spacing.step6 : tokens.spacing.step5,
    tooltipPadding: EdgeInsets.symmetric(
      horizontal: tokens.spacing.step3,
      vertical: tokens.spacing.step2,
    ),
    getTooltipColor: (_) => tokens.colors.background.level03,
    tooltipBorderRadius: BorderRadius.circular(tokens.radii.s),
    fitInsideHorizontally: true,
    fitInsideVertically: true,
    maxContentWidth: tokens.spacing.step13,
    getTooltipItem: getTooltipItem,
  );
}

/// The tooltip settings every time-series chart shares.
///
/// `fitInside*` is the load-bearing part: a tooltip near the top or the edge
/// of the plot used to be drawn outside the chart box and was then clipped by
/// the card around it, so the value the user tapped for was the half that got
/// cut off. Shifted inside, it is always readable.
LineTouchTooltipData chartTouchTooltipData(
  BuildContext context, {
  required GetLineTooltipItems getTooltipItems,
}) {
  final tokens = context.designTokens;
  return LineTouchTooltipData(
    tooltipMargin: isMobile ? tokens.spacing.step6 : tokens.spacing.step5,
    tooltipPadding: EdgeInsets.symmetric(
      horizontal: tokens.spacing.step3,
      vertical: tokens.spacing.step2,
    ),
    getTooltipColor: (_) => tokens.colors.background.level03,
    tooltipBorderRadius: BorderRadius.circular(tokens.radii.s),
    fitInsideHorizontally: true,
    fitInsideVertically: true,
    // Wide enough for a series name plus its unit on one line; the default
    // 120 broke "7-day average" across two.
    maxContentWidth: tokens.spacing.step13,
    getTooltipItems: getTooltipItems,
  );
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
