import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/charts/utils.dart';

typedef ColorByValue = Color Function(Observation);

/// Width of the value (left) axis gutter reserved inside every time-series
/// chart, and the exact left pad [DashboardChartDateAxis] applies, so a
/// chart's date labels always sit under its plot rather than under its y-axis
/// numbers.
///
/// ONE constant for every chart and every date axis, deliberately. Sizing the
/// gutter per chart from the labels it happens to draw buys ~10px of plot and
/// costs correctness: a chart and the date axis beside it are separate
/// widgets, so a measured gutter has to be threaded to both by hand, and the
/// five dashboards cards and three goal cards that pair them would each have
/// to re-derive the chart's own axis rule to do it. One of them getting it
/// wrong is invisible until the labels drift out from under the data.
///
/// 40 rather than the 52 this used to be: `formatAxisValue` compacts anything
/// from a thousand up ("15K"), so no axis label needs four digits of room.
const double kChartLeftAxisWidth = 40;

/// The laid-out width of [text] in [style], at the ambient text scale.
///
/// One helper rather than the private `_textWidth` every surface used to grow
/// its own: `MediaQuery.textScalerOf` and `Directionality` both have to be
/// threaded through, and a copy that forgets either mis-sizes only its own
/// surface, only at raised text scales — the least likely place to look.
double chartTextWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  return painter.width;
}

/// The type both axes are drawn in — shared so the value labels a chart
/// paints and the date labels beneath it cannot drift apart.
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
    super.key,
  });

  final DateTime rangeStart;
  final DateTime rangeEnd;
  final bool dateOnly;

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
TextStyle _tooltipLabelStyle(BuildContext context) {
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

/// The lines one tooltip renders: the day once as a header, then a quiet
/// label and a bold value per entry.
///
/// One builder for all three tooltip flavours (line, bar, and the Material
/// tooltip a hand-painted plot raises), because the promise they make is that
/// a value reads identically whichever chart it came from — and three copies
/// of the same span sequence is exactly how that promise gets broken.
List<InlineSpan> _tooltipSpans(
  BuildContext context, {
  required String date,
  required List<ChartTooltipEntry> entries,
  bool leadWithDate = true,
}) => [
  if (leadWithDate)
    TextSpan(text: '$date\n', style: chartTooltipDateStyle(context)),
  for (var index = 0; index < entries.length; index++) ...[
    if (entries[index].label case final label? when label.trim().isNotEmpty)
      TextSpan(text: '$label\n', style: _tooltipLabelStyle(context)),
    TextSpan(
      text: entries[index].value + (index == entries.length - 1 ? '' : '\n'),
      style: chartTooltipValueStyle(context),
    ),
  ],
];

/// Builds the fl_chart tooltip for a set of touched spots, with [date]
/// rendered exactly ONCE as a header above the value rows.
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
}) => [
  for (var index = 0; index < entries.length; index++)
    LineTooltipItem(
      '',
      chartTooltipValueStyle(context),
      textAlign: TextAlign.start,
      children: _tooltipSpans(
        context,
        date: date,
        entries: [entries[index]],
        leadWithDate: index == 0,
      ).cast<TextSpan>(),
    ),
];

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
  children: _tooltipSpans(context, date: date, entries: entries),
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
}) => BarTooltipItem(
  '',
  chartTooltipValueStyle(context),
  textAlign: TextAlign.start,
  children: _tooltipSpans(
    context,
    date: date,
    entries: [(label: null, value: value)],
  ).cast<TextSpan>(),
);

/// The tooltip chrome every time-series chart shares.
///
/// One record, two fl_chart classes: `LineTouchTooltipData` and
/// `BarTouchTooltipData` are unrelated types with the same eight settings, so
/// the values live here once and each builder spells only its own constructor.
///
/// `fitInside*` is the load-bearing part: a tooltip near the top or the edge
/// of the plot used to be drawn outside the chart box and was then clipped by
/// the card around it, so the value the user tapped for was the half that got
/// cut off. Shifted inside, it is always readable.
({
  double margin,
  EdgeInsets padding,
  Color background,
  BorderRadius radius,
  double maxContentWidth,
})
_tooltipChrome(BuildContext context) {
  final tokens = context.designTokens;
  return (
    margin: isMobile ? tokens.spacing.step6 : tokens.spacing.step5,
    padding: EdgeInsets.symmetric(
      horizontal: tokens.spacing.step3,
      vertical: tokens.spacing.step2,
    ),
    background: tokens.colors.background.level03,
    radius: BorderRadius.circular(tokens.radii.s),
    // Wide enough for a series name plus its unit on one line; the default
    // 120 broke "7-day average" across two.
    maxContentWidth: tokens.spacing.step13,
  );
}

/// [_tooltipChrome] as a line chart's touch settings.
LineTouchTooltipData chartTouchTooltipData(
  BuildContext context, {
  required GetLineTooltipItems getTooltipItems,
}) {
  final chrome = _tooltipChrome(context);
  return LineTouchTooltipData(
    tooltipMargin: chrome.margin,
    tooltipPadding: chrome.padding,
    getTooltipColor: (_) => chrome.background,
    tooltipBorderRadius: chrome.radius,
    fitInsideHorizontally: true,
    fitInsideVertically: true,
    maxContentWidth: chrome.maxContentWidth,
    getTooltipItems: getTooltipItems,
  );
}

/// [_tooltipChrome] as a bar chart's touch settings.
BarTouchTooltipData chartBarTouchTooltipData(
  BuildContext context, {
  required GetBarTooltipItem getTooltipItem,
}) {
  final chrome = _tooltipChrome(context);
  return BarTouchTooltipData(
    tooltipMargin: chrome.margin,
    tooltipPadding: chrome.padding,
    getTooltipColor: (_) => chrome.background,
    tooltipBorderRadius: chrome.radius,
    fitInsideHorizontally: true,
    fitInsideVertically: true,
    maxContentWidth: chrome.maxContentWidth,
    getTooltipItem: getTooltipItem,
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
