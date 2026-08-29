import 'dart:async';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:zxing2/qrcode.dart';

/// Channel order used by a desktop camera's packed four-byte image plane.
enum DesktopQrChannelOrder { rgba, bgra }

/// A sendable, decoder-ready copy of one desktop camera frame.
@immutable
class DesktopQrFrame {
  const DesktopQrFrame({
    required this.bytes,
    required this.width,
    required this.height,
    required this.bytesPerRow,
    required this.channelOrder,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final int bytesPerRow;
  final DesktopQrChannelOrder channelOrder;
}

/// Decodes a QR payload from a packed RGBA/BGRA desktop camera frame.
///
/// Camera rows may contain alignment padding, so pixels are walked using
/// [DesktopQrFrame.bytesPerRow] rather than treating the plane as tightly
/// packed. Malformed frames and frames without a QR code return null.
String? decodeDesktopQrFrame(DesktopQrFrame frame) {
  const bytesPerPixel = 4;
  if (frame.width <= 0 ||
      frame.height <= 0 ||
      frame.bytesPerRow < frame.width * bytesPerPixel) {
    return null;
  }

  final requiredBytes =
      (frame.height - 1) * frame.bytesPerRow + frame.width * bytesPerPixel;
  if (frame.bytes.length < requiredBytes) return null;

  final pixels = Int32List(frame.width * frame.height);
  for (var y = 0; y < frame.height; y++) {
    final rowStart = y * frame.bytesPerRow;
    for (var x = 0; x < frame.width; x++) {
      final offset = rowStart + x * bytesPerPixel;
      final (red, green, blue) = switch (frame.channelOrder) {
        DesktopQrChannelOrder.rgba => (
          frame.bytes[offset],
          frame.bytes[offset + 1],
          frame.bytes[offset + 2],
        ),
        DesktopQrChannelOrder.bgra => (
          frame.bytes[offset + 2],
          frame.bytes[offset + 1],
          frame.bytes[offset],
        ),
      };
      pixels[y * frame.width + x] = (0xFF000000 | red << 16 | green << 8 | blue)
          .toSigned(32);
    }
  }

  try {
    final source = RGBLuminanceSource(frame.width, frame.height, pixels);
    final bitmap = BinaryBitmap(HybridBinarizer(source));
    return QRCodeReader().decode(bitmap).text;
  } on ReaderException {
    return null;
  }
}

typedef DesktopQrUnavailableBuilder = Widget Function(BuildContext context);
typedef DesktopQrDecoder = Future<String?> Function(DesktopQrFrame frame);

/// Linux webcam preview and QR decoder.
///
/// `mobile_scanner` covers Android, iOS, and macOS but has no Linux plugin.
/// This widget uses the standard camera API, backed by `camera_desktop`, then
/// decodes copied RGBA/BGRA frames off the UI isolate with ZXing.
class DesktopQrScanner extends StatefulWidget {
  const DesktopQrScanner({
    required this.onDetect,
    required this.unavailableBuilder,
    super.key,
    this.decoder = _decodeOffUiIsolate,
  });

  final ValueChanged<String> onDetect;
  final DesktopQrUnavailableBuilder unavailableBuilder;
  final DesktopQrDecoder decoder;

  static Future<String?> _decodeOffUiIsolate(DesktopQrFrame frame) =>
      Isolate.run(() => decodeDesktopQrFrame(frame));

  @override
  State<DesktopQrScanner> createState() => _DesktopQrScannerState();
}

/// Narrow camera seam used by the widget tests; production uses
/// [_CameraDesktopQrCamera].
@visibleForTesting
abstract interface class DesktopQrCamera {
  Widget buildPreview();

  /// Starts the stream, consulting [shouldCaptureFrame] before copying a
  /// native camera buffer into a Dart-owned [DesktopQrFrame].
  Future<void> start({
    required bool Function() shouldCaptureFrame,
    required ValueChanged<DesktopQrFrame> onFrame,
    required ValueChanged<Object> onError,
  });

  Future<void> dispose();
}

typedef DesktopQrCameraFactory = Future<DesktopQrCamera> Function();

/// Test-only factory override for a native Linux webcam.
@visibleForTesting
DesktopQrCameraFactory? desktopQrCameraFactoryOverride;

/// Creates the production Linux camera adapter through a testable seam.
@visibleForTesting
Future<DesktopQrCamera> createDesktopQrCamera() =>
    _CameraDesktopQrCamera.create();

class _DesktopQrScannerState extends State<DesktopQrScanner> {
  DesktopQrCamera? _camera;
  bool _unavailable = false;
  bool _decoding = false;
  bool _handlingCameraFailure = false;
  String? _lastDetectedPayload;
  int _framesToSkip = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      final camera =
          await (desktopQrCameraFactoryOverride?.call() ??
              createDesktopQrCamera());
      if (!mounted) {
        await camera.dispose();
        return;
      }
      setState(() => _camera = camera);
      await camera.start(
        shouldCaptureFrame: _shouldCaptureFrame,
        onFrame: _onFrame,
        onError: _onCameraError,
      );
    } on Exception catch (error, stackTrace) {
      await _handleCameraFailure(error, stackTrace);
    }
  }

  void _onCameraError(Object error) {
    unawaited(_handleCameraFailure(error, StackTrace.current));
  }

  Future<void> _handleCameraFailure(Object error, StackTrace stackTrace) async {
    if (_handlingCameraFailure || _unavailable) return;
    _handlingCameraFailure = true;
    final failedCamera = _camera;
    _camera = null;
    if (failedCamera != null) {
      try {
        await failedCamera.dispose();
      } on Exception catch (disposeError, disposeStackTrace) {
        DevLogger.error(
          name: 'DesktopQrScanner',
          message: 'Failed to dispose desktop camera after camera error',
          error: disposeError,
          stackTrace: disposeStackTrace,
        );
      }
    }
    DevLogger.error(
      name: 'DesktopQrScanner',
      message: 'Desktop camera failed',
      error: error,
      stackTrace: stackTrace,
    );
    if (mounted) setState(() => _unavailable = true);
    _handlingCameraFailure = false;
  }

  bool _shouldCaptureFrame() {
    if (_decoding) return false;
    if (_framesToSkip > 0) {
      _framesToSkip--;
      return false;
    }
    // Decode roughly every fifth delivered frame. This is deterministic,
    // needs no Timer, and keeps backpressure independent of decoder latency.
    _framesToSkip = 4;
    _decoding = true;
    return true;
  }

  void _onFrame(DesktopQrFrame frame) {
    unawaited(_decode(frame));
  }

  Future<void> _decode(DesktopQrFrame frame) async {
    try {
      final payload = await widget.decoder(frame);
      if (!mounted ||
          payload == null ||
          payload.isEmpty ||
          payload == _lastDetectedPayload) {
        return;
      }
      _lastDetectedPayload = payload;
      widget.onDetect(payload);
    } on Exception catch (error, stackTrace) {
      DevLogger.error(
        name: 'DesktopQrScanner',
        message: 'Desktop QR decode failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _decoding = false;
    }
  }

  @override
  void dispose() {
    final camera = _camera;
    _camera = null;
    if (camera != null) unawaited(camera.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_unavailable) return widget.unavailableBuilder(context);
    final camera = _camera;
    if (camera == null) {
      return const Center(child: DesignSystemSpinner());
    }
    return camera.buildPreview();
  }
}

class _CameraDesktopQrCamera implements DesktopQrCamera {
  _CameraDesktopQrCamera(this._controller);

  final CameraController _controller;
  VoidCallback? _cameraErrorListener;

  static Future<_CameraDesktopQrCamera> create() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw CameraException('no_camera', 'No webcam is available');
    }
    final controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.bgra8888,
    );
    try {
      await controller.initialize();
    } on Exception {
      await controller.dispose();
      rethrow;
    }
    return _CameraDesktopQrCamera(controller);
  }

  @override
  Widget buildPreview() => CameraPreview(_controller);

  @override
  Future<void> start({
    required bool Function() shouldCaptureFrame,
    required ValueChanged<DesktopQrFrame> onFrame,
    required ValueChanged<Object> onError,
  }) async {
    void cameraErrorListener() {
      final description = _controller.value.errorDescription;
      if (description != null) {
        onError(CameraException('camera_error', description));
      }
    }

    _cameraErrorListener = cameraErrorListener;
    _controller.addListener(cameraErrorListener);
    try {
      await _controller.startImageStream((image) {
        if (image.planes.isEmpty || !shouldCaptureFrame()) return;
        final plane = image.planes.first;
        onFrame(
          DesktopQrFrame(
            // The native buffer is reused, so decoding must own a copy.
            bytes: Uint8List.fromList(plane.bytes),
            width: image.width,
            height: image.height,
            bytesPerRow: plane.bytesPerRow,
            channelOrder: image.format.raw == 'RGBA'
                ? DesktopQrChannelOrder.rgba
                : DesktopQrChannelOrder.bgra,
          ),
        );
      });
    } on Exception {
      _controller.removeListener(cameraErrorListener);
      _cameraErrorListener = null;
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    final cameraErrorListener = _cameraErrorListener;
    if (cameraErrorListener != null) {
      _controller.removeListener(cameraErrorListener);
      _cameraErrorListener = null;
    }
    if (_controller.value.isStreamingImages) {
      try {
        await _controller.stopImageStream();
      } on CameraException {
        // Disposal must still release the controller after a native stream
        // already stopped itself.
      }
    }
    await _controller.dispose();
  }
}
