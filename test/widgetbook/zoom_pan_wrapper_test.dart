import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgetbook/zoom_pan_wrapper.dart';

/// The modifier key used for zoom shortcuts — Command on macOS, Control on
/// Linux/Windows, matching the logic in [ZoomPanWrapperState.handleKeyEvent].
final LogicalKeyboardKey _modifierKey = Platform.isMacOS
    ? LogicalKeyboardKey.metaLeft
    : LogicalKeyboardKey.controlLeft;

Future<void> _pumpWrapper(
  WidgetTester tester, {
  GlobalKey<ZoomPanWrapperState>? key,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ZoomPanWrapper(
          key: key,
          child: const Text('Content'),
        ),
      ),
    ),
  );
  // Ensure Focus has received focus via autofocus
  await tester.pump();
}

void main() {
  group('ZoomPanWrapper rendering', () {
    testWidgets('renders child and InteractiveViewer', (tester) async {
      await _pumpWrapper(tester);

      expect(find.text('Content'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('renders SizedBox.shrink when child is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ZoomPanWrapper(child: null)),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('has autofocus Focus wrapping InteractiveViewer', (
      tester,
    ) async {
      await _pumpWrapper(tester);

      final focusWidgets = tester.widgetList<Focus>(
        find.ancestor(
          of: find.byType(InteractiveViewer),
          matching: find.byType(Focus),
        ),
      );
      expect(focusWidgets.any((f) => f.autofocus), isTrue);
    });

    testWidgets('InteractiveViewer has correct scale bounds', (tester) async {
      await _pumpWrapper(tester);

      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      expect(viewer.minScale, ZoomPanWrapperState.minScale);
      expect(viewer.maxScale, ZoomPanWrapperState.maxScale);
    });
  });

  group('ZoomPanWrapperState applyScale', () {
    testWidgets('sets transformation controller value', (tester) async {
      final key = GlobalKey<ZoomPanWrapperState>();
      await _pumpWrapper(tester, key: key);

      final state = key.currentState!;
      expect(state.currentScale, closeTo(1, 0.01));

      state.applyScale(2);
      expect(state.controller.value.getMaxScaleOnAxis(), closeTo(2, 0.01));
    });

    testWidgets('applyScale clamps above maxScale', (tester) async {
      final key = GlobalKey<ZoomPanWrapperState>();
      await _pumpWrapper(tester, key: key);

      key.currentState!.applyScale(10);
      expect(
        key.currentState!.controller.value.getMaxScaleOnAxis(),
        closeTo(ZoomPanWrapperState.maxScale, 0.01),
      );
    });

    testWidgets('applyScale clamps value set on controller', (tester) async {
      final key = GlobalKey<ZoomPanWrapperState>();
      await _pumpWrapper(tester, key: key);

      // Verify the controller matrix is set to the clamped value,
      // regardless of InteractiveViewer's subsequent layout correction.
      final state = key.currentState!..applyScale(0.01);
      // The matrix diagonal should reflect minScale clamping
      final matrix = state.controller.value;
      final sx = matrix.storage[0]; // scaleX from the diagonal
      expect(sx, closeTo(ZoomPanWrapperState.minScale, 0.01));
    });
  });

  group('ZoomPanWrapperState handleKeyEvent', () {
    testWidgets('ignores KeyUpEvent', (tester) async {
      final key = GlobalKey<ZoomPanWrapperState>();
      await _pumpWrapper(tester, key: key);

      final result = key.currentState!.handleKeyEvent(
        FocusNode(),
        const KeyUpEvent(
          physicalKey: PhysicalKeyboardKey.equal,
          logicalKey: LogicalKeyboardKey.equal,
          timeStamp: Duration.zero,
        ),
      );
      expect(result, KeyEventResult.ignored);
    });

    testWidgets('ignores key events without modifier', (tester) async {
      final key = GlobalKey<ZoomPanWrapperState>();
      await _pumpWrapper(tester, key: key);

      final result = key.currentState!.handleKeyEvent(
        FocusNode(),
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.equal,
          logicalKey: LogicalKeyboardKey.equal,
          timeStamp: Duration.zero,
        ),
      );
      expect(result, KeyEventResult.ignored);
    });

    testWidgets('Cmd++ zooms in', (tester) async {
      final key = GlobalKey<ZoomPanWrapperState>();
      await _pumpWrapper(tester, key: key);

      final initialScale = key.currentState!.currentScale;

      // Simulate Cmd++ via handleKeyEvent directly because
      // LogicalKeyboardKey.add has no physical key mapping in the
      // test framework.
      await tester.sendKeyDownEvent(_modifierKey);
      final result = key.currentState!.handleKeyEvent(
        FocusNode(),
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.numpadAdd,
          logicalKey: LogicalKeyboardKey.add,
          timeStamp: Duration.zero,
        ),
      );
      await tester.sendKeyUpEvent(_modifierKey);

      expect(result, KeyEventResult.handled);
      expect(
        key.currentState!.controller.value.getMaxScaleOnAxis(),
        greaterThan(initialScale),
      );
    });

    testWidgets('Cmd+- zooms out', (tester) async {
      final key = GlobalKey<ZoomPanWrapperState>();
      await _pumpWrapper(tester, key: key);

      // First zoom in so we have room to zoom out
      key.currentState!.applyScale(2);
      final zoomedScale = key.currentState!.controller.value
          .getMaxScaleOnAxis();

      await tester.sendKeyDownEvent(_modifierKey);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.minus);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.minus);
      await tester.sendKeyUpEvent(_modifierKey);

      expect(
        key.currentState!.controller.value.getMaxScaleOnAxis(),
        lessThan(zoomedScale),
      );
    });

    testWidgets('Cmd+0 resets zoom', (tester) async {
      final key = GlobalKey<ZoomPanWrapperState>();
      await _pumpWrapper(tester, key: key);

      // Zoom in first
      key.currentState!.applyScale(2);
      expect(
        key.currentState!.controller.value.getMaxScaleOnAxis(),
        closeTo(2, 0.01),
      );

      await tester.sendKeyDownEvent(_modifierKey);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.digit0);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.digit0);
      await tester.sendKeyUpEvent(_modifierKey);

      expect(
        key.currentState!.controller.value.getMaxScaleOnAxis(),
        closeTo(1, 0.01),
      );
    });

    testWidgets('ignores unrelated key even with modifier held', (
      tester,
    ) async {
      final key = GlobalKey<ZoomPanWrapperState>();
      await _pumpWrapper(tester, key: key);

      final initialScale = key.currentState!.currentScale;

      await tester.sendKeyDownEvent(_modifierKey);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(_modifierKey);

      expect(
        key.currentState!.controller.value.getMaxScaleOnAxis(),
        closeTo(initialScale, 0.01),
      );
    });
  });

  group('ZoomPanWrapper dispose', () {
    testWidgets('disposes TransformationController without error', (
      tester,
    ) async {
      await _pumpWrapper(tester);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
