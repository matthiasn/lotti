import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// An [ImageProvider] whose load fails at once, for exercising an image's
/// `errorBuilder` fallback.
///
/// The key resolves synchronously and the failure is a plain rejected future,
/// so no engine decode is involved and the error reaches the widget inside
/// `testWidgets`' fake async zone (see test/README.md, "Image decoding never
/// completes inside `testWidgets`").
class BrokenImageProvider extends ImageProvider<BrokenImageProvider> {
  const BrokenImageProvider();

  @override
  Future<BrokenImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<BrokenImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    BrokenImageProvider key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(Future<ImageInfo>.error('broken'));
}
