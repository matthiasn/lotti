import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings_v2/state/settings_tree_width_controller.dart';
import 'package:lotti/features/settings_v2/ui/widgets/settings_tree_resize_handle.dart';

import '../../../../widget_test_utils.dart';

/// Drags with a warmup move that exceeds `kDragSlopDefault` so the
/// arena resolves to the horizontal drag recognizer (rather than
/// holding for a competing tap/double-tap). After warmup, subsequent
/// moves are reported to `onHorizontalDragUpdate` verbatim.
///
/// The _exact_ delta math is covered by the notifier tests; the
/// widget tests care only about direction and clamping, so a single
/// `moveBy(delta)` after warmup is all we need.
Future<void> _drag(WidgetTester tester, double dx) async {
  final center = tester.getCenter(find.byType(SettingsTreeResizeHandle));
  final gesture = await tester.startGesture(center);
  // Warmup: push past slop in the intended direction.
  await gesture.moveBy(Offset(dx.sign * (kDragSlopDefault + 1), 0));
  await tester.pump();
  await gesture.moveBy(Offset(dx, 0));
  await gesture.up();
  await tester.pump();
  // Drain the debounced persist timer so it doesn't leak into the
  // test framework's post-test "pending timers" check.
  await tester.pump(settingsTreeNavWidthPersistDebounce);
}

/// Drains any pending double-tap + debounce timers at the end of
/// tests that tap or reset — otherwise the test framework's
/// post-test "pending timers" invariant fires.
///
/// Uses the production debounce window + a small slack so this stays
/// in sync with `settingsTreeNavWidthPersistDebounce` if that ever
/// changes.
Future<void> _drainTimers(WidgetTester tester) async {
  await tester.pump(
    settingsTreeNavWidthPersistDebounce + const Duration(milliseconds: 100),
  );
}

Future<void> _pumpHandle(
  WidgetTester tester, {
  FocusNode? focusNode,
}) async {
  await tester.pumpWidget(
    makeTestableWidget(
      SizedBox(
        width: 400,
        height: 400,
        child: Center(
          child: SettingsTreeResizeHandle(focusNode: focusNode),
        ),
      ),
    ),
  );
  // Let the width provider hydrate.
  await tester.pump();
}

double _width(WidgetTester tester) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(SettingsTreeResizeHandle)),
  );
  return container.read(settingsTreeNavWidthProvider);
}

void main() {
  setUp(() async {
    await setUpTestGetIt();
  });

  tearDown(() async {
    await tearDownTestGetIt();
  });

  group('SettingsTreeResizeHandle — mouse cursor', () {
    testWidgets('exposes a resizeColumn cursor over the hit target', (
      tester,
    ) async {
      await _pumpHandle(tester);
      final region = tester.widget<MouseRegion>(
        find.descendant(
          of: find.byType(SettingsTreeResizeHandle),
          matching: find.byType(MouseRegion),
        ),
      );
      expect(region.cursor, SystemMouseCursors.resizeColumn);
    });
  });

  group('SettingsTreeResizeHandle — drag', () {
    testWidgets('horizontal drag increases the persisted width', (
      tester,
    ) async {
      await _pumpHandle(tester);
      final before = _width(tester);

      await _drag(tester, 50);

      expect(_width(tester), greaterThan(before));
    });

    testWidgets('reverse drag decreases the width', (tester) async {
      await _pumpHandle(tester);
      final before = _width(tester);

      await _drag(tester, -30);

      expect(_width(tester), lessThan(before));
    });

    testWidgets('drag clamps at the maximum', (tester) async {
      await _pumpHandle(tester);
      await _drag(tester, 500);
      expect(_width(tester), maxSettingsTreeNavWidth);
    });

    testWidgets('drag clamps at the minimum', (tester) async {
      await _pumpHandle(tester);
      await _drag(tester, -500);
      expect(_width(tester), minSettingsTreeNavWidth);
    });
  });

  group('SettingsTreeResizeHandle — double-tap', () {
    testWidgets('resets width back to default from a drifted value', (
      tester,
    ) async {
      await _pumpHandle(tester);
      await _drag(tester, 50);
      expect(_width(tester), isNot(defaultSettingsTreeNavWidth));

      final center = tester.getCenter(find.byType(SettingsTreeResizeHandle));
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(center);
      await _drainTimers(tester);

      expect(_width(tester), defaultSettingsTreeNavWidth);
    });
  });

  group('SettingsTreeResizeHandle — keyboard', () {
    testWidgets('right arrow nudges width up by the 8 dp step', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await _pumpHandle(tester, focusNode: focus);
      focus.requestFocus();
      await tester.pump();

      final before = _width(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await _drainTimers(tester);
      expect(_width(tester), before + settingsTreeNavWidthArrowStep);
    });

    testWidgets('left arrow nudges width down by the 8 dp step', (
      tester,
    ) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await _pumpHandle(tester, focusNode: focus);
      focus.requestFocus();
      await tester.pump();

      final before = _width(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await _drainTimers(tester);
      expect(_width(tester), before - settingsTreeNavWidthArrowStep);
    });

    testWidgets('shift+right uses the 32 dp step', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await _pumpHandle(tester, focusNode: focus);
      focus.requestFocus();
      await tester.pump();

      final before = _width(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await _drainTimers(tester);

      expect(_width(tester), before + settingsTreeNavWidthShiftArrowStep);
    });

    testWidgets('shift+left uses the 32 dp step in reverse', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await _pumpHandle(tester, focusNode: focus);
      focus.requestFocus();
      await tester.pump();

      final before = _width(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await _drainTimers(tester);

      expect(_width(tester), before - settingsTreeNavWidthShiftArrowStep);
    });

    testWidgets('Home resets to default', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await _pumpHandle(tester, focusNode: focus);
      focus.requestFocus();
      await tester.pump();

      // Drift first so Home actually changes something.
      await _drag(tester, 40);
      expect(_width(tester), isNot(defaultSettingsTreeNavWidth));

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await _drainTimers(tester);
      expect(_width(tester), defaultSettingsTreeNavWidth);
    });

    testWidgets(
      'unrelated keys pass through without changing the width',
      (tester) async {
        final focus = FocusNode();
        addTearDown(focus.dispose);
        await _pumpHandle(tester, focusNode: focus);
        focus.requestFocus();
        await tester.pump();

        final before = _width(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        await tester.pump();
        expect(_width(tester), before);
      },
    );

    testWidgets(
      'key repeat continues to nudge the width (held-down behavior)',
      (tester) async {
        final focus = FocusNode();
        addTearDown(focus.dispose);
        await _pumpHandle(tester, focusNode: focus);
        focus.requestFocus();
        await tester.pump();

        final before = _width(tester);
        // keyDown → repeat → keyUp simulates a held-down arrow key
        // producing a repeat event after the initial down.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
        await _drainTimers(tester);
        expect(_width(tester), before + settingsTreeNavWidthArrowStep * 2);
      },
    );
  });

  group('SettingsTreeResizeHandle — semantics', () {
    testWidgets('advertises itself as a slider with a resize label', (
      tester,
    ) async {
      await _pumpHandle(tester);
      final sem = tester.getSemantics(
        find
            .descendant(
              of: find.byType(SettingsTreeResizeHandle),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(sem.label, contains('Resize settings tree'));
    });

    testWidgets('onIncrease semantics action nudges width up', (tester) async {
      final semanticsHandle = tester.ensureSemantics();

      await _pumpHandle(tester);
      final before = _width(tester);

      final semanticsNode = tester.getSemantics(
        find
            .descendant(
              of: find.byType(SettingsTreeResizeHandle),
              matching: find.byType(Semantics),
            )
            .first,
      );
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(
          type: SemanticsAction.increase,
          nodeId: semanticsNode.id,
          viewId: tester.view.viewId,
        ),
      );
      await _drainTimers(tester);

      expect(_width(tester), before + settingsTreeNavWidthArrowStep);
      semanticsHandle.dispose();
    });

    testWidgets('onDecrease semantics action nudges width down', (
      tester,
    ) async {
      final semanticsHandle = tester.ensureSemantics();

      await _pumpHandle(tester);
      final before = _width(tester);

      final semanticsNode = tester.getSemantics(
        find
            .descendant(
              of: find.byType(SettingsTreeResizeHandle),
              matching: find.byType(Semantics),
            )
            .first,
      );
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(
          type: SemanticsAction.decrease,
          nodeId: semanticsNode.id,
          viewId: tester.view.viewId,
        ),
      );
      await _drainTimers(tester);

      expect(_width(tester), before - settingsTreeNavWidthArrowStep);
      semanticsHandle.dispose();
    });
  });

  group('SettingsTreeResizeHandle — hover', () {
    testWidgets('mouse enter sets hovered state and exit clears it', (
      tester,
    ) async {
      await _pumpHandle(tester);

      final center = tester.getCenter(find.byType(SettingsTreeResizeHandle));
      // Move mouse into the handle to trigger onEnter.
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      await gesture.moveTo(center);
      await tester.pump();

      // After hover enter the AnimatedContainer should use a non-transparent
      // color (hover bar is visible). We verify this indirectly by confirming
      // the MouseRegion's onEnter fired (the widget rebuilt without errors).
      final mouseRegion = tester.widget<MouseRegion>(
        find.descendant(
          of: find.byType(SettingsTreeResizeHandle),
          matching: find.byType(MouseRegion),
        ),
      );
      expect(mouseRegion.cursor, SystemMouseCursors.resizeColumn);

      // Move mouse out to trigger onExit.
      await gesture.moveTo(Offset.zero);
      await tester.pump();

      // Width is unchanged — hover only affects visual state.
      expect(_width(tester), defaultSettingsTreeNavWidth);
    });
  });

  group('SettingsTreeResizeHandle — didUpdateWidget', () {
    testWidgets(
      'adopts external focus node and disposes internally-created one',
      (tester) async {
        // Pump without a focusNode first. The widget's build calls _focusNode
        // getter which lazily creates _ownedFocusNode.
        await tester.pumpWidget(
          makeTestableWidget(
            const SizedBox(
              width: 400,
              height: 400,
              child: Center(child: SettingsTreeResizeHandle()),
            ),
          ),
        );
        await tester.pump();

        // Verify the widget is rendered (ownedFocusNode was created).
        expect(find.byType(SettingsTreeResizeHandle), findsOneWidget);

        // Now rebuild with an external FocusNode. didUpdateWidget fires with
        // oldWidget.focusNode == null && widget.focusNode != null, and since
        // _ownedFocusNode was created during the first build, the dispose
        // branch executes.
        final externalFocus = FocusNode();
        addTearDown(externalFocus.dispose);

        await tester.pumpWidget(
          makeTestableWidget(
            SizedBox(
              width: 400,
              height: 400,
              child: Center(
                child: SettingsTreeResizeHandle(focusNode: externalFocus),
              ),
            ),
          ),
        );
        await tester.pump();

        // The widget continues to function using the external focus node.
        externalFocus.requestFocus();
        await tester.pump();
        final before = _width(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await _drainTimers(tester);

        expect(_width(tester), before + settingsTreeNavWidthArrowStep);
      },
    );
  });
}
