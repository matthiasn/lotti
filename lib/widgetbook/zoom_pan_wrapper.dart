import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keyboard zoom (+/-/0) and pinch/drag panning wrapper.
///
/// Wraps its child in an [InteractiveViewer] with keyboard shortcuts:
/// - **Cmd/Ctrl +**: zoom in
/// - **Cmd/Ctrl -**: zoom out
/// - **Cmd/Ctrl 0**: reset to 1×
/// - **Pinch / scroll wheel**: zoom
/// - **Drag**: pan when zoomed in
class ZoomPanWrapper extends StatefulWidget {
  const ZoomPanWrapper({required this.child, super.key});
  final Widget? child;

  @override
  State<ZoomPanWrapper> createState() => ZoomPanWrapperState();
}

@visibleForTesting
class ZoomPanWrapperState extends State<ZoomPanWrapper> {
  final controller = TransformationController();

  static const minScale = 0.25;
  static const maxScale = 4.0;
  static const zoomStep = 0.15;

  double get currentScale => controller.value.getMaxScaleOnAxis();

  void applyScale(double scale) {
    final clamped = scale.clamp(minScale, maxScale);
    controller.value = Matrix4.diagonal3Values(clamped, clamped, 1);
  }

  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    // Accept both Command (macOS) and Control (Windows/Linux)
    final isModifierPressed =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    if (!isModifierPressed) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.equal ||
        event.logicalKey == LogicalKeyboardKey.add) {
      applyScale(currentScale + zoomStep);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.minus) {
      applyScale(currentScale - zoomStep);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.digit0) {
      applyScale(1);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: handleKeyEvent,
      child: InteractiveViewer(
        transformationController: controller,
        minScale: minScale,
        maxScale: maxScale,
        child: widget.child ?? const SizedBox.shrink(),
      ),
    );
  }
}
