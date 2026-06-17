import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/habits/state/heatmap/habit_heatmap_data.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/charts/utils.dart';

/// The scrolling consistency grid: weekday rows × week columns, one fixed-size
/// square per day, the newest week pinned to the right and older weeks revealed
/// by dragging left (a horizontal `reverse` [ListView] anchors today at the
/// right edge on first paint and builds older columns lazily). A month-label
/// band sits above the cells (one label at the first week column of each month,
/// GitHub-style) so a year of columns is anchored in time.
///
/// Purely presentational — the host supplies the already-grouped [columns] (see
/// `groupIntoWeekColumns`) and the resolved [firstDayOfWeekIndex]; the "today"
/// cell is flagged in the data itself. Each in-range cell carries a tooltip +
/// screen-reader label (date + "n of m done"); empty days are a quiet neutral,
/// never a miss.
class HabitHeatmapGrid extends StatelessWidget {
  const HabitHeatmapGrid({
    required this.columns,
    required this.firstDayOfWeekIndex,
    super.key,
  });

  /// Week columns, oldest-first (the grid reverses them for display).
  final List<List<HeatmapDay?>> columns;

  /// `0 = Sunday` … `6 = Saturday`, used to label the weekday gutter.
  final int firstDayOfWeekIndex;

  /// Cell + gap geometry are data-viz dimensions (like the old history strip's
  /// `_maxCell`), not layout spacing — desktop gets a touch more room.
  static double _cellSize(BuildContext context) => isDesktop ? 14.0 : 11.0;

  /// Ascending column index → the month abbreviation to print above it. A label
  /// is emitted for the first column whose month differs from the column before
  /// it, so each month is anchored once at its leftmost (oldest) week.
  Map<int, String> _monthLabels(String locale) {
    final labels = <int, String>{};
    String? previous;
    for (var i = 0; i < columns.length; i++) {
      final firstDay = columns[i].firstWhere(
        (d) => d != null,
        orElse: () => null,
      );
      if (firstDay == null) continue;
      final month = DateFormat.MMM(locale).format(DateTime.parse(firstDay.ymd));
      if (month != previous) {
        labels[i] = month;
      }
      previous = month;
    }
    return labels;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cell = _cellSize(context);
    final gap = tokens.spacing.step1;
    final monthBand = tokens.spacing.step5;
    final gridHeight = monthBand + cell * 7 + gap * 6;
    final locale = Localizations.localeOf(context).toString();
    final monthLabels = _monthLabels(locale);

    return SizedBox(
      height: gridHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WeekdayGutter(
            firstDayOfWeekIndex: firstDayOfWeekIndex,
            cellSize: cell,
            gap: gap,
            monthBand: monthBand,
          ),
          SizedBox(width: tokens.spacing.step2),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              reverse: true,
              itemCount: columns.length,
              itemBuilder: (context, index) {
                // reverse → index 0 renders at the right edge; map it to the
                // newest column so today sits on the right on first paint.
                final ascending = columns.length - 1 - index;
                return Padding(
                  padding: EdgeInsets.only(left: gap),
                  child: _WeekColumn(
                    column: columns[ascending],
                    cellSize: cell,
                    gap: gap,
                    monthBand: monthBand,
                    monthLabel: monthLabels[ascending],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The fixed left column of weekday initials. Only Monday / Wednesday / Friday
/// are labelled (the GitHub-contributions convention) — distinct initials that
/// never collide (unlike Tue/Thu's shared "T"), placed at whatever rows they
/// fall on for the region's first day of week, so the gutter stays uncluttered.
class _WeekdayGutter extends StatelessWidget {
  const _WeekdayGutter({
    required this.firstDayOfWeekIndex,
    required this.cellSize,
    required this.gap,
    required this.monthBand,
  });

  final int firstDayOfWeekIndex;
  final double cellSize;
  final double gap;
  final double monthBand;

  /// The Sunday-zero index (0 = Sun … 6 = Sat) of the weekday at [row], or null
  /// when that row is not one of Mon/Wed/Fri.
  int? _labelledIndex(int row) {
    final sundayZero = (row + firstDayOfWeekIndex) % 7; // 0 = Sun … 6 = Sat
    final weekday = sundayZero == 0 ? DateTime.sunday : sundayZero; // 1 … 7
    const labelled = {DateTime.monday, DateTime.wednesday, DateTime.friday};
    return labelled.contains(weekday) ? sundayZero : null;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final narrowWeekdays = MaterialLocalizations.of(context).narrowWeekdays;
    final style = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.highEmphasis,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(height: monthBand),
        for (var row = 0; row < 7; row++) ...[
          if (row > 0) SizedBox(height: gap),
          SizedBox(
            height: cellSize,
            child: switch (_labelledIndex(row)) {
              final int i => Center(
                child: Text(narrowWeekdays[i], style: style),
              ),
              null => null,
            },
          ),
        ],
      ],
    );
  }
}

/// One week: an optional month label above seven stacked day cells (or blanks
/// for the leading/trailing padding of the oldest/newest weeks).
class _WeekColumn extends StatelessWidget {
  const _WeekColumn({
    required this.column,
    required this.cellSize,
    required this.gap,
    required this.monthBand,
    this.monthLabel,
  });

  final List<HeatmapDay?> column;
  final double cellSize;
  final double gap;
  final double monthBand;
  final String? monthLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: monthBand,
          child: monthLabel == null
              ? null
              : Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    monthLabel!,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ),
        ),
        for (var row = 0; row < column.length; row++) ...[
          if (row > 0) SizedBox(height: gap),
          if (column[row] == null)
            SizedBox.square(dimension: cellSize)
          else
            _HeatmapCell(day: column[row]!, size: cellSize),
        ],
      ],
    );
  }
}

/// A single day square. Shaded by completion intensity in discrete, perceptually
/// separated buckets (so adjacent days are distinguishable on the dark ground),
/// neutral when nothing was done, ringed when it is today. In-range days expose
/// a tooltip + semantics label so the value never depends on colour alone.
class _HeatmapCell extends StatelessWidget {
  const _HeatmapCell({required this.day, required this.size});

  final HeatmapDay day;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final hasMeaning = day.isInActiveRange || day.isToday;

    // A day with a win shows its green bucket. A day that was active but had no
    // success ("missed") is a *present* neutral (level02) — distinct from a day
    // before any habit existed, which stays the faintest neutral (level01).
    // Both are neutral, never red: a miss is recorded, not shamed.
    final fill = day.intensity > 0
        ? heatmapFillColor(day.intensity, tokens)
        : day.isInActiveRange
        ? tokens.colors.decorative.level02
        : tokens.colors.decorative.level01;

    final square = Container(
      key: ValueKey('habit-heatmap-cell-${day.ymd}'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        border: day.isToday
            ? Border.all(
                color: tokens.colors.interactive.enabled,
                width: 2,
              )
            : null,
      ),
    );

    if (!hasMeaning) {
      return square;
    }

    return Tooltip(
      excludeFromSemantics: true,
      message:
          '${chartDateFormatter(day.ymd)} · '
          '${day.successCount}/${day.activeCount}',
      child: Semantics(
        label: messages.habitHeatmapDaySemantic(
          chartDateFormatter(day.ymd),
          day.successCount,
          day.activeCount,
        ),
        child: square,
      ),
    );
  }
}

/// The discrete alpha steps a lit heatmap cell can take, lowest → highest. The
/// floor is deliberately well clear of the neutral "empty" tint so a single
/// completion is unmistakably *green*, not a faint smudge, and the steps are
/// spaced so neighbouring buckets stay distinguishable on a dark canvas.
const _heatmapAlphaSteps = [0.40, 0.58, 0.76, 1.0];

/// The fill for a heatmap cell (or legend swatch) of [intensity] in `[0, 1]`:
/// a quiet neutral when nothing was done, otherwise [successColor] snapped to
/// one of [_heatmapAlphaSteps] by quartile. The sanctioned data-viz shading
/// pattern (alpha on a semantic colour), shared by the grid cells and the
/// card's legend.
Color heatmapFillColor(double intensity, DsTokens tokens) {
  if (intensity <= 0) {
    return tokens.colors.decorative.level01;
  }
  final bucket = intensity <= 0.25
      ? 0
      : intensity <= 0.5
      ? 1
      : intensity <= 0.75
      ? 2
      : 3;
  return successColor.withValues(alpha: _heatmapAlphaSteps[bucket]);
}

/// The intensities (0 = empty, then one per [_heatmapAlphaSteps] bucket) the
/// card's "Less → More" legend renders, so the legend swatches exactly match
/// the five appearances a cell can take.
const heatmapLegendIntensities = [0.0, 0.25, 0.5, 0.75, 1.0];
