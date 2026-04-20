import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// A draggable vertical divider that allows resizing adjacent panes.
///
/// Displays a thin visual line with a wider hit target area. Shows a
/// horizontal resize cursor on hover and while dragging. When [enabled] is
/// false the divider still paints its 1 px hairline — so the layout does not
/// shift when the parent disables it — but no drag gestures, hover feedback
/// or resize cursor are attached.
class ResizableDivider extends StatefulWidget {
  const ResizableDivider({
    required this.onDrag,
    this.hitTargetWidth = 8,
    this.enabled = true,
    super.key,
  });

  /// Called with the horizontal drag delta when the user drags the divider.
  /// Ignored while [enabled] is false.
  final ValueChanged<double> onDrag;

  /// Width of the invisible hit target area for easier grabbing.
  final double hitTargetWidth;

  /// Whether the divider accepts drag input and renders hover feedback.
  final bool enabled;

  @override
  State<ResizableDivider> createState() => _ResizableDividerState();
}

class _ResizableDividerState extends State<ResizableDivider> {
  bool _isDragging = false;
  bool _isHovering = false;

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
    final isActive = widget.enabled && (_isDragging || _isHovering);
    final lineColor = isActive
        ? tokens.colors.interactive.enabled
        : tokens.colors.decorative.level01;

    // The divider reserves a constant 3 px of width in the row layout so
    // adjacent panes never shift while the pointer crosses it. The visible
    // line inside animates between a thin 1 px hairline (idle) and the full
    // 3 px width (hover/drag), while a wider invisible [OverflowBox] on top
    // preserves the full hitTargetWidth drag/hover area.
    final visual = SizedBox(
      width: 3,
      child: OverflowBox(
        maxWidth: widget.hitTargetWidth,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: isActive ? 3 : 1,
            color: lineColor,
          ),
        ),
      ),
    );

    if (!widget.enabled) {
      return visual;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => setState(() => _isDragging = true),
        onHorizontalDragUpdate: (details) => widget.onDrag(details.delta.dx),
        onHorizontalDragCancel: () => setState(() => _isDragging = false),
        onHorizontalDragEnd: (_) => setState(() => _isDragging = false),
        child: visual,
      ),
    );
  }
}
