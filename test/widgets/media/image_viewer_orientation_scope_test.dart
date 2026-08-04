import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/media/image_viewer_orientation_scope.dart';

void main() {
  test('portrait lock is applied only on mobile platforms', () async {
    final mobileCalls = <List<DeviceOrientation>>[];
    final mobileController = AppOrientationController(
      isMobilePlatform: () => true,
      setPreferredOrientations: (orientations) async {
        mobileCalls.add(List.of(orientations));
      },
    );
    final desktopCalls = <List<DeviceOrientation>>[];
    final desktopController = AppOrientationController(
      isMobilePlatform: () => false,
      setPreferredOrientations: (orientations) async {
        desktopCalls.add(List.of(orientations));
      },
    );

    await mobileController.lockToPortrait();
    await desktopController.lockToPortrait();

    expect(mobileCalls, [AppOrientationController.portraitOrientations]);
    expect(desktopCalls, isEmpty);
  });

  test(
    'nested viewers restore portrait only after the last viewer exits',
    () async {
      final calls = <List<DeviceOrientation>>[];
      final controller = AppOrientationController(
        isMobilePlatform: () => true,
        setPreferredOrientations: (orientations) async {
          calls.add(List.of(orientations));
        },
      );

      await controller.leaveImageViewer();
      expect(calls, isEmpty);

      await controller.enterImageViewer();
      await controller.enterImageViewer();
      await controller.leaveImageViewer();

      expect(calls, [AppOrientationController.imageViewerOrientations]);

      await controller.leaveImageViewer();

      expect(calls, [
        AppOrientationController.imageViewerOrientations,
        AppOrientationController.portraitOrientations,
      ]);
    },
  );

  testWidgets(
    'scope allows landscape, reapplies on resume, and restores portrait',
    (tester) async {
      final calls = <List<DeviceOrientation>>[];
      final controller = AppOrientationController(
        isMobilePlatform: () => true,
        setPreferredOrientations: (orientations) async {
          calls.add(List.of(orientations));
        },
      );

      await tester.pumpWidget(
        ImageViewerOrientationScope(
          controller: controller,
          child: const SizedBox.shrink(),
        ),
      );

      expect(calls, [AppOrientationController.imageViewerOrientations]);

      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await tester.pump();

      expect(calls, [
        AppOrientationController.imageViewerOrientations,
        AppOrientationController.imageViewerOrientations,
      ]);

      await tester.pumpWidget(const SizedBox.shrink());

      expect(calls.last, AppOrientationController.portraitOrientations);
    },
  );

  testWidgets('changing controller transfers viewer ownership', (tester) async {
    final firstCalls = <List<DeviceOrientation>>[];
    final firstController = AppOrientationController(
      isMobilePlatform: () => true,
      setPreferredOrientations: (orientations) async {
        firstCalls.add(List.of(orientations));
      },
    );
    final secondCalls = <List<DeviceOrientation>>[];
    final secondController = AppOrientationController(
      isMobilePlatform: () => true,
      setPreferredOrientations: (orientations) async {
        secondCalls.add(List.of(orientations));
      },
    );

    await tester.pumpWidget(
      ImageViewerOrientationScope(
        controller: firstController,
        child: const SizedBox.shrink(),
      ),
    );
    await tester.pumpWidget(
      ImageViewerOrientationScope(
        controller: secondController,
        child: const SizedBox.shrink(),
      ),
    );

    expect(firstCalls, [
      AppOrientationController.imageViewerOrientations,
      AppOrientationController.portraitOrientations,
    ]);
    expect(secondCalls, [AppOrientationController.imageViewerOrientations]);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(secondCalls.last, AppOrientationController.portraitOrientations);
  });
}
