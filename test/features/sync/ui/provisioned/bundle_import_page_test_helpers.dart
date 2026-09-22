import 'package:flutter_test/flutter_test.dart'
    hide isLinux, isMacOS, isWindows;
import 'package:lotti/features/sync/ui/provisioned/qr_scanner.dart';
import 'package:lotti/utils/platform.dart';
import 'package:material_ui/material_ui.dart';

/// A camera the real [QrScanner] can mount without a platform plugin.
///
/// [startError] makes the stream refuse to start, the way a platform rejects
/// a camera it cannot open.
class FakeQrCamera implements QrCamera {
  FakeQrCamera({this.startError});

  final Exception? startError;
  bool started = false;
  bool disposed = false;

  @override
  Widget buildPreview() => const ColoredBox(
    key: Key('fake_camera_preview'),
    color: Color(0xFF00AA00),
  );

  @override
  Future<void> start({
    required bool Function() shouldCaptureFrame,
    required ValueChanged<QrFrame> onFrame,
    required ValueChanged<Object> onError,
  }) async {
    started = true;
    final error = startError;
    if (error != null) throw error;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

/// Installs [factory] as the scanner's camera source for one test.
void installQrCameraFactory(QrCameraFactory factory) {
  qrCameraFactoryOverride = factory;
  addTearDown(() => qrCameraFactoryOverride = null);
}

/// Pins the platform flags to a phone and installs a fake camera, registering
/// all restores — the shared preamble of every scan-flow test.
FakeQrCamera setUpMobileScanner() {
  final wasDesktop = isDesktop;
  final wasMobile = isMobile;
  final wasWindows = isWindows;
  final wasLinux = isLinux;
  final wasMacOS = isMacOS;
  isDesktop = false;
  isMobile = true;
  isWindows = false;
  isLinux = false;
  isMacOS = false;
  addTearDown(() {
    isDesktop = wasDesktop;
    isMobile = wasMobile;
    isWindows = wasWindows;
    isLinux = wasLinux;
    isMacOS = wasMacOS;
  });

  final camera = FakeQrCamera();
  installQrCameraFactory(() async => camera);
  return camera;
}

/// Pins the platform flags to macOS with the same fake camera.
FakeQrCamera setUpMacOsScanner() {
  final camera = setUpMobileScanner();
  isDesktop = true;
  isMobile = false;
  isMacOS = true;
  return camera;
}

/// Delivers [code] exactly as the mounted scanner reports a decoded frame.
void scanCode(WidgetTester tester, String code) {
  tester.widget<QrScanner>(find.byType(QrScanner)).onDetect(code);
}
