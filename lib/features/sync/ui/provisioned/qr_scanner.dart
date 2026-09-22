import 'dart:async';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/utils/platform.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zxing2/qrcode.dart';

/// Pixel layout of the camera plane a [QrFrame] was copied from.
enum QrFramePixelFormat {
  /// Four bytes per pixel, red first (Linux webcams).
  rgba(4),

  /// Four bytes per pixel, blue first (iOS, macOS, most desktop webcams).
  bgra(4),

  /// One byte per pixel: the Y plane of a YUV frame (Android CameraX).
  /// Luminance is all a QR decoder reads, so the chroma planes are never
  /// copied.
  luminance(1);

  const QrFramePixelFormat(this.bytesPerPixel);

  final int bytesPerPixel;
}

/// A sendable, decoder-ready copy of one camera frame.
@immutable
class QrFrame {
  const QrFrame({
    required this.bytes,
    required this.width,
    required this.height,
    required this.bytesPerRow,
    required this.pixelFormat,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final int bytesPerRow;
  final QrFramePixelFormat pixelFormat;
}

/// Decodes a QR payload from a packed camera frame.
///
/// Camera rows may contain alignment padding, so pixels are walked using
/// [QrFrame.bytesPerRow] rather than treating the plane as tightly packed.
/// A luminance plane goes through the same RGB source as grey pixels, which
/// ZXing maps straight back to the original value. Malformed frames and
/// frames without a QR code return null.
String? decodeQrFrame(QrFrame frame) {
  final bytesPerPixel = frame.pixelFormat.bytesPerPixel;
  if (frame.width <= 0 ||
      frame.height <= 0 ||
      frame.bytesPerRow < frame.width * bytesPerPixel) {
    return null;
  }

  // The last row may stop at its final pixel rather than at a full stride;
  // Android's Y plane is commonly delivered that way.
  final requiredBytes =
      (frame.height - 1) * frame.bytesPerRow + frame.width * bytesPerPixel;
  if (frame.bytes.length < requiredBytes) return null;

  final pixels = Int32List(frame.width * frame.height);
  for (var y = 0; y < frame.height; y++) {
    final rowStart = y * frame.bytesPerRow;
    for (var x = 0; x < frame.width; x++) {
      final offset = rowStart + x * bytesPerPixel;
      final (red, green, blue) = switch (frame.pixelFormat) {
        QrFramePixelFormat.rgba => (
          frame.bytes[offset],
          frame.bytes[offset + 1],
          frame.bytes[offset + 2],
        ),
        QrFramePixelFormat.bgra => (
          frame.bytes[offset + 2],
          frame.bytes[offset + 1],
          frame.bytes[offset],
        ),
        QrFramePixelFormat.luminance => (
          frame.bytes[offset],
          frame.bytes[offset],
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

typedef QrUnavailableBuilder = Widget Function(BuildContext context);
typedef QrDecoder = Future<String?> Function(QrFrame frame);

/// Camera preview and QR decoder for every platform that scans.
///
/// Built on the standard camera API — CameraX on Android, AVFoundation on
/// iOS, `camera_desktop` on macOS and Linux — and decoded off the UI isolate
/// with the pure-Dart ZXing port. No proprietary scanning SDK is involved,
/// which keeps the Android build free of Google ML Kit.
class QrScanner extends StatefulWidget {
  const QrScanner({
    required this.onDetect,
    required this.unavailableBuilder,
    super.key,
    this.decoder = _decodeOffUiIsolate,
  });

  final ValueChanged<String> onDetect;
  final QrUnavailableBuilder unavailableBuilder;
  final QrDecoder decoder;

  static Future<String?> _decodeOffUiIsolate(QrFrame frame) =>
      Isolate.run(() => decodeQrFrame(frame));

  @override
  State<QrScanner> createState() => _QrScannerState();
}

/// Narrow camera seam used by the widget tests; production uses
/// [_CameraQrCamera].
@visibleForTesting
abstract interface class QrCamera {
  Widget buildPreview();

  /// Starts the stream, consulting [shouldCaptureFrame] before copying a
  /// native camera buffer into a Dart-owned [QrFrame].
  Future<void> start({
    required bool Function() shouldCaptureFrame,
    required ValueChanged<QrFrame> onFrame,
    required ValueChanged<Object> onError,
  });

  Future<void> dispose();
}

typedef QrCameraFactory = Future<QrCamera> Function();

/// Test-only factory override for the native camera.
@visibleForTesting
QrCameraFactory? qrCameraFactoryOverride;

/// Creates the production camera adapter through a testable seam.
@visibleForTesting
Future<QrCamera> createQrCamera() => _CameraQrCamera.create();

class _QrScannerState extends State<QrScanner> with WidgetsBindingObserver {
  QrCamera? _camera;
  bool _unavailable = false;
  bool _decoding = false;
  bool _handlingCameraFailure = false;
  String? _lastDetectedPayload;
  int _framesToSkip = 0;

  /// Identifies the current camera session. Releasing the camera or leaving
  /// the tree bumps it, so an initialisation still in flight from an earlier
  /// session knows to discard what it opened.
  int _session = 0;

  /// Whether the camera was released for the app going to the background and
  /// must be reopened on resume.
  bool _suspended = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _openCamera();
  }

  void _openCamera() {
    unawaited(_initialize(++_session));
  }

  Future<void> _initialize(int session) async {
    try {
      final camera =
          await (qrCameraFactoryOverride?.call() ?? createQrCamera());
      if (!mounted || session != _session) {
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
      // A superseded session already released its camera; its failure (a
      // permission prompt answered while backgrounded, say) is not this
      // session's to report.
      if (session != _session) return;
      await _handleCameraFailure(error, stackTrace);
    }
  }

  /// Releases the camera while the app is away and reopens it on return.
  ///
  /// The camera plugin does not survive backgrounding on phones: the native
  /// session is stopped underneath a live controller, and a preview kept
  /// across it comes back frozen. Reopening on resume also retries a camera
  /// that had failed, which is how granting access in system settings takes
  /// effect without the user finding the retry button.
  ///
  /// Desktop windows go `inactive` whenever they lose focus, so only a hidden
  /// or paused desktop app releases its webcam.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_suspended) return;
      _suspended = false;
      setState(() => _unavailable = false);
      _openCamera();
      return;
    }
    if (state == AppLifecycleState.inactive && !isMobile) return;
    if (_suspended) return;
    _suspended = true;
    _session++;
    final camera = _camera;
    _camera = null;
    if (camera != null) unawaited(_disposeCamera(camera));
    setState(() {});
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
      await _disposeCamera(failedCamera);
    }
    DevLogger.error(
      name: 'QrScanner',
      message: 'Camera failed',
      error: error,
      stackTrace: stackTrace,
    );
    if (mounted) setState(() => _unavailable = true);
    _handlingCameraFailure = false;
  }

  Future<void> _disposeCamera(QrCamera camera) async {
    try {
      await camera.dispose();
    } on Exception catch (error, stackTrace) {
      DevLogger.error(
        name: 'QrScanner',
        message: 'Failed to dispose camera',
        error: error,
        stackTrace: stackTrace,
      );
    }
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

  void _onFrame(QrFrame frame) {
    unawaited(_decode(frame));
  }

  Future<void> _decode(QrFrame frame) async {
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
        name: 'QrScanner',
        message: 'QR decode failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _decoding = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session++;
    final camera = _camera;
    _camera = null;
    if (camera != null) unawaited(_disposeCamera(camera));
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

class _CameraQrCamera implements QrCamera {
  _CameraQrCamera(this._controller);

  final CameraController _controller;
  VoidCallback? _cameraErrorListener;

  static Future<_CameraQrCamera> create() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw CameraException('no_camera', 'No camera is available');
    }
    final controller = CameraController(
      _preferredCamera(cameras),
      // A phone's medium preset is 480×360 on iOS, too coarse for a dense
      // provisioning code held at arm's length; desktop webcams keep the
      // cheaper preset they have always scanned with.
      isMobile ? ResolutionPreset.high : ResolutionPreset.medium,
      enableAudio: false,
      // Android's image stream offers YUV rather than BGRA; its Y plane is
      // the luminance the decoder needs, without a colour conversion.
      imageFormatGroup: isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );
    try {
      await controller.initialize();
    } on Exception {
      await controller.dispose();
      rethrow;
    }
    return _CameraQrCamera(controller);
  }

  /// The code is on another device's screen, so a phone points its back
  /// camera at it. Desktops report external or front webcams only, where the
  /// first one listed is the one the system prefers.
  static CameraDescription _preferredCamera(List<CameraDescription> cameras) {
    for (final camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.back) return camera;
    }
    return cameras.first;
  }

  @override
  Widget buildPreview() => _CoverCameraPreview(controller: _controller);

  @override
  Future<void> start({
    required bool Function() shouldCaptureFrame,
    required ValueChanged<QrFrame> onFrame,
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
          QrFrame(
            // The native buffer is reused, so decoding must own a copy.
            bytes: Uint8List.fromList(plane.bytes),
            width: image.width,
            height: image.height,
            bytesPerRow: plane.bytesPerRow,
            pixelFormat: _pixelFormatOf(image.format),
          ),
        );
      });
    } on Exception {
      _controller.removeListener(cameraErrorListener);
      _cameraErrorListener = null;
      rethrow;
    }
  }

  /// YUV frames are decoded from their first plane, which is luminance;
  /// four-byte frames name their channel order in the raw format.
  static QrFramePixelFormat _pixelFormatOf(ImageFormat format) =>
      switch (format.group) {
        ImageFormatGroup.yuv420 ||
        ImageFormatGroup.nv21 => QrFramePixelFormat.luminance,
        _ =>
          format.raw == 'RGBA'
              ? QrFramePixelFormat.rgba
              : QrFramePixelFormat.bgra,
      };

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

/// Fills the viewfinder square with the camera image, cropping rather than
/// stretching it.
///
/// [CameraPreview] sizes itself with an [AspectRatio], which the square's
/// tight constraints override, squashing the picture. Laying it out at its
/// own ratio and scaling that to cover keeps the image undistorted.
class _CoverCameraPreview extends StatelessWidget {
  const _CoverCameraPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CameraValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        if (!value.isInitialized) return const SizedBox.shrink();
        return ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: previewAspectRatio(value),
              height: 1,
              child: CameraPreview(controller),
            ),
          ),
        );
      },
    );
  }
}

/// The width-to-height ratio [CameraPreview] draws at for [value].
///
/// The sensor reports a landscape ratio; a phone held upright shows it
/// rotated, so the ratio inverts. Mirrors `CameraPreview`'s own choice of
/// orientation, which it does not expose.
@visibleForTesting
double previewAspectRatio(CameraValue value) {
  final orientation =
      value.previewPauseOrientation ??
      value.lockedCaptureOrientation ??
      value.deviceOrientation;
  final landscape =
      orientation == DeviceOrientation.landscapeLeft ||
      orientation == DeviceOrientation.landscapeRight;
  return landscape ? value.aspectRatio : 1 / value.aspectRatio;
}
