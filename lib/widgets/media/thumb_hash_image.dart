import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:lotti/utils/thumbhash.dart';

/// Rasterises a [ThumbHash] as an [ImageProvider].
///
/// Keyed on the hash, so the image cache holds one decoded frame per distinct
/// hash however many tiles show it and however often they rebuild: the DCT
/// runs once per hash per cache lifetime, not once per build. The frame is
/// tiny — [thumbHashRasterExtent] on its longest edge — and is meant to be
/// drawn scaled up with a [FilterQuality] above `none`, which is where the
/// blur comes from.
@immutable
class ThumbHashImage extends ImageProvider<ThumbHashImage> {
  const ThumbHashImage(this.thumbHash);

  final ThumbHash thumbHash;

  @override
  Future<ThumbHashImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<ThumbHashImage>(this);

  @override
  ImageStreamCompleter loadImage(
    ThumbHashImage key,
    ImageDecoderCallback decode,
  ) => ThumbHashStreamCompleter(
    _decodeFrame(key.thumbHash),
    debugLabel: key.toString(),
  );

  /// Hands the decoded RGBA raster to the engine as it is — no PNG encode,
  /// no [ImageDecoderCallback], the pixels are read straight from the
  /// buffer. The buffer and descriptor stay alive until the frame exists:
  /// the codec reads them when the frame is decoded, not when it is made.
  static Future<ImageInfo> _decodeFrame(ThumbHash thumbHash) async {
    final pixels = thumbHash.decode();
    final buffer = await ui.ImmutableBuffer.fromUint8List(pixels.rgba);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: pixels.width,
      height: pixels.height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    try {
      final frame = await codec.getNextFrame();
      return ImageInfo(image: frame.image, debugLabel: thumbHash.toString());
    } finally {
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
    }
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is ThumbHashImage && other.thumbHash == thumbHash;
  }

  @override
  int get hashCode => thumbHash.hashCode;

  @override
  String toString() =>
      '${objectRuntimeType(this, 'ThumbHashImage')}(${thumbHash.toBase64()})';
}

/// A one-frame stream completer that lets a late frame go instead of
/// throwing.
///
/// [OneFrameImageStreamCompleter] hands every resolved frame to [setImage],
/// and [setImage] throws once the stream is disposed — which it is as soon
/// as its last listener left and the cache dropped the entry: a list tile
/// scrolled away before the engine handed the raster back. Here such a frame
/// is disposed and the stream stays quiet; an error after disposal is not
/// reported either, because nobody is left to hear it.
@visibleForTesting
class ThumbHashStreamCompleter extends ImageStreamCompleter {
  ThumbHashStreamCompleter(
    Future<ImageInfo> frame, {
    String? debugLabel,
    InformationCollector? informationCollector,
  }) {
    this.debugLabel = debugLabel;
    frame.then<void>(
      (info) {
        if (_disposed) {
          info.dispose();
          return;
        }
        setImage(info);
      },
      onError: (Object error, StackTrace stack) {
        if (_disposed) return;
        reportError(
          context: ErrorDescription('rasterising a ThumbHash'),
          exception: error,
          stack: stack,
          informationCollector: informationCollector,
          silent: true,
        );
      },
    );
  }

  bool _disposed = false;

  @override
  void onDisposed() {
    _disposed = true;
    super.onDisposed();
  }
}
