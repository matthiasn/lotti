import 'package:flutter/services.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// A draggable divider that allows resizing adjacent panes.
///
/// Along [Axis.horizontal] (the default) it is a vertical line between
/// columns: a thin visual line with a wider hit target area, a horizontal
/// resize cursor on hover and while dragging, ←/→ from the keyboard. When
/// [enabled] is false it still paints its 1 px hairline — so the layout does
/// not shift when the parent disables it — but no drag gestures, hover
/// feedback or resize cursor are attached.
///
/// Along [Axis.vertical] it is a band between rows, dragged up and down —
/// a phone's split, worked by a finger: the band takes [hitTargetWidth] of
/// real height, so all of it can be grabbed, and shows a grip at its centre
/// where a column divider shows its line; ↑/↓ from the keyboard.
class ResizableDivider extends StatefulWidget {
  const ResizableDivider({
    required this.onDrag,
    this.axis = Axis.horizontal,
    this.hitTargetWidth = 8,
    this.enabled = true,
    this.reverse = false,
    this.currentValue,
    this.minValue,
    this.maxValue,
    super.key,
  }) : assert(
         (currentValue == null && minValue == null && maxValue == null) ||
             (currentValue != null && minValue != null && maxValue != null),
         'Provide all resize semantic values or none of them.',
       );

  /// Reserved row width, independent of the overflowing pointer hit target.
  static const layoutWidth = 3.0;

  /// Called with the change in pane width — or height, along
  /// [Axis.vertical]. Pointer and arrow-key deltas are reversed when [reverse]
  /// is true; semantic increase always grows the pane. Ignored while
  /// [enabled] is false.
  final ValueChanged<double> onDrag;

  /// The direction the divider drags: [Axis.horizontal] between columns,
  /// [Axis.vertical] between rows.
  final Axis axis;

  /// Whether the controlled pane sits to the right of (or below) the
  /// divider.
  final bool reverse;

  /// Width of the invisible hit target area for easier grabbing; along
  /// [Axis.vertical], the band's laid-out height.
  final double hitTargetWidth;

  /// Whether the divider accepts drag input and renders hover feedback.
  final bool enabled;

  /// The current width of the pane controlled by this divider, when known.
  ///
  /// Supplying all three semantic values lets assistive technology announce
  /// the current width and its valid range alongside the increase/decrease
  /// actions. Leave all three null when the parent has no bounded value.
  final double? currentValue;
  final double? minValue;
  final double? maxValue;

  @override
  State<ResizableDivider> createState() => _ResizableDividerState();
}

class _ResizableDividerState extends State<ResizableDivider> {
  bool _isDragging = false;
  bool _isHovering = false;
  bool _isFocused = false;

  @override
  void didUpdateWidget(ResizableDivider oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear any lingering hover/drag state when the divider is disabled so
    // a later re-enable does not resurrect a stale active line. The
    // `build()` `widget.enabled && …` guard masks the flags visually while
    // disabled, but without clearing them here the line would flip back to
    // the 3 px active width the moment the divider was re-enabled without
    // any new pointer activity.
    if (!widget.enabled && (_isDragging || _isHovering)) {
      setState(() {
        _isDragging = false;
        _isHovering = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isActive =
        widget.enabled && (_isDragging || _isHovering || _isFocused);
    final lineColor = isActive
        ? tokens.colors.interactive.enabled
        : tokens.colors.decorative.level01;
    final vertical = widget.axis == Axis.vertical;

    // The divider reserves a constant 3 px of width in the row layout so
    // adjacent panes never shift while the pointer crosses it. The visible
    // line inside animates between a thin 1 px hairline (idle) and the full
    // 3 px width (hover/drag), while a wider invisible [OverflowBox] on top
    // preserves the full hitTargetWidth drag/hover area.
    final visual = vertical
        // A band a finger can find: its whole height is the target, a grip
        // at its centre the sign that it moves.
        ? SizedBox(
            height: widget.hitTargetWidth,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: tokens.spacing.step8,
                height: tokens.spacing.step2,
                decoration: BoxDecoration(
                  color: isActive
                      ? tokens.colors.interactive.enabled
                      : tokens.colors.decorative.level02,
                  borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
                ),
              ),
            ),
          )
        : SizedBox(
            width: ResizableDivider.layoutWidth,
            child: OverflowBox(
              maxWidth: widget.hitTargetWidth,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: isActive ? ResizableDivider.layoutWidth : 1,
                  color: lineColor,
                ),
              ),
            ),
          );

    if (!widget.enabled) {
      return visual;
    }

    double keyboardStep() => HardwareKeyboard.instance.isShiftPressed
        ? tokens.spacing.step8
        : tokens.spacing.step4;

    final currentValue = widget.currentValue?.round();
    final minValue = widget.minValue?.round();
    final maxValue = widget.maxValue?.round();
    String? valueAfterChange(double delta) {
      if (currentValue == null || minValue == null || maxValue == null) {
        return null;
      }
      return (currentValue + delta)
          .clamp(minValue, maxValue)
          .round()
          .toString();
    }

    return Semantics(
      label: currentValue == null
          ? context.messages.keyboardResizeDividerLabel
          : context.messages.keyboardResizeDividerValue(
              currentValue,
              minValue!,
              maxValue!,
            ),
      slider: true,
      value: currentValue?.toString(),
      increasedValue: valueAfterChange(keyboardStep()),
      decreasedValue: valueAfterChange(-keyboardStep()),
      onIncrease: () => widget.onDrag(keyboardStep()),
      onDecrease: () => widget.onDrag(-keyboardStep()),
      child: Focus(
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
            return KeyEventResult.ignored;
          }
          final (less, more) = vertical
              ? (LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.arrowDown)
              : (LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowRight);
          if (event.logicalKey == less) {
            widget.onDrag(widget.reverse ? keyboardStep() : -keyboardStep());
            return KeyEventResult.handled;
          }
          if (event.logicalKey == more) {
            widget.onDrag(widget.reverse ? -keyboardStep() : keyboardStep());
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          cursor: vertical
              ? SystemMouseCursors.resizeRow
              : SystemMouseCursors.resizeColumn,
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          child: vertical
              ? GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: (_) =>
                      setState(() => _isDragging = true),
                  onVerticalDragUpdate: (details) => widget.onDrag(
                    details.delta.dy * (widget.reverse ? -1 : 1),
                  ),
                  onVerticalDragCancel: () =>
                      setState(() => _isDragging = false),
                  onVerticalDragEnd: (_) => setState(() => _isDragging = false),
                  child: visual,
                )
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) =>
                      setState(() => _isDragging = true),
                  onHorizontalDragUpdate: (details) => widget.onDrag(
                    details.delta.dx * (widget.reverse ? -1 : 1),
                  ),
                  onHorizontalDragCancel: () =>
                      setState(() => _isDragging = false),
                  onHorizontalDragEnd: (_) =>
                      setState(() => _isDragging = false),
                  child: visual,
                ),
        ),
      ),
    );
  }
}
