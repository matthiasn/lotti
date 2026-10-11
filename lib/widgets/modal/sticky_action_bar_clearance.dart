import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// Room under a modal page's content for the sticky action bar that floats
/// over it.
///
/// Wolt lays a page's sticky action bar in a `Stack` over the scrolling
/// content and reserves no space for it, so the content's last lines can
/// only ever scroll as far as behind the bar. A guessed constant drifts from
/// the bar it should clear — its padding, a larger button, a bar that stacks
/// at large text — so this measures the bar as laid out instead: wrap the
/// bar in [bar] and the content in [content], and the content ends with
/// exactly the bar's height of room.
///
/// One per modal, made where the modal is shown. Not disposed: both widgets
/// keep building through the exit animation, after the route's future has
/// completed, and a notifier with no listeners left holds nothing.
class StickyActionBarClearance {
  final ValueNotifier<double> _height = ValueNotifier(0);

  /// The bar's height as last laid out; zero before its first layout.
  double get height => _height.value;

  /// [child], the sticky action bar, measured on every layout.
  Widget bar(Widget child) => _HeightReporter(
    onHeight: (height) => _height.value = height,
    child: child,
  );

  /// [child], the page content, followed by the bar's height of room.
  Widget content(Widget child) => ValueListenableBuilder<double>(
    valueListenable: _height,
    builder: (context, height, child) => Padding(
      padding: EdgeInsets.only(bottom: height),
      child: child,
    ),
    child: child,
  );
}

/// Reports its child's laid-out height to [onHeight] whenever it changes,
/// after the frame — a listener may rebuild, which layout cannot.
class _HeightReporter extends SingleChildRenderObjectWidget {
  const _HeightReporter({required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHeightReporter(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderHeightReporter renderObject,
  ) => renderObject.onHeight = onHeight;
}

class _RenderHeightReporter extends RenderProxyBox {
  _RenderHeightReporter(this.onHeight);

  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    if (size.height == _reported) return;
    _reported = size.height;
    // The latest height, whichever layout queued it: two in one frame
    // report the last one twice, which the notifier takes as one.
    WidgetsBinding.instance.addPostFrameCallback((_) => onHeight(_reported!));
  }
}
