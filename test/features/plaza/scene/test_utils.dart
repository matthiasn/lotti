import 'package:flutter_scene/scene.dart';

/// Counts requested captures and lets a test finish them without a GPU host.
class FakeWidgetTextureController extends WidgetTextureController {
  int requests = 0;
  int landed = 0;
  Duration duration = Duration.zero;

  @override
  void requestCapture() => requests++;

  @override
  int get captureCount => landed;

  @override
  Duration get lastCaptureDuration => duration;
}
