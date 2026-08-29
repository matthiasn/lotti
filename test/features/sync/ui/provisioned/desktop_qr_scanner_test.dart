import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/ui/provisioned/desktop_qr_scanner.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:zxing2/qrcode.dart';

import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    DevLogger.suppressOutput = true;
    DevLogger.clear();
  });

  tearDown(() {
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
  });
}

DesktopQrFrame _blankFrame() => DesktopQrFrame(
  bytes: Uint8List.fromList(List.filled(4, 0xFF)),
  width: 1,
  height: 1,
  bytesPerRow: 4,
  channelOrder: DesktopQrChannelOrder.rgba,
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
  }) async {
    started = true;
    _shouldCaptureFrame = shouldCaptureFrame;
    _onFrame = onFrame;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    _shouldCaptureFrame = null;
    _onFrame = null;
  }
}
