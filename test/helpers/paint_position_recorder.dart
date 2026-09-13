import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// Records the child's global top whenever it paints.
///
/// Scroll-stability widget tests use this to catch one-frame displacement that
/// a final-geometry assertion would miss.
class PaintPositionRecorder extends SingleChildRenderObjectWidget {
  const PaintPositionRecorder({
    required this.onPaint,
    required super.child,
    super.key,
  });

  final ValueChanged<double>? onPaint;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return PaintPositionRecorderRenderObject(onPaint);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    PaintPositionRecorderRenderObject renderObject,
  ) {
    renderObject.onPaint = onPaint;
  }
}

class PaintPositionRecorderRenderObject extends RenderProxyBox {
  PaintPositionRecorderRenderObject(this.onPaint);

  ValueChanged<double>? onPaint;

  @override
  void paint(PaintingContext context, Offset offset) {
    onPaint?.call(localToGlobal(Offset.zero).dy);
    super.paint(context, offset);
  }
}
