import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

Future<void> pumpFab(
  WidgetTester tester, {
  VoidCallback? onPressed,
}) {
  return tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      DesignSystemFloatingActionButton(
        semanticLabel: 'Create',
        onPressed: onPressed,
      ),
      theme: DesignSystemTheme.light(),
    ),
  );
}

BoxDecoration _fabDecoration(WidgetTester tester) {
  final ink = tester.widget<Ink>(
    find.descendant(
      of: find.byType(DesignSystemFloatingActionButton),
      matching: find.byType(Ink),
    ),
  );
  return ink.decoration! as BoxDecoration;
}

void main() {
  group('DesignSystemFloatingActionButton', () {
    testWidgets('renders the primary jumbo icon-only button', (tester) async {
      await pumpFab(tester);

      expect(find.byType(DesignSystemFloatingActionButton), findsOneWidget);
      expect(find.bySemanticsLabel('Create'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);

      final size = tester.getSize(
        find.byType(DesignSystemFloatingActionButton),
      );
      expect(size, const Size(56, 56));
    });

    testWidgets('invokes onPressed when tapped', (tester) async {
      var tapped = false;

      await pumpFab(tester, onPressed: () => tapped = true);

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('centers the icon horizontally inside the button', (
      tester,
    ) async {
      await pumpFab(tester);

      final buttonCenter = tester.getCenter(
        find.byType(DesignSystemFloatingActionButton),
      );
      final iconCenter = tester.getCenter(find.byIcon(Icons.add_rounded));

      expect(iconCenter.dx, closeTo(buttonCenter.dx, 0.01));
    });

    testWidgets('uses rounded-xl (24) corners matching the Figma FAB', (
      tester,
    ) async {
      await pumpFab(tester);

      final ink = tester.widget<Ink>(
        find.descendant(
          of: find.byType(DesignSystemFloatingActionButton),
          matching: find.byType(Ink),
        ),
      );
      final decoration = ink.decoration! as BoxDecoration;
      expect(decoration.shape, BoxShape.rectangle);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(24),
        reason: 'FAB must match the Figma radii.xl (24) corner radius',
      );

      final inkWell = tester.widget<InkWell>(
        find.descendant(
          of: find.byType(DesignSystemFloatingActionButton),
          matching: find.byType(InkWell),
        ),
      );
      expect(inkWell.borderRadius, BorderRadius.circular(24));
    });

    testWidgets(
      'applies the hover background token while the pointer is over it',
      (tester) async {
        await pumpFab(tester, onPressed: () {});

        expect(
          _fabDecoration(tester).color,
          dsTokensLight.colors.interactive.enabled,
          reason: 'idle FAB uses the enabled background token',
        );

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer();
        await tester.pump();
        await gesture.moveTo(
          tester.getCenter(find.byType(DesignSystemFloatingActionButton)),
        );
        await tester.pump();

        expect(
          _fabDecoration(tester).color,
          dsTokensLight.colors.interactive.hover,
          reason: 'onEnter must flip the background to the hover token',
        );

        await gesture.moveTo(const Offset(-100, -100));
        await tester.pump();

        expect(
          _fabDecoration(tester).color,
          dsTokensLight.colors.interactive.enabled,
          reason: 'onExit must reset the background to the enabled token',
        );
      },
    );

    testWidgets('applies the pressed background token while held down', (
      tester,
    ) async {
      await pumpFab(tester, onPressed: () {});

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(DesignSystemFloatingActionButton)),
      );
      await tester.pump();
      // InkWell highlight kicks in after the tap-down delay.
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        _fabDecoration(tester).color,
        dsTokensLight.colors.interactive.pressed,
        reason: 'onHighlightChanged(true) must use the pressed token',
      );

      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        _fabDecoration(tester).color,
        dsTokensLight.colors.interactive.enabled,
        reason: 'releasing the press must restore the enabled token',
      );
    });

    testWidgets(
      'clears transient hover/pressed state when disabled then re-enabled',
      (tester) async {
        final enabled = ValueNotifier<bool>(true);
        addTearDown(enabled.dispose);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            _FabInteractionHarness(enabled: enabled),
            theme: DesignSystemTheme.light(),
          ),
        );

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer();
        await tester.pump();
        await gesture.moveTo(
          tester.getCenter(find.byType(DesignSystemFloatingActionButton)),
        );
        await tester.pump();

        expect(
          _fabDecoration(tester).color,
          dsTokensLight.colors.interactive.hover,
          reason: 'precondition: FAB is hovered before being disabled',
        );

        // Disabling removes onExit, so didUpdateWidget must clear _hovered.
        enabled.value = false;
        await tester.pump();
        enabled.value = true;
        await tester.pump();

        expect(
          _fabDecoration(tester).color,
          dsTokensLight.colors.interactive.enabled,
          reason: 'didUpdateWidget must drop the stale hover state on disable',
        );
      },
    );

    testWidgets(
      'does not react to hover/press while disabled (onPressed null)',
      (tester) async {
        await pumpFab(tester);

        expect(
          find.byType(Opacity),
          findsWidgets,
          reason: 'disabled FAB is wrapped in an Opacity',
        );

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer();
        await tester.pump();
        await gesture.moveTo(
          tester.getCenter(find.byType(DesignSystemFloatingActionButton)),
        );
        await tester.pump();

        // onEnter is null while disabled, so the background stays the
        // disabled-state enabled token and never flips to hover.
        expect(
          _fabDecoration(tester).color,
          dsTokensLight.colors.interactive.enabled,
        );

        // The component's own MouseRegion is the closest one wrapping the Ink.
        final mouseRegion = tester.widget<MouseRegion>(
          find
              .ancestor(
                of: find.byType(Ink),
                matching: find.byType(MouseRegion),
              )
              .first,
        );
        expect(mouseRegion.onEnter, isNull);
        expect(mouseRegion.onExit, isNull);
        expect(mouseRegion.cursor, SystemMouseCursors.basic);
      },
    );
  });
}

/// Rebuildable wrapper so a test can toggle [DesignSystemFloatingActionButton]
/// between enabled and disabled to exercise `didUpdateWidget`.
class _FabInteractionHarness extends StatelessWidget {
  const _FabInteractionHarness({required this.enabled});

  final ValueNotifier<bool> enabled;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: enabled,
      builder: (context, isEnabled, child) {
        return DesignSystemFloatingActionButton(
          semanticLabel: 'Create',
          onPressed: isEnabled ? () {} : null,
        );
      },
    );
  }
}
