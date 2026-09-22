import 'dart:async';

import 'package:camera/camera.dart' show CameraPreview, CameraValue, Optional;
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/ui/provisioned/qr_scanner.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/utils/platform.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zxing2/qrcode.dart';

import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CameraPlatform originalCameraPlatform;

  setUp(() {
    originalCameraPlatform = CameraPlatform.instance;
    final wasMobile = isMobile;
    final wasAndroid = isAndroid;
    isMobile = false;
    isAndroid = false;
    addTearDown(() {
      isMobile = wasMobile;
      isAndroid = wasAndroid;
    });
    DevLogger.suppressOutput = true;
    DevLogger.clear();
  });

  tearDown(() {
    CameraPlatform.instance = originalCameraPlatform;
    qrCameraFactoryOverride = null;
    DevLogger.suppressOutput = false;
    DevLogger.clear();
  });

  group('decodeQrFrame', () {
    for (final format in QrFramePixelFormat.values) {
      test('decodes ${format.name} data with padded rows', () {
        const payload = 'lotti-sync-handover-v2';
        final frame = _qrFrame(payload, format: format, rowPadding: 12);

        expect(decodeQrFrame(frame), payload);
      });
    }

    test('decodes a luminance plane whose last row stops at its width', () {
      // Android hands over a Y plane without the final row's stride padding;
      // insisting on height × stride bytes would reject every such frame.
      const payload = 'android-y-plane';
      final padded = _qrFrame(
        payload,
        format: QrFramePixelFormat.luminance,
        rowPadding: 16,
      );
      final trimmed = QrFrame(
        bytes: Uint8List.sublistView(padded.bytes, 0, padded.bytes.length - 16),
        width: padded.width,
        height: padded.height,
        bytesPerRow: padded.bytesPerRow,
        pixelFormat: QrFramePixelFormat.luminance,
      );

      expect(decodeQrFrame(trimmed), payload);
    });

    test('rejects a luminance plane shorter than its last row', () {
      final padded = _qrFrame(
        'truncated',
        format: QrFramePixelFormat.luminance,
        rowPadding: 16,
      );
      final truncated = QrFrame(
        bytes: Uint8List.sublistView(padded.bytes, 0, padded.bytes.length - 17),
        width: padded.width,
        height: padded.height,
        bytesPerRow: padded.bytesPerRow,
        pixelFormat: QrFramePixelFormat.luminance,
      );

      expect(decodeQrFrame(truncated), isNull);
    });

    test('returns null for a malformed frame', () {
      expect(
        decodeQrFrame(
          QrFrame(
            bytes: Uint8List(3),
            width: 20,
            height: 20,
            bytesPerRow: 80,
            pixelFormat: QrFramePixelFormat.rgba,
          ),
        ),
        isNull,
      );
    });

    test('returns null when the frame has no QR code', () {
      expect(
        decodeQrFrame(
          QrFrame(
            bytes: Uint8List.fromList(List.filled(40 * 40 * 4, 0xFF)),
            width: 40,
            height: 40,
            bytesPerRow: 40 * 4,
            pixelFormat: QrFramePixelFormat.rgba,
          ),
        ),
        isNull,
      );
    });

    test('decodes outside the UI isolate', () async {
      const payload = 'decoded-off-ui-isolate';
      final frame = _qrFrame(
        payload,
        format: QrFramePixelFormat.rgba,
        rowPadding: 4,
      );
      final scanner = QrScanner(
        onDetect: (_) {},
        unavailableBuilder: (_) => const SizedBox.shrink(),
      );

      expect(await scanner.decoder(frame), payload);
    });
  });

  group('QrScanner', () {
    testWidgets(
      'copies one frame in five and continues after a different payload',
      (tester) async {
        final camera = _FakeQrCamera();
        qrCameraFactoryOverride = () async => camera;
        final detected = <String>[];
        var decodeCount = 0;

        await tester.pumpWidget(
          makeTestableWidget2(
            QrScanner(
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

        expect(find.byKey(const Key('camera_preview')), findsOneWidget);
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
      qrCameraFactoryOverride = () async =>
          throw const FormatException('no camera');

      await tester.pumpWidget(
        makeTestableWidget2(
          QrScanner(
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
      final camera = _FakeQrCamera(
        startError: const FormatException('stream unavailable'),
      );
      qrCameraFactoryOverride = () async => camera;

      await tester.pumpWidget(
        makeTestableWidget2(
          QrScanner(
            onDetect: (_) {},
            unavailableBuilder: (_) => const Text('Camera unavailable'),
          ),
        ),
      );
      await tester.pump();

      expect(camera.started, isTrue);
      expect(camera.disposed, isTrue);
      expect(find.text('Camera unavailable'), findsOneWidget);
      expect(find.byKey(const Key('camera_preview')), findsNothing);
    });

    testWidgets('keeps fallback usable when failed camera disposal throws', (
      tester,
    ) async {
      final camera = _FakeQrCamera(
        startError: const FormatException('stream unavailable'),
        disposeError: const FormatException('dispose failed'),
      );
      qrCameraFactoryOverride = () async => camera;

      await tester.pumpWidget(
        makeTestableWidget2(
          QrScanner(
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

    group('app lifecycle', () {
      /// Hands out a fresh fake camera per request, recording each one.
      List<_FakeQrCamera> installCameraQueue() {
        final cameras = <_FakeQrCamera>[];
        qrCameraFactoryOverride = () async {
          final camera = _FakeQrCamera();
          cameras.add(camera);
          return camera;
        };
        return cameras;
      }

      Future<void> pumpScanner(WidgetTester tester) async {
        addTearDown(
          () => tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          ),
        );
        await tester.pumpWidget(
          makeTestableWidget2(
            QrScanner(
              onDetect: (_) {},
              unavailableBuilder: (_) => const Text('Camera unavailable'),
            ),
          ),
        );
        await tester.pump();
      }

      Future<void> moveTo(WidgetTester tester, AppLifecycleState state) async {
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump();
      }

      testWidgets('a backgrounded phone releases the camera and reopens it', (
        tester,
      ) async {
        isMobile = true;
        final cameras = installCameraQueue();
        await pumpScanner(tester);
        expect(cameras.single.started, isTrue);

        // Switching away (the app goes inactive, then hidden and paused)
        // releases the native session exactly once.
        await moveTo(tester, AppLifecycleState.inactive);
        await moveTo(tester, AppLifecycleState.hidden);
        await moveTo(tester, AppLifecycleState.paused);
        expect(cameras.single.disposed, isTrue);
        expect(find.byKey(const Key('camera_preview')), findsNothing);

        // Coming back opens a new camera instead of the stopped one.
        await moveTo(tester, AppLifecycleState.hidden);
        await moveTo(tester, AppLifecycleState.inactive);
        await moveTo(tester, AppLifecycleState.resumed);
        expect(cameras, hasLength(2));
        expect(cameras.last.started, isTrue);
        expect(cameras.last.disposed, isFalse);
        expect(find.byKey(const Key('camera_preview')), findsOneWidget);
      });

      testWidgets('a desktop window losing focus keeps its webcam', (
        tester,
      ) async {
        final cameras = installCameraQueue();
        await pumpScanner(tester);

        await moveTo(tester, AppLifecycleState.inactive);
        await moveTo(tester, AppLifecycleState.resumed);

        expect(cameras, hasLength(1));
        expect(cameras.single.disposed, isFalse);
        expect(find.byKey(const Key('camera_preview')), findsOneWidget);
      });

      testWidgets('a hidden desktop app releases its webcam until shown', (
        tester,
      ) async {
        final cameras = installCameraQueue();
        await pumpScanner(tester);

        await moveTo(tester, AppLifecycleState.inactive);
        await moveTo(tester, AppLifecycleState.hidden);
        expect(cameras.single.disposed, isTrue);

        await moveTo(tester, AppLifecycleState.inactive);
        await moveTo(tester, AppLifecycleState.resumed);
        expect(cameras, hasLength(2));
        expect(cameras.last.started, isTrue);
      });

      testWidgets('returning from settings retries a camera that had failed', (
        tester,
      ) async {
        // The denied-camera copy sends the user to system settings. Coming
        // back must pick up the new permission without another tap.
        isMobile = true;
        var attempts = 0;
        final granted = _FakeQrCamera();
        qrCameraFactoryOverride = () async {
          attempts++;
          if (attempts == 1) {
            throw CameraException('CameraAccessDenied', 'denied');
          }
          return granted;
        };
        await pumpScanner(tester);
        expect(find.text('Camera unavailable'), findsOneWidget);

        await moveTo(tester, AppLifecycleState.inactive);
        await moveTo(tester, AppLifecycleState.hidden);
        await moveTo(tester, AppLifecycleState.inactive);
        await moveTo(tester, AppLifecycleState.resumed);

        expect(attempts, 2);
        expect(granted.started, isTrue);
        expect(find.text('Camera unavailable'), findsNothing);
        expect(find.byKey(const Key('camera_preview')), findsOneWidget);
      });

      testWidgets('a camera that opens after backgrounding is discarded', (
        tester,
      ) async {
        // iOS's permission prompt makes the app inactive while the camera is
        // still being opened; what that request yields belongs to a session
        // that no longer exists.
        isMobile = true;
        final pending = Completer<QrCamera>();
        final lateCamera = _FakeQrCamera();
        final fresh = _FakeQrCamera();
        var requests = 0;
        qrCameraFactoryOverride = () {
          requests++;
          return requests == 1 ? pending.future : Future.value(fresh);
        };
        await pumpScanner(tester);

        await moveTo(tester, AppLifecycleState.inactive);
        pending.complete(lateCamera);
        await tester.pump();
        expect(lateCamera.disposed, isTrue);
        expect(lateCamera.started, isFalse);

        await moveTo(tester, AppLifecycleState.resumed);
        expect(fresh.started, isTrue);
        expect(find.byKey(const Key('camera_preview')), findsOneWidget);
      });

      testWidgets('a failure from a superseded session is not reported', (
        tester,
      ) async {
        isMobile = true;
        final pending = Completer<QrCamera>();
        final fresh = _FakeQrCamera();
        var requests = 0;
        qrCameraFactoryOverride = () {
          requests++;
          return requests == 1 ? pending.future : Future.value(fresh);
        };
        await pumpScanner(tester);

        await moveTo(tester, AppLifecycleState.inactive);
        await moveTo(tester, AppLifecycleState.resumed);
        expect(fresh.started, isTrue);

        // The first request only now fails. The live session is healthy, so
        // the fallback must not replace its preview.
        pending.completeError(CameraException('CameraAccessDenied', 'denied'));
        await tester.pump();

        expect(find.text('Camera unavailable'), findsNothing);
        expect(find.byKey(const Key('camera_preview')), findsOneWidget);
        expect(fresh.disposed, isFalse);
      });

      testWidgets('stops observing the lifecycle once removed', (tester) async {
        isMobile = true;
        final cameras = installCameraQueue();
        await pumpScanner(tester);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

        await moveTo(tester, AppLifecycleState.inactive);
        await moveTo(tester, AppLifecycleState.resumed);

        expect(cameras, hasLength(1));
        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('disposes a camera created after the scanner is removed', (
      tester,
    ) async {
      final cameraCompleter = Completer<QrCamera>();
      final camera = _FakeQrCamera();
      qrCameraFactoryOverride = () => cameraCompleter.future;

      await tester.pumpWidget(
        makeTestableWidget2(
          QrScanner(
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
      final camera = _FakeQrCamera();
      qrCameraFactoryOverride = () async => camera;
      final detected = <String>[];
      var decodeCount = 0;

      await tester.pumpWidget(
        makeTestableWidget2(
          QrScanner(
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
      final camera = _FakeQrCamera();
      qrCameraFactoryOverride = () async => camera;

      await tester.pumpWidget(
        makeTestableWidget2(
          QrScanner(
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
      final camera = _FakeQrCamera(
        disposeError: const FormatException('release failed'),
      );
      qrCameraFactoryOverride = () async => camera;

      await tester.pumpWidget(
        makeTestableWidget2(
          QrScanner(
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

  group('previewAspectRatio', () {
    const description = CameraDescription(
      name: 'rear',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 90,
    );
    final landscapeSensor = const CameraValue.uninitialized(
      description,
    ).copyWith(isInitialized: true, previewSize: const Size(640, 480));

    test('uses the sensor ratio in landscape', () {
      expect(
        previewAspectRatio(
          landscapeSensor.copyWith(
            deviceOrientation: DeviceOrientation.landscapeRight,
          ),
        ),
        640 / 480,
      );
    });

    test('inverts the ratio for an upright phone', () {
      expect(
        previewAspectRatio(
          landscapeSensor.copyWith(
            deviceOrientation: DeviceOrientation.portraitUp,
          ),
        ),
        480 / 640,
      );
    });

    test('a locked orientation wins over the device orientation', () {
      expect(
        previewAspectRatio(
          landscapeSensor.copyWith(
            deviceOrientation: DeviceOrientation.portraitUp,
            lockedCaptureOrientation: const Optional.of(
              DeviceOrientation.landscapeLeft,
            ),
          ),
        ),
        640 / 480,
      );
    });

    test('a paused preview keeps the orientation it paused in', () {
      expect(
        previewAspectRatio(
          landscapeSensor.copyWith(
            deviceOrientation: DeviceOrientation.landscapeLeft,
            lockedCaptureOrientation: const Optional.of(
              DeviceOrientation.landscapeLeft,
            ),
            previewPauseOrientation: const Optional.of(
              DeviceOrientation.portraitDown,
            ),
          ),
        ),
        480 / 640,
      );
    });
  });

  group('production camera adapter', () {
    testWidgets('shows the fallback when no webcam exists', (tester) async {
      final platform = _FakeCameraPlatform(cameras: const []);
      CameraPlatform.instance = platform;

      await tester.pumpWidget(
        makeTestableWidget2(
          QrScanner(
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
        createQrCamera(),
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
      final decodedFrames = <QrFrame>[];
      var admitFrame = false;

      final camera = await createQrCamera();
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
      expect(decodedFrames.first.pixelFormat, QrFramePixelFormat.rgba);
      expect(decodedFrames.first.bytes, [1, 2, 3, 4]);
      expect(decodedFrames.last.pixelFormat, QrFramePixelFormat.bgra);
      expect(decodedFrames.last.bytes, [5, 6, 7, 8]);

      // Android's YUV stream is decoded from its first (Y) plane alone.
      final yPlane = Uint8List.fromList([9, 10, 11, 12]);
      platform.emit(
        _cameraImage(
          yPlane,
          rawFormat: 35,
          group: ImageFormatGroup.yuv420,
        ),
      );
      yPlane[0] = 77;
      expect(decodedFrames, hasLength(3));
      expect(decodedFrames.last.pixelFormat, QrFramePixelFormat.luminance);
      expect(decodedFrames.last.bytes, [9, 10, 11, 12]);
      expect(decodedFrames.last.bytesPerRow, 4);

      await camera.dispose();

      expect(platform.streamCancelled, isTrue);
      expect(platform.disposedCameraIds, [7]);
    });

    test('Android streams YUV at the higher phone resolution', () async {
      isMobile = true;
      isAndroid = true;
      final platform = _FakeCameraPlatform();
      CameraPlatform.instance = platform;

      final camera = await createQrCamera();

      expect(platform.requestedImageFormat, ImageFormatGroup.yuv420);
      expect(platform.requestedResolution, ResolutionPreset.high);
      await camera.dispose();
    });

    test('iOS keeps BGRA frames at the higher phone resolution', () async {
      isMobile = true;
      final platform = _FakeCameraPlatform();
      CameraPlatform.instance = platform;

      final camera = await createQrCamera();

      expect(platform.requestedImageFormat, ImageFormatGroup.bgra8888);
      expect(platform.requestedResolution, ResolutionPreset.high);
      await camera.dispose();
    });

    test('prefers the back camera over one listed before it', () async {
      final platform = _FakeCameraPlatform(
        cameras: const [
          CameraDescription(
            name: 'selfie',
            lensDirection: CameraLensDirection.front,
            sensorOrientation: 270,
          ),
          CameraDescription(
            name: 'rear',
            lensDirection: CameraLensDirection.back,
            sensorOrientation: 90,
          ),
        ],
      );
      CameraPlatform.instance = platform;

      final camera = await createQrCamera();

      expect(platform.createdCameraNames, ['rear']);
      await camera.dispose();
    });

    test('falls back to the first camera when none faces back', () async {
      final platform = _FakeCameraPlatform(
        cameras: const [
          CameraDescription(
            name: 'built-in',
            lensDirection: CameraLensDirection.front,
            sensorOrientation: 0,
          ),
          CameraDescription(
            name: 'usb',
            lensDirection: CameraLensDirection.external,
            sensorOrientation: 0,
          ),
        ],
      );
      CameraPlatform.instance = platform;

      final camera = await createQrCamera();

      expect(platform.createdCameraNames, ['built-in']);
      await camera.dispose();
    });

    for (final (orientation, expected) in const [
      (DeviceOrientation.portraitUp, Size(200, 800 / 3)),
      (DeviceOrientation.landscapeLeft, Size(800 / 3, 200)),
    ]) {
      testWidgets(
        'a ${orientation.name} preview covers the square undistorted',
        (tester) async {
          final platform = _FakeCameraPlatform(orientation: orientation);
          CameraPlatform.instance = platform;

          // Created outside the fake clock: the controller's initialisation
          // waits on platform streams that a fake-async body never drains.
          final camera = (await tester.runAsync(createQrCamera))!;
          addTearDown(() => tester.runAsync(camera.dispose));
          await tester.pumpWidget(
            makeTestableWidget2(
              Center(
                child: SizedBox.square(
                  key: const Key('viewfinder'),
                  dimension: 200,
                  child: camera.buildPreview(),
                ),
              ),
            ),
          );
          await tester.pump();

          // The 640×480 picture keeps its own ratio and is scaled until the
          // shorter side fills the square, rather than squashed into it.
          final preview = tester.getRect(find.byType(CameraPreview));
          expect(preview.width, closeTo(expected.width, 0.01));
          expect(preview.height, closeTo(expected.height, 0.01));
          final square = find.byKey(const Key('viewfinder'));
          expect(preview.center, tester.getCenter(square));
          // The overflow is clipped to the square.
          expect(
            tester.getSize(
              find.descendant(of: square, matching: find.byType(ClipRect)),
            ),
            const Size.square(200),
          );
        },
      );
    }

    test('still disposes when the native stream already stopped', () async {
      final platform = _FakeCameraPlatform(throwOnStreamCancel: true);
      CameraPlatform.instance = platform;

      final camera = await createQrCamera();
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

      final camera = await createQrCamera();
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
          QrScanner(
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

QrFrame _blankFrame() => QrFrame(
  bytes: Uint8List.fromList(List.filled(4, 0xFF)),
  width: 1,
  height: 1,
  bytesPerRow: 4,
  pixelFormat: QrFramePixelFormat.rgba,
);

CameraImageData _cameraImage(
  Uint8List bytes, {
  required Object rawFormat,
  ImageFormatGroup group = ImageFormatGroup.bgra8888,
}) => CameraImageData(
  format: CameraImageFormat(group, raw: rawFormat),
  planes: [
    CameraImagePlane(
      bytes: bytes,
      bytesPerRow: bytes.length,
      bytesPerPixel: group == ImageFormatGroup.bgra8888 ? 4 : 1,
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

QrFrame _qrFrame(
  String payload, {
  required QrFramePixelFormat format,
  required int rowPadding,
}) {
  const quietZone = 4;
  const scale = 7;
  final bytesPerPixel = format.bytesPerPixel;
  final matrix = Encoder.encode(payload, ErrorCorrectionLevel.h).matrix!;
  final width = (matrix.width + quietZone * 2) * scale;
  final height = (matrix.height + quietZone * 2) * scale;
  final bytesPerRow = width * bytesPerPixel + rowPadding;
  final bytes = Uint8List(bytesPerRow * height)
    ..fillRange(0, bytesPerRow * height, 0xFF);

  for (var moduleY = 0; moduleY < matrix.height; moduleY++) {
    for (var moduleX = 0; moduleX < matrix.width; moduleX++) {
      if (matrix.get(moduleX, moduleY) != 1) continue;
      final startX = (moduleX + quietZone) * scale;
      final startY = (moduleY + quietZone) * scale;
      for (var y = startY; y < startY + scale; y++) {
        for (var x = startX; x < startX + scale; x++) {
          final offset = y * bytesPerRow + x * bytesPerPixel;
          bytes.fillRange(offset, offset + bytesPerPixel, 0);
          // Four-byte formats keep an opaque alpha channel.
          if (bytesPerPixel == 4) bytes[offset + 3] = 0xFF;
        }
      }
    }
  }

  return QrFrame(
    bytes: bytes,
    width: width,
    height: height,
    bytesPerRow: bytesPerRow,
    pixelFormat: format,
  );
}

class _FakeQrCamera implements QrCamera {
  _FakeQrCamera({this.startError, this.disposeError});

  final Exception? startError;
  final Exception? disposeError;
  bool Function()? _shouldCaptureFrame;
  ValueChanged<QrFrame>? _onFrame;
  bool started = false;
  bool disposed = false;
  int emittedFrames = 0;
  int capturedFrames = 0;

  @override
  Widget buildPreview() => const ColoredBox(
    key: Key('camera_preview'),
    color: Colors.green,
  );

  void emit(QrFrame frame) {
    emittedFrames++;
    if (!(_shouldCaptureFrame?.call() ?? false)) return;
    capturedFrames++;
    _onFrame?.call(frame);
  }

  @override
  Future<void> start({
    required bool Function() shouldCaptureFrame,
    required ValueChanged<QrFrame> onFrame,
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
    this.orientation,
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

  /// Reported through the orientation stream when set; the controller
  /// otherwise keeps its portrait default.
  final DeviceOrientation? orientation;
  final _initialized = StreamController<CameraInitializedEvent>.broadcast(
    sync: true,
  );
  final _errors = StreamController<CameraErrorEvent>.broadcast(sync: true);
  late final StreamController<CameraImageData> _frames;

  int createCalls = 0;
  final createdCameraNames = <String>[];
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
    createdCameraNames.add(cameraDescription.name);
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
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() {
    final reported = orientation;
    return reported == null
        ? const Stream.empty()
        : Stream.value(DeviceOrientationChangedEvent(reported));
  }

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
