import 'dart:async';

import 'package:camera/camera.dart' show CameraPreview;
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/ui/provisioned/desktop_qr_scanner.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:zxing2/qrcode.dart';

import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CameraPlatform originalCameraPlatform;

  setUp(() {
    originalCameraPlatform = CameraPlatform.instance;
    DevLogger.suppressOutput = true;
    DevLogger.clear();
  });

  tearDown(() {
    CameraPlatform.instance = originalCameraPlatform;
    desktopQrCameraFactoryOverride = null;
    DevLogger.suppressOutput = false;
    DevLogger.clear();
  });

  group('decodeDesktopQrFrame', () {
    for (final order in DesktopQrChannelOrder.values) {
      test('decodes ${order.name} data with padded rows', () {
        const payload = 'lotti-sync-handover-v2';
        final frame = _qrFrame(payload, order: order, rowPadding: 12);

        expect(decodeDesktopQrFrame(frame), payload);
      });
    }

    test('returns null for a malformed frame', () {
      expect(
        decodeDesktopQrFrame(
          DesktopQrFrame(
            bytes: Uint8List(3),
            width: 20,
            height: 20,
            bytesPerRow: 80,
            channelOrder: DesktopQrChannelOrder.rgba,
          ),
        ),
        isNull,
      );
    });

    test('returns null when the frame has no QR code', () {
      expect(
        decodeDesktopQrFrame(
          DesktopQrFrame(
            bytes: Uint8List.fromList(List.filled(40 * 40 * 4, 0xFF)),
            width: 40,
            height: 40,
            bytesPerRow: 40 * 4,
            channelOrder: DesktopQrChannelOrder.rgba,
          ),
        ),
        isNull,
      );
    });

    test('decodes outside the UI isolate', () async {
      const payload = 'decoded-off-ui-isolate';
      final frame = _qrFrame(
        payload,
        order: DesktopQrChannelOrder.rgba,
        rowPadding: 4,
      );
      final scanner = DesktopQrScanner(
        onDetect: (_) {},
        unavailableBuilder: (_) => const SizedBox.shrink(),
      );

      expect(await scanner.decoder(frame), payload);
    });
  });

  group('DesktopQrScanner', () {
    testWidgets(
      'copies one frame in five and continues after a different payload',
      (tester) async {
        final camera = _FakeDesktopQrCamera();
        desktopQrCameraFactoryOverride = () async => camera;
        final detected = <String>[];
        var decodeCount = 0;

        await tester.pumpWidget(
          makeTestableWidget2(
            DesktopQrScanner(
              onDetect: detected.add,
              unavailableBuilder: (_) => const Text('Camera unavailable'),
              decoder: (_) async {
                decodeCount++;
                return decodeCount == 1 ? 'not-a-bundle' : 'pairing-code';
              },
            ),
          ),
        );
        await tester.pump();

        expect(find.byKey(const Key('desktop_camera_preview')), findsOneWidget);
        expect(camera.started, isTrue);

        camera.emit(_blankFrame());
        await tester.pump();
        for (var i = 0; i < 4; i++) {
          camera.emit(_blankFrame());
        }
        camera.emit(_blankFrame());
        await tester.pump();
        for (var i = 0; i < 4; i++) {
          camera.emit(_blankFrame());
        }
        camera.emit(_blankFrame());
        await tester.pump();

        expect(detected, ['not-a-bundle', 'pairing-code']);
        expect(camera.emittedFrames, 11);
        expect(camera.capturedFrames, 3);
        expect(decodeCount, 3);
      },
    );

    testWidgets('shows the fallback when camera initialization fails', (
      tester,
    ) async {
      desktopQrCameraFactoryOverride = () async =>
          throw const FormatException('no camera');

      await tester.pumpWidget(
        makeTestableWidget2(
          DesktopQrScanner(
            onDetect: (_) {},
            unavailableBuilder: (_) => const Text('Camera unavailable'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Camera unavailable'), findsOneWidget);
    });

    testWidgets('disposes the camera before reporting stream start failure', (
      tester,
    ) async {
      final camera = _FakeDesktopQrCamera(
        startError: const FormatException('stream unavailable'),
      );
      desktopQrCameraFactoryOverride = () async => camera;

      await tester.pumpWidget(
        makeTestableWidget2(
          DesktopQrScanner(
            onDetect: (_) {},
            unavailableBuilder: (_) => const Text('Camera unavailable'),
          ),
        ),
      );
      await tester.pump();

      expect(camera.started, isTrue);
      expect(camera.disposed, isTrue);
      expect(find.text('Camera unavailable'), findsOneWidget);
      expect(find.byKey(const Key('desktop_camera_preview')), findsNothing);
    });

    testWidgets('keeps fallback usable when failed camera disposal throws', (
      tester,
    ) async {
      final camera = _FakeDesktopQrCamera(
        startError: const FormatException('stream unavailable'),
        disposeError: const FormatException('dispose failed'),
      );
      desktopQrCameraFactoryOverride = () async => camera;

      await tester.pumpWidget(
        makeTestableWidget2(
          DesktopQrScanner(
            onDetect: (_) {},
            unavailableBuilder: (_) => const Text('Camera unavailable'),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(camera.disposed, isTrue);
      expect(find.text('Camera unavailable'), findsOneWidget);
    });

    testWidgets('disposes a camera created after the scanner is removed', (
      tester,
    ) async {
      final cameraCompleter = Completer<DesktopQrCamera>();
      final camera = _FakeDesktopQrCamera();
      desktopQrCameraFactoryOverride = () => cameraCompleter.future;

      await tester.pumpWidget(
        makeTestableWidget2(
          DesktopQrScanner(
            onDetect: (_) {},
            unavailableBuilder: (_) => const Text('Camera unavailable'),
          ),
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());

      cameraCompleter.complete(camera);
      await tester.pump();

      expect(camera.started, isFalse);
      expect(camera.disposed, isTrue);
    });

    testWidgets('recovers after the decoder throws', (tester) async {
      final camera = _FakeDesktopQrCamera();
      desktopQrCameraFactoryOverride = () async => camera;
      final detected = <String>[];
      var decodeCount = 0;

      await tester.pumpWidget(
        makeTestableWidget2(
          DesktopQrScanner(
            onDetect: detected.add,
            unavailableBuilder: (_) => const Text('Camera unavailable'),
            decoder: (_) async {
              decodeCount++;
              if (decodeCount == 1) throw const FormatException('bad frame');
              return 'recovered-payload';
            },
          ),
        ),
      );
      await tester.pump();

      camera.emit(_blankFrame());
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        camera.emit(_blankFrame());
      }
      camera.emit(_blankFrame());
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(detected, ['recovered-payload']);
      expect(decodeCount, 2);
    });

    testWidgets('disposes the camera when removed', (tester) async {
      final camera = _FakeDesktopQrCamera();
      desktopQrCameraFactoryOverride = () async => camera;

      await tester.pumpWidget(
        makeTestableWidget2(
          DesktopQrScanner(
            onDetect: (_) {},
            unavailableBuilder: (_) => const Text('Camera unavailable'),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(camera.disposed, isTrue);
    });

    testWidgets('contains camera disposal failures when removed', (
      tester,
    ) async {
      final camera = _FakeDesktopQrCamera(
        disposeError: const FormatException('release failed'),
      );
      desktopQrCameraFactoryOverride = () async => camera;

      await tester.pumpWidget(
        makeTestableWidget2(
          DesktopQrScanner(
            onDetect: (_) {},
            unavailableBuilder: (_) => const Text('Camera unavailable'),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(camera.disposed, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('production camera adapter', () {
    testWidgets('shows the fallback when no webcam exists', (tester) async {
      final platform = _FakeCameraPlatform(cameras: const []);
      CameraPlatform.instance = platform;

      await tester.pumpWidget(
        makeTestableWidget2(
          DesktopQrScanner(
            onDetect: (_) {},
            unavailableBuilder: (_) => const Text('No webcam'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No webcam'), findsOneWidget);
      expect(platform.createCalls, 0);
    });

    test('disposes the controller when initialization fails', () async {
      final platform = _FakeCameraPlatform(throwOnInitialize: true);
      CameraPlatform.instance = platform;

      await expectLater(
        createDesktopQrCamera(),
        throwsA(
          isA<CameraException>().having(
            (error) => error.code,
            'code',
            'initialization_failed',
          ),
        ),
      );

      expect(platform.disposedCameraIds, [7]);
      expect(platform.requestedImageFormat, ImageFormatGroup.bgra8888);
    });

    test('copies admitted RGBA and BGRA frames before decoding', () async {
      final platform = _FakeCameraPlatform();
      CameraPlatform.instance = platform;
      final decodedFrames = <DesktopQrFrame>[];
      var admitFrame = false;

      final camera = await createDesktopQrCamera();
      expect(camera.buildPreview(), isA<CameraPreview>());
      await camera.start(
        shouldCaptureFrame: () => admitFrame,
        onFrame: decodedFrames.add,
        onError: (_) {},
      );

      expect(platform.streaming, isTrue);
      expect(platform.requestedResolution, ResolutionPreset.medium);
      expect(platform.requestedAudio, isFalse);

      platform
        ..emit(_cameraImageWithoutPlanes())
        ..emit(_cameraImage(Uint8List(4), rawFormat: 'RGBA'));
      expect(decodedFrames, isEmpty);

      admitFrame = true;
      final rgbaBytes = Uint8List.fromList([1, 2, 3, 4]);
      platform.emit(_cameraImage(rgbaBytes, rawFormat: 'RGBA'));
      rgbaBytes[0] = 99;
      final bgraBytes = Uint8List.fromList([5, 6, 7, 8]);
      platform.emit(_cameraImage(bgraBytes, rawFormat: 'BGRA'));
      bgraBytes[0] = 88;

      expect(decodedFrames, hasLength(2));
      expect(decodedFrames.first.channelOrder, DesktopQrChannelOrder.rgba);
      expect(decodedFrames.first.bytes, [1, 2, 3, 4]);
      expect(decodedFrames.last.channelOrder, DesktopQrChannelOrder.bgra);
      expect(decodedFrames.last.bytes, [5, 6, 7, 8]);

      await camera.dispose();

      expect(platform.streamCancelled, isTrue);
      expect(platform.disposedCameraIds, [7]);
    });

    test('still disposes when the native stream already stopped', () async {
      final platform = _FakeCameraPlatform(throwOnStreamCancel: true);
      CameraPlatform.instance = platform;

      final camera = await createDesktopQrCamera();
      await camera.start(
        shouldCaptureFrame: () => false,
        onFrame: (_) {},
        onError: (_) {},
      );
      expect(platform.streaming, isTrue);

      await expectLater(camera.dispose(), completes);

      expect(platform.streamCancelled, isTrue);
      expect(platform.disposedCameraIds, [7]);
    });

    test('removes its error listener when stream startup fails', () async {
      final platform = _FakeCameraPlatform(throwOnStreamListen: true);
      CameraPlatform.instance = platform;
      final errors = <Object>[];

      final camera = await createDesktopQrCamera();
      await expectLater(
        camera.start(
          shouldCaptureFrame: () => false,
          onFrame: (_) {},
          onError: errors.add,
        ),
        throwsA(
          isA<CameraException>().having(
            (error) => error.code,
            'code',
            'stream_start_failed',
          ),
        ),
      );

      platform.emitError('late camera error');
      await Future<void>.value();
      expect(errors, isEmpty);

      await camera.dispose();
      expect(platform.disposedCameraIds, [7]);
    });

    testWidgets('shows the fallback after a running camera reports an error', (
      tester,
    ) async {
      final platform = _FakeCameraPlatform();
      CameraPlatform.instance = platform;

      await tester.pumpWidget(
        makeTestableWidget2(
          DesktopQrScanner(
            onDetect: (_) {},
            unavailableBuilder: (_) => const Text('Camera disconnected'),
          ),
        ),
      );
      await tester.pump();

      expect(platform.streaming, isTrue);
      expect(find.byType(CameraPreview), findsOneWidget);

      platform.emitError('camera disconnected');
      await tester.pump();

      expect(platform.streamCancelled, isTrue);
      expect(platform.disposedCameraIds, [7]);
      expect(find.text('Camera disconnected'), findsOneWidget);
      expect(find.byType(CameraPreview), findsNothing);
    });
  });
}

DesktopQrFrame _blankFrame() => DesktopQrFrame(
  bytes: Uint8List.fromList(List.filled(4, 0xFF)),
  width: 1,
  height: 1,
  bytesPerRow: 4,
  channelOrder: DesktopQrChannelOrder.rgba,
);

CameraImageData _cameraImage(
  Uint8List bytes, {
  required Object rawFormat,
}) => CameraImageData(
  format: CameraImageFormat(ImageFormatGroup.bgra8888, raw: rawFormat),
  planes: [
    CameraImagePlane(
      bytes: bytes,
      bytesPerRow: 4,
      bytesPerPixel: 4,
      height: 1,
      width: 1,
    ),
  ],
  height: 1,
  width: 1,
);

CameraImageData _cameraImageWithoutPlanes() => const CameraImageData(
  format: CameraImageFormat(ImageFormatGroup.bgra8888, raw: 'BGRA'),
  planes: [],
  height: 1,
  width: 1,
);

DesktopQrFrame _qrFrame(
  String payload, {
  required DesktopQrChannelOrder order,
  required int rowPadding,
}) {
  const quietZone = 4;
  const scale = 7;
  final matrix = Encoder.encode(payload, ErrorCorrectionLevel.h).matrix!;
  final width = (matrix.width + quietZone * 2) * scale;
  final height = (matrix.height + quietZone * 2) * scale;
  final bytesPerRow = width * 4 + rowPadding;
  final bytes = Uint8List(bytesPerRow * height)
    ..fillRange(0, bytesPerRow * height, 0xFF);

  for (var moduleY = 0; moduleY < matrix.height; moduleY++) {
    for (var moduleX = 0; moduleX < matrix.width; moduleX++) {
      if (matrix.get(moduleX, moduleY) != 1) continue;
      final startX = (moduleX + quietZone) * scale;
      final startY = (moduleY + quietZone) * scale;
      for (var y = startY; y < startY + scale; y++) {
        for (var x = startX; x < startX + scale; x++) {
          final offset = y * bytesPerRow + x * 4;
          bytes[offset] = 0;
          bytes[offset + 1] = 0;
          bytes[offset + 2] = 0;
          bytes[offset + 3] = 0xFF;
        }
      }
    }
  }

  return DesktopQrFrame(
    bytes: bytes,
    width: width,
    height: height,
    bytesPerRow: bytesPerRow,
    channelOrder: order,
  );
}

class _FakeDesktopQrCamera implements DesktopQrCamera {
  _FakeDesktopQrCamera({this.startError, this.disposeError});

  final Exception? startError;
  final Exception? disposeError;
  bool Function()? _shouldCaptureFrame;
  ValueChanged<DesktopQrFrame>? _onFrame;
  bool started = false;
  bool disposed = false;
  int emittedFrames = 0;
  int capturedFrames = 0;

  @override
  Widget buildPreview() => const ColoredBox(
    key: Key('desktop_camera_preview'),
    color: Colors.green,
  );

  void emit(DesktopQrFrame frame) {
    emittedFrames++;
    if (!(_shouldCaptureFrame?.call() ?? false)) return;
    capturedFrames++;
    _onFrame?.call(frame);
  }

  @override
  Future<void> start({
    required bool Function() shouldCaptureFrame,
    required ValueChanged<DesktopQrFrame> onFrame,
    required ValueChanged<Object> onError,
  }) async {
    started = true;
    final error = startError;
    if (error != null) throw error;
    _shouldCaptureFrame = shouldCaptureFrame;
    _onFrame = onFrame;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    _shouldCaptureFrame = null;
    _onFrame = null;
    final error = disposeError;
    if (error != null) throw error;
  }
}

class _FakeCameraPlatform extends CameraPlatform {
  _FakeCameraPlatform({
    this.cameras = const [
      CameraDescription(
        name: 'webcam',
        lensDirection: CameraLensDirection.external,
        sensorOrientation: 0,
      ),
    ],
    this.throwOnInitialize = false,
    this.throwOnStreamListen = false,
    this.throwOnStreamCancel = false,
  }) {
    _frames = StreamController<CameraImageData>(
      sync: true,
      onListen: () => streaming = true,
      onCancel: () async {
        streamCancelled = true;
        streaming = false;
        if (throwOnStreamCancel) {
          throw PlatformException(code: 'stream_already_stopped');
        }
      },
    );
  }

  final List<CameraDescription> cameras;
  final bool throwOnInitialize;
  final bool throwOnStreamListen;
  final bool throwOnStreamCancel;
  final _initialized = StreamController<CameraInitializedEvent>.broadcast(
    sync: true,
  );
  final _errors = StreamController<CameraErrorEvent>.broadcast(sync: true);
  late final StreamController<CameraImageData> _frames;

  int createCalls = 0;
  bool streaming = false;
  bool streamCancelled = false;
  bool? requestedAudio;
  ResolutionPreset? requestedResolution;
  ImageFormatGroup? requestedImageFormat;
  final disposedCameraIds = <int>[];

  void emit(CameraImageData image) => _frames.add(image);

  void emitError(String description) =>
      _errors.add(CameraErrorEvent(7, description));

  @override
  Future<List<CameraDescription>> availableCameras() async => cameras;

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings mediaSettings,
  ) async {
    createCalls++;
    requestedAudio = mediaSettings.enableAudio;
    requestedResolution = mediaSettings.resolutionPreset;
    return 7;
  }

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    requestedImageFormat = imageFormatGroup;
    if (throwOnInitialize) {
      throw PlatformException(code: 'initialization_failed');
    }
    _initialized.add(
      CameraInitializedEvent(
        cameraId,
        640,
        480,
        ExposureMode.auto,
        false,
        FocusMode.auto,
        false,
      ),
    );
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      _initialized.stream;

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => _errors.stream;

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();

  @override
  bool supportsImageStreaming() => true;

  @override
  Stream<CameraImageData> onStreamedFrameAvailable(
    int cameraId, {
    CameraImageStreamOptions? options,
  }) {
    if (throwOnStreamListen) {
      throw PlatformException(code: 'stream_start_failed');
    }
    return _frames.stream;
  }

  @override
  Widget buildPreview(int cameraId) => const ColoredBox(
    key: Key('native_camera_preview'),
    color: Colors.blue,
  );

  @override
  Future<void> dispose(int cameraId) async {
    disposedCameraIds.add(cameraId);
  }
}
