import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/widgetbook/zoom_pan_wrapper.dart';

/// The two modifier keys [ZoomPanWrapperState.handleKeyEvent] accepts —
/// Command (macOS) and Control (Windows/Linux). Tests run against both so the
/// suite never depends on the host platform of the CI runner.
const _modifierKeys = <LogicalKeyboardKey>[
  LogicalKeyboardKey.metaLeft,
  LogicalKeyboardKey.controlLeft,
];

extension _AnyZoom on glados.Any {
  /// Scale inputs spanning far below [ZoomPanWrapperState.minScale] (including
  /// negatives), through the legal `[0.25, 4.0]` band, to far above
  /// [ZoomPanWrapperState.maxScale]. Exercises both clamp boundaries.
  glados.Generator<double> get scaleInput =>
      glados.DoubleAnys(this).doubleInRange(-100, 100);

  /// A logical key drawn from the set of keys the wrapper inspects plus a few
  /// it ignores, so the ignored-event property covers both sides of the border.
  glados.Generator<LogicalKeyboardKey> get logicalKey => choose(const [
    LogicalKeyboardKey.add,
    LogicalKeyboardKey.minus,
    LogicalKeyboardKey.digit0,
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.equal,
    LogicalKeyboardKey.space,
  ]);
}

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

    testWidgets('uses an empty SizedBox.shrink child when child is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ZoomPanWrapper(child: null)),
        ),
      );

      // The wrapper still builds the viewer, and its child is the zero-sized
      // placeholder rather than any real content.
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      expect(viewer.child, isA<SizedBox>());
      final placeholder = viewer.child! as SizedBox;
      expect(placeholder.width, 0);
      expect(placeholder.height, 0);
      expect(find.text('Content'), findsNothing);
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

    testWidgets('applyScale clamps below minScale', (tester) async {
      final key = GlobalKey<ZoomPanWrapperState>();
      await _pumpWrapper(tester, key: key);

      key.currentState!.applyScale(0.01);
      // currentScale (getMaxScaleOnAxis) floors sub-unit scales at 1.0 because
      // the matrix z-axis stays 1.0, so the stored x/y factor is the only
      // faithful read of a below-min clamp.
      expect(
        key.currentState!.controller.value.storage[0],
        closeTo(ZoomPanWrapperState.minScale, 1e-9),
      );
      expect(
        key.currentState!.controller.value.storage[5],
        closeTo(ZoomPanWrapperState.minScale, 1e-9),
      );
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

    // Run the modifier-driven shortcuts against BOTH Command and Control so the
    // assertions never depend on the CI runner's OS.
    for (final modifier in _modifierKeys) {
      final name = modifier == LogicalKeyboardKey.metaLeft ? 'Cmd' : 'Ctrl';

      testWidgets('$name + "+" zooms in', (tester) async {
        final key = GlobalKey<ZoomPanWrapperState>();
        await _pumpWrapper(tester, key: key);

        final initialScale = key.currentState!.currentScale;

        // Hold the modifier so HardwareKeyboard reports it pressed, then feed
        // the add key directly: LogicalKeyboardKey.add has no physical mapping
        // in the test framework's sendKeyDownEvent path.
        await tester.sendKeyDownEvent(modifier);
        final result = key.currentState!.handleKeyEvent(
          FocusNode(),
          const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.numpadAdd,
            logicalKey: LogicalKeyboardKey.add,
            timeStamp: Duration.zero,
          ),
        );
        await tester.sendKeyUpEvent(modifier);

        expect(result, KeyEventResult.handled);
        expect(
          key.currentState!.currentScale,
          closeTo(initialScale + ZoomPanWrapperState.zoomStep, 0.01),
        );
      });

      testWidgets('$name + "+" on a KeyRepeatEvent also zooms in', (
        tester,
      ) async {
        final key = GlobalKey<ZoomPanWrapperState>();
        await _pumpWrapper(tester, key: key);

        final initialScale = key.currentState!.currentScale;

        await tester.sendKeyDownEvent(modifier);
        final result = key.currentState!.handleKeyEvent(
          FocusNode(),
          const KeyRepeatEvent(
            physicalKey: PhysicalKeyboardKey.numpadAdd,
            logicalKey: LogicalKeyboardKey.add,
            timeStamp: Duration.zero,
          ),
        );
        await tester.sendKeyUpEvent(modifier);

        // Auto-repeat must advance the scale just like the initial key-down.
        expect(result, KeyEventResult.handled);
        expect(
          key.currentState!.currentScale,
          closeTo(initialScale + ZoomPanWrapperState.zoomStep, 0.01),
        );
      });

      testWidgets('$name + "-" zooms out', (tester) async {
        final key = GlobalKey<ZoomPanWrapperState>();
        await _pumpWrapper(tester, key: key);

        // First zoom in so we have room to zoom out.
        key.currentState!.applyScale(2);
        final zoomedScale = key.currentState!.currentScale;

        await tester.sendKeyDownEvent(modifier);
        final result = key.currentState!.handleKeyEvent(
          FocusNode(),
          const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.minus,
            logicalKey: LogicalKeyboardKey.minus,
            timeStamp: Duration.zero,
          ),
        );
        await tester.sendKeyUpEvent(modifier);

        expect(result, KeyEventResult.handled);
        expect(
          key.currentState!.currentScale,
          closeTo(zoomedScale - ZoomPanWrapperState.zoomStep, 0.01),
        );
      });

      testWidgets('$name + "0" resets zoom to 1x', (tester) async {
        final key = GlobalKey<ZoomPanWrapperState>();
        await _pumpWrapper(tester, key: key);

        key.currentState!.applyScale(2);
        expect(key.currentState!.currentScale, closeTo(2, 0.01));

        await tester.sendKeyDownEvent(modifier);
        final result = key.currentState!.handleKeyEvent(
          FocusNode(),
          const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.digit0,
            logicalKey: LogicalKeyboardKey.digit0,
            timeStamp: Duration.zero,
          ),
        );
        await tester.sendKeyUpEvent(modifier);

        expect(result, KeyEventResult.handled);
        expect(key.currentState!.currentScale, closeTo(1, 0.01));
      });

      testWidgets('$name + unrelated key is ignored and leaves scale alone', (
        tester,
      ) async {
        final key = GlobalKey<ZoomPanWrapperState>();
        await _pumpWrapper(tester, key: key);

        final initialScale = key.currentState!.currentScale;

        await tester.sendKeyDownEvent(modifier);
        final result = key.currentState!.handleKeyEvent(
          FocusNode(),
          const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.keyA,
            logicalKey: LogicalKeyboardKey.keyA,
            timeStamp: Duration.zero,
          ),
        );
        await tester.sendKeyUpEvent(modifier);

        expect(result, KeyEventResult.ignored);
        expect(
          key.currentState!.currentScale,
          closeTo(initialScale, 0.01),
        );
      });
    }
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

  // ---------------------------------------------------------------------------
  // Glados property tests.
  //
  // applyScale is a pure arithmetic clamp over its TransformationController, and
  // the type guard in handleKeyEvent rejects every non-KeyDown/KeyRepeat event
  // regardless of modifier state — both are invariants that hold for ANY input,
  // not just the hand-picked values above. The state object only touches its
  // own controller (no context / mounting needed), so it is created and
  // disposed directly per run.
  // ---------------------------------------------------------------------------
  group('applyScale — properties', () {
    glados.Glados<double>(
      glados.any.scaleInput,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'stored x/y scale always equals the clamp of the input',
      (input) {
        final state = ZoomPanWrapperState();
        try {
          state.applyScale(input);
          final expected = input.clamp(
            ZoomPanWrapperState.minScale,
            ZoomPanWrapperState.maxScale,
          );
          // applyScale writes the clamped factor onto the x/y diagonal of the
          // matrix. currentScale (getMaxScaleOnAxis) cannot be used here: the
          // matrix z-axis stays at 1.0, so it floors any sub-unit scale to 1.0.
          // The raw storage indices are the only faithful observation.
          final storedX = state.controller.value.storage[0];
          final storedY = state.controller.value.storage[5];
          expect(
            storedX,
            closeTo(expected, 1e-9),
            reason: 'input=$input did not clamp x to $expected',
          );
          expect(
            storedY,
            closeTo(expected, 1e-9),
            reason: 'input=$input did not clamp y to $expected',
          );
          expect(
            storedX,
            inInclusiveRange(
              ZoomPanWrapperState.minScale,
              ZoomPanWrapperState.maxScale,
            ),
            reason: 'input=$input produced out-of-range scale $storedX',
          );
        } finally {
          state.controller.dispose();
        }
      },
      tags: 'glados',
    );
  });

  group('handleKeyEvent — properties', () {
    glados.Glados<LogicalKeyboardKey>(
      glados.any.logicalKey,
    ).test(
      'every KeyUpEvent is ignored regardless of which key it carries',
      (logicalKey) {
        final state = ZoomPanWrapperState();
        try {
          final result = state.handleKeyEvent(
            FocusNode(),
            KeyUpEvent(
              physicalKey: PhysicalKeyboardKey.equal,
              logicalKey: logicalKey,
              timeStamp: Duration.zero,
            ),
          );
          // The type guard rejects key-up before any modifier/key inspection,
          // so the scale must never move for an up event.
          expect(
            result,
            KeyEventResult.ignored,
            reason: 'KeyUpEvent for $logicalKey was not ignored',
          );
          expect(state.currentScale, closeTo(1, 1e-9));
        } finally {
          state.controller.dispose();
        }
      },
      tags: 'glados',
    );
  });
}
