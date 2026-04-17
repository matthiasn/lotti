import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// A draggable vertical divider that allows resizing adjacent panes.
///
/// Displays a thin visual line with a wider hit target area. Shows a
/// horizontal resize cursor on hover and while dragging.
class ResizableDivider extends StatefulWidget {
  const ResizableDivider({
    required this.onDrag,
    this.hitTargetWidth = 8,
    super.key,
  });

  /// Called with the horizontal drag delta when the user drags the divider.
  final ValueChanged<double> onDrag;

  /// Width of the invisible hit target area for easier grabbing.
  final double hitTargetWidth;

  @override
  State<ResizableDivider> createState() => _ResizableDividerState();
}

class _ResizableDividerState extends State<ResizableDivider> {
  bool _isDragging = false;
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isActive = _isDragging || _isHovering;
    final lineColor = isActive
        ? tokens.colors.interactive.enabled
        : tokens.colors.decorative.level01;

    // The divider occupies a 1 px flush line in the row layout so adjacent
    // panes sit edge-to-edge against it (matching the Figma reference —
    // no extra gap between, e.g., the task list's vertical divider and a
    // task cover art image). A wider invisible [OverflowBox] on top
    // preserves the full hitTargetWidth drag/hover area.
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
        child: SizedBox(
          width: isActive ? 3 : 1,
          child: OverflowBox(
            maxWidth: widget.hitTargetWidth,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: isActive ? 3 : 1,
              color: lineColor,
            ),
          ),
        ),
      ),
    );
  }
}
