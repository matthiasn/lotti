import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/utils/disabled_overlay.dart';

part 'design_system_calendar_date_card.dart';
part 'design_system_calendar_day_cell.dart';
part 'design_system_calendar_month_rail.dart';

@immutable
class _CalendarPickerGeometry {
  const _CalendarPickerGeometry({
    required this.railWidth,
    required this.controlHeight,
    required this.railButtonWidth,
    required this.dateCardWidth,
    required this.dateCardHeight,
  });

  factory _CalendarPickerGeometry.fromTokens(DsTokens tokens) {
    return _CalendarPickerGeometry(
      // Fits a three-letter month label plus horizontal rail padding.
      railWidth: tokens.spacing.step12 + (tokens.spacing.step5 * 2),
      // Matches the design's compact rail/header control height.
      controlHeight: tokens.spacing.step8 - tokens.spacing.step2,
      railButtonWidth: tokens.spacing.step12,
      // Matches the shipped 50x56 date cards while staying token-derived.
      dateCardWidth: tokens.spacing.step9 + tokens.spacing.step1,
      dateCardHeight: tokens.spacing.step9 + tokens.spacing.step3,
    );
  }

  final double railWidth;
  final double controlHeight;
  final double railButtonWidth;
  final double dateCardWidth;
  final double dateCardHeight;
}

class DesignSystemCalendarPicker extends StatelessWidget {
  const DesignSystemCalendarPicker({
    required this.monthSections,
    required this.visibleMonthLabel,
    required this.weekdayLabels,
    required this.weeks,
    required this.todayLabel,
    this.onTodayPressed,
    super.key,
  }) : assert(weekdayLabels.length == 7, 'Provide exactly 7 weekday labels.');

  final List<DesignSystemCalendarMonthRailSection> monthSections;
  final String visibleMonthLabel;
  final List<String> weekdayLabels;
  final List<List<DesignSystemCalendarDayCellData?>> weeks;
  final String todayLabel;
  final VoidCallback? onTodayPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final geometry = _CalendarPickerGeometry.fromTokens(tokens);
    final cellSize = tokens.spacing.step8;
    final gap = tokens.spacing.step1;
    final verticalPadding = 2 * tokens.spacing.step5;
    final gridWidth = 7 * cellSize + 2 * tokens.spacing.step5;
    final totalWidth = geometry.railWidth + gridWidth;
    final fixedContentHeight = geometry.controlHeight + gap + cellSize + gap;
    final weeksHeight = weeks.length * cellSize + (weeks.length - 1) * gap;
    final totalHeight = verticalPadding + fixedContentHeight + weeksHeight;

    return SizedBox(
      width: totalWidth,
      height: totalHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.background.level01,
          borderRadius: BorderRadius.circular(tokens.radii.s),
          boxShadow: [
            BoxShadow(
              color: tokens.colors.decorative.level01,
              blurRadius: tokens.spacing.step2,
              offset: Offset(0, tokens.spacing.step1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(tokens.radii.s),
          child: Row(
            children: [
              SizedBox(
                width: geometry.railWidth,
                child: _CalendarMonthRail(
                  monthSections: monthSections,
                ),
              ),
              SizedBox(
                width: gridWidth,
                child: _CalendarMonthView(
                  visibleMonthLabel: visibleMonthLabel,
                  weekdayLabels: weekdayLabels,
                  weeks: weeks,
                  todayLabel: todayLabel,
                  onTodayPressed: onTodayPressed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarMonthView extends StatelessWidget {
  const _CalendarMonthView({
    required this.visibleMonthLabel,
    required this.weekdayLabels,
    required this.weeks,
    required this.todayLabel,
    this.onTodayPressed,
  });

  final String visibleMonthLabel;
  final List<String> weekdayLabels;
  final List<List<DesignSystemCalendarDayCellData?>> weeks;
  final String todayLabel;
  final VoidCallback? onTodayPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Padding(
      padding: EdgeInsets.all(tokens.spacing.step5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CalendarMonthHeader(
            visibleMonthLabel: visibleMonthLabel,
            todayLabel: todayLabel,
            onTodayPressed: onTodayPressed,
          ),
          SizedBox(height: tokens.spacing.step1),
          _CalendarWeekdayHeaderRow(labels: weekdayLabels),
          SizedBox(height: tokens.spacing.step1),
          for (var index = 0; index < weeks.length; index++) ...[
            _CalendarWeekRow(row: _trimTrailingPlaceholders(weeks[index])),
            if (index < weeks.length - 1)
              SizedBox(height: tokens.spacing.step1),
          ],
        ],
      ),
    );
  }

  List<DesignSystemCalendarDayCellData?> _trimTrailingPlaceholders(
    List<DesignSystemCalendarDayCellData?> row,
  ) {
    var end = row.length;
    while (end > 0 && row[end - 1] == null) {
      end -= 1;
    }
    return row.sublist(0, end);
  }
}

class _CalendarMonthHeader extends StatelessWidget {
  const _CalendarMonthHeader({
    required this.visibleMonthLabel,
    required this.todayLabel,
    this.onTodayPressed,
  });

  final String visibleMonthLabel;
  final String todayLabel;
  final VoidCallback? onTodayPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final geometry = _CalendarPickerGeometry.fromTokens(tokens);

    final cellSize = tokens.spacing.step8;

    return SizedBox(
      width: 7 * cellSize,
      height: geometry.controlHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              visibleMonthLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
          ),
          _CalendarTodayButton(
            label: todayLabel,
            onPressed: onTodayPressed,
          ),
        ],
      ),
    );
  }
}

class _CalendarTodayButton extends StatefulWidget {
  const _CalendarTodayButton({
    required this.label,
    this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  State<_CalendarTodayButton> createState() => _CalendarTodayButtonState();
}

class _CalendarTodayButtonState extends State<_CalendarTodayButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final geometry = _CalendarPickerGeometry.fromTokens(tokens);
    final enabled = widget.onPressed != null;

    final button = Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: MouseRegion(
        onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
        onExit: enabled ? (_) => setState(() => _hovered = false) : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _hovered ? tokens.colors.surface.enabled : null,
              borderRadius: BorderRadius.circular(tokens.radii.l),
            ),
            child: SizedBox(
              width: geometry.railButtonWidth,
              height: geometry.controlHeight,
              child: Center(
                child: Text(
                  widget.label,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: _hovered
                        ? tokens.colors.interactive.hover
                        : tokens.colors.interactive.enabled,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return button.withDisabledOpacity(
      enabled: enabled,
      disabledOpacity: tokens.colors.text.lowEmphasis.a,
    );
  }
}

class _CalendarWeekdayHeaderRow extends StatelessWidget {
  const _CalendarWeekdayHeaderRow({
    required this.labels,
  });

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cellSize = tokens.spacing.step8;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final label in labels)
          SizedBox(
            width: cellSize,
            height: cellSize,
            child: Center(
              child: Text(
                label,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CalendarWeekRow extends StatelessWidget {
  const _CalendarWeekRow({
    required this.row,
  });

  final List<DesignSystemCalendarDayCellData?> row;

  @override
  Widget build(BuildContext context) {
    final cellSize = context.designTokens.spacing.step8;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final cell in row)
          cell == null
              ? SizedBox(width: cellSize, height: cellSize)
              : _CalendarDayCell(data: cell),
      ],
    );
  }
}
