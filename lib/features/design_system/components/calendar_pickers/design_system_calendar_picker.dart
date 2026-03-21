import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

enum DesignSystemCalendarDateCardVisualState {
  idle,
  hover,
}

class DesignSystemCalendarDateCard extends StatefulWidget {
  const DesignSystemCalendarDateCard({
    required this.weekdayLabel,
    required this.dayLabel,
    required this.selected,
    required this.onPressed,
    this.semanticsLabel,
    this.forcedState,
    super.key,
  }) : assert(
         weekdayLabel != '' || semanticsLabel != null,
         'Provide weekdayLabel or semanticsLabel for accessibility.',
       );

  final String weekdayLabel;
  final String dayLabel;
  final bool selected;
  final VoidCallback? onPressed;
  final String? semanticsLabel;
  final DesignSystemCalendarDateCardVisualState? forcedState;

  @override
  State<DesignSystemCalendarDateCard> createState() =>
      _DesignSystemCalendarDateCardState();
}

class _DesignSystemCalendarDateCardState
    extends State<DesignSystemCalendarDateCard> {
  bool _hovered = false;

  @override
  void didUpdateWidget(covariant DesignSystemCalendarDateCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final interactionModeChanged =
        oldWidget.forcedState != widget.forcedState ||
        oldWidget.selected != widget.selected ||
        (oldWidget.onPressed == null) != (widget.onPressed == null);

    if (interactionModeChanged) {
      _hovered = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final enabled = widget.onPressed != null;
    final visualState = _resolveVisualState(enabled);
    final styleSpec = _CalendarDateCardStyleSpec.fromTokens(
      tokens: tokens,
      selected: widget.selected,
      visualState: visualState,
    );

    final card = Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label:
          widget.semanticsLabel ?? '${widget.weekdayLabel} ${widget.dayLabel}',
      child: MouseRegion(
        onEnter: widget.forcedState == null && enabled && !widget.selected
            ? (_) => setState(() => _hovered = true)
            : null,
        onExit: widget.forcedState == null && enabled && !widget.selected
            ? (_) => setState(() => _hovered = false)
            : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: styleSpec.backgroundColor,
              borderRadius: BorderRadius.circular(tokens.radii.l),
              border: styleSpec.borderColor == null
                  ? null
                  : Border.all(color: styleSpec.borderColor!),
            ),
            child: SizedBox(
              width: 50,
              height: 56,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step2,
                  vertical: tokens.spacing.step2,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.weekdayLabel,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: styleSpec.weekdayColor,
                      ),
                    ),
                    SizedBox(height: tokens.spacing.step3),
                    Text(
                      widget.dayLabel,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: tokens.typography.styles.subtitle.subtitle2
                          .copyWith(color: styleSpec.dayColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (enabled) {
      return card;
    }

    return Opacity(
      opacity: tokens.colors.text.lowEmphasis.a,
      child: card,
    );
  }

  DesignSystemCalendarDateCardVisualState _resolveVisualState(bool enabled) {
    if (!enabled || widget.selected) {
      return DesignSystemCalendarDateCardVisualState.idle;
    }

    if (widget.forcedState != null) {
      return widget.forcedState!;
    }

    if (_hovered) {
      return DesignSystemCalendarDateCardVisualState.hover;
    }

    return DesignSystemCalendarDateCardVisualState.idle;
  }
}

class _CalendarDateCardStyleSpec {
  const _CalendarDateCardStyleSpec({
    required this.backgroundColor,
    required this.weekdayColor,
    required this.dayColor,
    this.borderColor,
  });

  factory _CalendarDateCardStyleSpec.fromTokens({
    required DsTokens tokens,
    required bool selected,
    required DesignSystemCalendarDateCardVisualState visualState,
  }) {
    if (selected) {
      return _CalendarDateCardStyleSpec(
        backgroundColor: tokens.colors.surface.selected,
        weekdayColor: tokens.colors.interactive.enabled,
        dayColor: tokens.colors.interactive.enabled,
        borderColor: tokens.colors.interactive.enabled,
      );
    }

    return _CalendarDateCardStyleSpec(
      backgroundColor:
          visualState == DesignSystemCalendarDateCardVisualState.hover
          ? tokens.colors.background.level02
          : null,
      weekdayColor: tokens.colors.text.lowEmphasis,
      dayColor: tokens.colors.text.mediumEmphasis,
    );
  }

  final Color? backgroundColor;
  final Color weekdayColor;
  final Color dayColor;
  final Color? borderColor;
}

@immutable
class DesignSystemCalendarMonthRailSection {
  const DesignSystemCalendarMonthRailSection({
    required this.yearLabel,
    required this.items,
  });

  final String yearLabel;
  final List<DesignSystemCalendarMonthRailItem> items;
}

@immutable
class DesignSystemCalendarMonthRailItem {
  const DesignSystemCalendarMonthRailItem({
    required this.label,
    required this.selected,
    this.key,
    this.onPressed,
    this.semanticsLabel,
  });

  final Key? key;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  final String? semanticsLabel;
}

enum DesignSystemCalendarDayCellType {
  activeMonth,
  today,
  selected,
}

enum DesignSystemCalendarDayCellSelectionPosition {
  start,
  middle,
  end,
  standalone,
}

enum DesignSystemCalendarDayCellVisualState {
  idle,
  hover,
}

@immutable
class DesignSystemCalendarDayCellData {
  const DesignSystemCalendarDayCellData({
    required this.label,
    required this.type,
    this.key,
    this.selectionPosition = DesignSystemCalendarDayCellSelectionPosition.start,
    this.onPressed,
    this.semanticsLabel,
    this.forcedState,
  });

  final Key? key;
  final String label;
  final DesignSystemCalendarDayCellType type;
  final DesignSystemCalendarDayCellSelectionPosition selectionPosition;
  final VoidCallback? onPressed;
  final String? semanticsLabel;
  final DesignSystemCalendarDayCellVisualState? forcedState;
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

  static const _headerHeight = 36.0;
  static const _cellSize = 40.0;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final totalHeight =
        2 * tokens.spacing.step5 +
        _headerHeight +
        tokens.spacing.step1 +
        _cellSize +
        tokens.spacing.step1 +
        weeks.length * _cellSize +
        (weeks.length - 1) * tokens.spacing.step1;

    return SizedBox(
      width: 440,
      height: totalHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.background.level01,
          borderRadius: BorderRadius.circular(tokens.radii.s),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40464646),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(tokens.radii.s),
          child: Row(
            children: [
              SizedBox(
                width: 128,
                child: _CalendarMonthRail(
                  monthSections: monthSections,
                ),
              ),
              SizedBox(
                width: 312,
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

class _CalendarMonthRail extends StatelessWidget {
  const _CalendarMonthRail({
    required this.monthSections,
  });

  final List<DesignSystemCalendarMonthRailSection> monthSections;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: tokens.colors.decorative.level01),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step5),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final section in monthSections) ...[
                _CalendarYearDivider(label: section.yearLabel),
                for (final item in section.items)
                  _CalendarMonthRailButton(item: item),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarYearDivider extends StatelessWidget {
  const _CalendarYearDivider({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final labelColor = tokens.colors.decorative.level02;

    return Padding(
      padding: EdgeInsets.only(
        top: tokens.spacing.step3,
        bottom: tokens.spacing.step2,
      ),
      child: SizedBox(
        width: 96,
        height: 16,
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: tokens.typography.styles.others.overline.copyWith(
              color: labelColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarMonthRailButton extends StatefulWidget {
  const _CalendarMonthRailButton({
    required this.item,
  });

  final DesignSystemCalendarMonthRailItem item;

  @override
  State<_CalendarMonthRailButton> createState() =>
      _CalendarMonthRailButtonState();
}

class _CalendarMonthRailButtonState extends State<_CalendarMonthRailButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final enabled = widget.item.onPressed != null;

    final backgroundColor = switch ((widget.item.selected, _hovered)) {
      (true, _) => tokens.colors.surface.hover,
      (false, true) => tokens.colors.surface.enabled,
      (false, false) => null,
    };

    final button = Semantics(
      button: true,
      enabled: enabled,
      selected: widget.item.selected,
      label: widget.item.semanticsLabel ?? widget.item.label,
      child: MouseRegion(
        onEnter: enabled && !widget.item.selected
            ? (_) => setState(() => _hovered = true)
            : null,
        onExit: enabled && !widget.item.selected
            ? (_) => setState(() => _hovered = false)
            : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.item.onPressed,
          child: DecoratedBox(
            key: widget.item.key,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(tokens.radii.l),
            ),
            child: SizedBox(
              width: 96,
              height: 36,
              child: Center(
                child: Text(
                  widget.item.label,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (enabled) {
      return button;
    }

    return Opacity(
      opacity: tokens.colors.text.lowEmphasis.a,
      child: button,
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

    return SizedBox(
      width: 280,
      height: 36,
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
              width: 96,
              height: 36,
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

    if (enabled) {
      return button;
    }

    return Opacity(
      opacity: tokens.colors.text.lowEmphasis.a,
      child: button,
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final label in labels)
          SizedBox(
            width: 40,
            height: 40,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final cell in row)
          cell == null
              ? const SizedBox(width: 40, height: 40)
              : _CalendarDayCell(data: cell),
      ],
    );
  }
}

class _CalendarDayCell extends StatefulWidget {
  const _CalendarDayCell({
    required this.data,
  });

  final DesignSystemCalendarDayCellData data;

  @override
  State<_CalendarDayCell> createState() => _CalendarDayCellState();
}

class _CalendarDayCellState extends State<_CalendarDayCell> {
  bool _hovered = false;

  @override
  void didUpdateWidget(covariant _CalendarDayCell oldWidget) {
    super.didUpdateWidget(oldWidget);

    final interactionModeChanged =
        oldWidget.data.forcedState != widget.data.forcedState ||
        oldWidget.data.type != widget.data.type ||
        oldWidget.data.selectionPosition != widget.data.selectionPosition ||
        (oldWidget.data.onPressed == null) != (widget.data.onPressed == null);

    if (interactionModeChanged) {
      _hovered = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final enabled = widget.data.onPressed != null;
    final visualState = _resolveVisualState(enabled);
    final styleSpec = _CalendarDayCellStyleSpec.fromTokens(
      tokens: tokens,
      data: widget.data,
      visualState: visualState,
      enabled: enabled,
    );

    final cell = Semantics(
      button: true,
      enabled: enabled,
      selected: widget.data.type == DesignSystemCalendarDayCellType.selected,
      label: widget.data.semanticsLabel ?? widget.data.label,
      child: MouseRegion(
        onEnter: widget.data.forcedState == null && enabled
            ? (_) => setState(() => _hovered = true)
            : null,
        onExit: widget.data.forcedState == null && enabled
            ? (_) => setState(() => _hovered = false)
            : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.data.onPressed,
          child: SizedBox(
            key: widget.data.key,
            width: 40,
            height: 40,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (styleSpec.connectionColor != null)
                  Positioned(
                    left:
                        widget.data.selectionPosition ==
                            DesignSystemCalendarDayCellSelectionPosition.start
                        ? 20
                        : 0,
                    right:
                        widget.data.selectionPosition ==
                            DesignSystemCalendarDayCellSelectionPosition.end
                        ? 20
                        : -20,
                    child: ColoredBox(
                      color: styleSpec.connectionColor!,
                      child: const SizedBox(height: 40),
                    ),
                  ),
                if (styleSpec.backgroundColor != null)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: styleSpec.backgroundColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const SizedBox(width: 40, height: 40),
                  ),
                Text(
                  widget.data.label,
                  style: styleSpec.labelStyle.copyWith(
                    color: styleSpec.labelColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (enabled) {
      return cell;
    }

    return Opacity(
      opacity: tokens.colors.text.lowEmphasis.a,
      child: cell,
    );
  }

  DesignSystemCalendarDayCellVisualState _resolveVisualState(bool enabled) {
    if (!enabled) {
      return DesignSystemCalendarDayCellVisualState.idle;
    }

    if (widget.data.forcedState != null) {
      return widget.data.forcedState!;
    }

    if (_hovered) {
      return DesignSystemCalendarDayCellVisualState.hover;
    }

    return DesignSystemCalendarDayCellVisualState.idle;
  }
}

class _CalendarDayCellStyleSpec {
  const _CalendarDayCellStyleSpec({
    required this.labelStyle,
    required this.labelColor,
    this.backgroundColor,
    this.connectionColor,
  });

  factory _CalendarDayCellStyleSpec.fromTokens({
    required DsTokens tokens,
    required DesignSystemCalendarDayCellData data,
    required DesignSystemCalendarDayCellVisualState visualState,
    required bool enabled,
  }) {
    if (data.type == DesignSystemCalendarDayCellType.selected) {
      if (data.selectionPosition ==
          DesignSystemCalendarDayCellSelectionPosition.middle) {
        if (!enabled) {
          return _CalendarDayCellStyleSpec(
            labelStyle: tokens.typography.styles.subtitle.subtitle2,
            labelColor: tokens.colors.interactive.enabled,
            connectionColor: tokens.colors.background.level02,
          );
        }

        return _CalendarDayCellStyleSpec(
          labelStyle: tokens.typography.styles.subtitle.subtitle2,
          labelColor: tokens.colors.interactive.enabled,
          backgroundColor:
              visualState == DesignSystemCalendarDayCellVisualState.hover
              ? tokens.colors.background.level02
              : null,
          connectionColor: tokens.colors.background.level03,
        );
      }

      final showConnection =
          data.selectionPosition !=
          DesignSystemCalendarDayCellSelectionPosition.standalone;

      return _CalendarDayCellStyleSpec(
        labelStyle: tokens.typography.styles.subtitle.subtitle2,
        labelColor: tokens.colors.text.onInteractiveAlert,
        backgroundColor:
            visualState == DesignSystemCalendarDayCellVisualState.hover
            ? tokens.colors.interactive.hover
            : tokens.colors.interactive.enabled,
        connectionColor: showConnection
            ? (enabled
                  ? tokens.colors.background.level03
                  : tokens.colors.background.level02)
            : null,
      );
    }

    if (data.type == DesignSystemCalendarDayCellType.today) {
      return _CalendarDayCellStyleSpec(
        labelStyle: tokens.typography.styles.body.bodySmall,
        labelColor: visualState == DesignSystemCalendarDayCellVisualState.hover
            ? tokens.colors.interactive.hover
            : tokens.colors.interactive.enabled,
        backgroundColor:
            visualState == DesignSystemCalendarDayCellVisualState.hover
            ? tokens.colors.background.level03
            : tokens.colors.background.level02,
      );
    }

    return _CalendarDayCellStyleSpec(
      labelStyle: tokens.typography.styles.body.bodySmall,
      labelColor: tokens.colors.text.highEmphasis,
      backgroundColor:
          visualState == DesignSystemCalendarDayCellVisualState.hover
          ? tokens.colors.surface.hover
          : null,
    );
  }

  final TextStyle labelStyle;
  final Color labelColor;
  final Color? backgroundColor;
  final Color? connectionColor;
}
