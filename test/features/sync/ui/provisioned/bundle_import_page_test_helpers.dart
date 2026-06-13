import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/platform.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobile_scanner/src/method_channel/mobile_scanner_method_channel.dart';

// ---------------------------------------------------------------------------
// Fake MobileScannerPlatform used to prevent platform channel crashes when
// the MobileScanner widget is mounted in tests.
// ---------------------------------------------------------------------------
class FakeMethodChannelMobileScanner extends MethodChannelMobileScanner {
  final _barcodesController = StreamController<BarcodeCapture?>.broadcast();
  final _torchController = StreamController<TorchState>.broadcast();
  final _zoomController = StreamController<double>.broadcast();

  Stream<BarcodeCapture?> get testBarcodesStream => _barcodesController.stream;

  @override
  Stream<BarcodeCapture?> get barcodesStream => _barcodesController.stream;

  @override
  Stream<TorchState> get torchStateStream => _torchController.stream;

  @override
  Stream<double> get zoomScaleStateStream => _zoomController.stream;

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.off,
      size: Size(640, 480),
      numberOfCameras: 1,
    );
  }

  @override
  Future<void> stop({bool force = false}) async {}

  @override
  Widget buildCameraView() {
    return const Placeholder(
      fallbackHeight: 100,
      fallbackWidth: 100,
      color: Color(0xFF00AA00),
    );
  }

  Future<void> disposeControllers() async {
    await _barcodesController.close();
    await _torchController.close();
    await _zoomController.close();
  }
}

/// Pins the platform flags to mobile and installs a fresh fake scanner
/// platform, registering all restores/teardowns — the shared preamble of
/// every scan-flow test.
void setUpMobileScanner() {
  final wasDesktop = isDesktop;
  final wasMobile = isMobile;
  isDesktop = false;
  isMobile = true;
  addTearDown(() {
    isDesktop = wasDesktop;
    isMobile = wasMobile;
  });

  final fakePlatform = FakeMethodChannelMobileScanner();
  MobileScannerPlatform.instance = fakePlatform;
  addTearDown(fakePlatform.disposeControllers);
}
