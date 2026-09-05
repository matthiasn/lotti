import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Repaints the scene subtree without rebuilding its hosted Flutter widgets.
/// The boundary owns its frame listener and also isolates scene painting from
/// HUD rebuilds. The scene view below it uses `autoTick: false`.
class PlazaRepaint extends SingleChildRenderObjectWidget {
  const PlazaRepaint({required this.frames, required super.child, super.key});

  final Listenable frames;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _SceneRepaint(frames);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _SceneRepaint renderObject,
  ) {
    renderObject.frames = frames;
  }
}

class _SceneRepaint extends RenderProxyBox {
  _SceneRepaint(this._frames);

  Listenable _frames;

  set frames(Listenable value) {
    if (identical(value, _frames)) return;
    if (attached) _frames.removeListener(markNeedsPaint);
    _frames = value;
    if (attached) _frames.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _frames.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _frames.removeListener(markNeedsPaint);
    super.detach();
  }
}
