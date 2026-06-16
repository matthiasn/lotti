import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/utils/disabled_overlay.dart';

/// Category of a calendar day cell, driving its color treatment.
enum DesignSystemCalendarDayCellType {
  activeMonth,
  today,
  selected,
}

/// Position of a selected cell within a contiguous selection range, used to
/// draw the connecting bar between days (none for a [standalone] single day).
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

/// Immutable description of a single day cell rendered by [CalendarDayCell].
///
/// Carries the day [label], its [type] and [selectionPosition], an optional
/// [onPressed] (null renders the cell disabled/dimmed), plus accessibility and
/// showcase hooks ([semanticsLabel], [forcedState]).
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

/// A single token-styled day cell in the design-system month grid.
///
/// Renders the day number with the background, label, and selection-range
/// connector implied by its [DesignSystemCalendarDayCellData], tracking
/// hover state and dimming when the cell is disabled.
class CalendarDayCell extends StatefulWidget {
  const CalendarDayCell({
    required this.data,
    super.key,
  });

  final DesignSystemCalendarDayCellData data;

  @override
  State<CalendarDayCell> createState() => _CalendarDayCellState();
}

class _CalendarDayCellState extends State<CalendarDayCell> {
  bool _hovered = false;

  @override
  void didUpdateWidget(covariant CalendarDayCell oldWidget) {
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
    final cellSize = tokens.spacing.step8;
    final halfCellSize = cellSize / 2;
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
            width: cellSize,
            height: cellSize,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (styleSpec.connectionColor != null)
                  Positioned(
                    left:
                        widget.data.selectionPosition ==
                            DesignSystemCalendarDayCellSelectionPosition.start
                        ? halfCellSize
                        : 0,
                    right:
                        widget.data.selectionPosition ==
                            DesignSystemCalendarDayCellSelectionPosition.end
                        ? halfCellSize
                        : -halfCellSize,
                    child: ColoredBox(
                      color: styleSpec.connectionColor!,
                      child: SizedBox(height: cellSize),
                    ),
                  ),
                if (styleSpec.backgroundColor != null)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: styleSpec.backgroundColor,
                      borderRadius: BorderRadius.circular(halfCellSize),
                    ),
                    child: SizedBox(
                      width: cellSize,
                      height: cellSize,
                    ),
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

    return cell.withDisabledOpacity(
      enabled: enabled,
      disabledOpacity: tokens.colors.text.lowEmphasis.a,
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
