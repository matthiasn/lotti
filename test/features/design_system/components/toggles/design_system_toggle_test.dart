import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemToggle', () {
    testWidgets('renders the small off state from tokens', (tester) async {
      const toggleKey = Key('toggle-small-off');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemToggle(
            key: toggleKey,
            value: false,
            label: 'Small toggle',
            tooltipIcon: Icons.info_outline_rounded,
            tooltipMessage: 'More information',
            onChanged: _noopToggle,
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final track = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(toggleKey),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is AnimatedContainer &&
                widget.constraints?.maxWidth == dsTokensLight.spacing.step8 &&
                widget.constraints?.maxHeight == dsTokensLight.spacing.step6,
          ),
        ),
      );
      final thumb = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(toggleKey),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is AnimatedContainer &&
                widget.constraints?.maxWidth ==
                    dsTokensLight.spacing.step6 - dsTokensLight.spacing.step2 &&
                widget.constraints?.maxHeight ==
                    dsTokensLight.spacing.step6 - dsTokensLight.spacing.step2,
          ),
        ),
      );
      final align = tester.widget<AnimatedAlign>(
        find.descendant(
          of: find.byKey(toggleKey),
          matching: find.byType(AnimatedAlign),
        ),
      );
      final label = tester.widget<RichText>(
        find.descendant(
          of: find.byKey(toggleKey),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText() == 'Small toggle',
          ),
        ),
      );
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(toggleKey),
          matching: find.byIcon(Icons.info_outline_rounded),
        ),
      );
      final tooltip = tester.widget<Tooltip>(
        find.descendant(
          of: find.byKey(toggleKey),
          matching: find.byType(Tooltip),
        ),
      );

      expect(
        (track.decoration! as BoxDecoration).color,
        Colors.transparent,
      );
      expect(
        ((track.decoration! as BoxDecoration).border! as Border).top.color,
        dsTokensLight.colors.text.mediumEmphasis,
      );
      expect(
        (thumb.decoration! as BoxDecoration).color,
        dsTokensLight.colors.text.highEmphasis,
      );
      expect(align.alignment, Alignment.centerLeft);
      expectTextStyle(
        label.text.style!,
        dsTokensLight.typography.styles.subtitle.subtitle2,
        dsTokensLight.colors.text.highEmphasis,
      );
      expect(
        icon.size,
        dsTokensLight.typography.styles.subtitle.subtitle2.fontSize,
      );
      expect(icon.color, dsTokensLight.colors.text.mediumEmphasis);
      expect(tooltip.message, 'More information');
    });

    testWidgets('renders the default on state from tokens', (tester) async {
      const toggleKey = Key('toggle-default-on');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemToggle(
            key: toggleKey,
            size: DesignSystemToggleSize.defaultSize,
            value: true,
            label: 'Default toggle',
            tooltipIcon: Icons.info_outline_rounded,
            onChanged: _noopToggle,
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final track = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(toggleKey),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is AnimatedContainer &&
                widget.constraints?.maxWidth == dsTokensLight.spacing.step9 &&
                widget.constraints?.maxHeight == dsTokensLight.spacing.step7,
          ),
        ),
      );
      final label = tester.widget<RichText>(
        find.descendant(
          of: find.byKey(toggleKey),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText() == 'Default toggle',
          ),
        ),
      );

      expect(
        (track.decoration! as BoxDecoration).color,
        dsTokensLight.colors.interactive.enabled,
      );
      expectTextStyle(
        label.text.style!,
        dsTokensLight.typography.styles.subtitle.subtitle1,
        dsTokensLight.colors.text.highEmphasis,
      );
    });

    testWidgets('switches value when tapped', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const _ToggleHarness(),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Off'), findsOneWidget);

      await tester.tap(find.byType(DesignSystemToggle));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('On'), findsOneWidget);
    });

    testWidgets('applies token-driven hover and disabled treatments', (
      tester,
    ) async {
      const hoverKey = Key('toggle-hover-off');
      const disabledKey = Key('toggle-disabled');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DesignSystemToggle(
                key: hoverKey,
                value: false,
                label: 'Hover toggle',
                forcedState: DesignSystemToggleVisualState.hover,
                onChanged: _noopToggle,
              ),
              DesignSystemToggle(
                key: disabledKey,
                value: false,
                label: 'Disabled toggle',
                enabled: false,
                onChanged: _noopToggle,
              ),
            ],
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final hoverTrack = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(hoverKey),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is AnimatedContainer &&
                widget.constraints?.maxWidth == dsTokensLight.spacing.step8 &&
                widget.constraints?.maxHeight == dsTokensLight.spacing.step6,
          ),
        ),
      );
      final disabledOpacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byKey(disabledKey),
          matching: find.byType(Opacity),
        ),
      );

      expect(
        (hoverTrack.decoration! as BoxDecoration).color,
        dsTokensLight.colors.surface.hover,
      );
      expect(
        (((hoverTrack.decoration! as BoxDecoration).border!) as Border)
            .top
            .color,
        dsTokensLight.colors.text.mediumEmphasis,
      );
      final hoverInkWell = tester.widget<InkWell>(
        find.descendant(
          of: find.byKey(hoverKey),
          matching: find.byType(InkWell),
        ),
      );
      expect(
        hoverInkWell.overlayColor?.resolve({WidgetState.hovered}),
        Colors.transparent,
      );
      expect(hoverInkWell.hoverColor, Colors.transparent);
      expect(hoverInkWell.highlightColor, Colors.transparent);
      expect(hoverInkWell.splashColor, Colors.transparent);
      expect(disabledOpacity.opacity, dsTokensLight.colors.text.lowEmphasis.a);
      expect(
        tester
            .widget<InkWell>(
              find.descendant(
                of: find.byKey(disabledKey),
                matching: find.byType(InkWell),
              ),
            )
            .onTap,
        isNull,
      );
    });

    testWidgets('omits optional label and tooltip icon when not provided', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      const toggleKey = Key('toggle-iconless');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemToggle(
            key: toggleKey,
            value: false,
            semanticsLabel: 'Accessible toggle',
            onChanged: _noopToggle,
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(
        find.descendant(of: find.byKey(toggleKey), matching: find.byType(Text)),
        findsNothing,
      );
      expect(
        find.descendant(of: find.byKey(toggleKey), matching: find.byType(Icon)),
        findsNothing,
      );
      expect(find.bySemanticsLabel('Accessible toggle'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('uses semanticsLabel as the tooltip fallback', (tester) async {
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemToggle(
            value: false,
            semanticsLabel: 'Accessible toggle',
            tooltipIcon: Icons.info_outline_rounded,
            onChanged: _noopToggle,
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));

      expect(tooltip.message, 'Accessible toggle');
      expect(find.bySemanticsLabel('Accessible toggle'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('wraps long labels in a flexible ellipsis text node', (
      tester,
    ) async {
      const label = 'A very long toggle label that should truncate cleanly';

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox(
            width: 180,
            child: DesignSystemToggle(
              value: false,
              label: label,
              tooltipIcon: Icons.info_outline_rounded,
              onChanged: _noopToggle,
            ),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(Flexible), findsOneWidget);

      final richText = tester.widget<RichText>(
        find.byWidgetPredicate(
          (widget) => widget is RichText && widget.text.toPlainText() == label,
        ),
      );

      expect(richText.overflow, TextOverflow.ellipsis);
      expect(richText.maxLines, 1);
    });

    testWidgets('clears transient hover state after disable and re-enable', (
      tester,
    ) async {
      final enabled = ValueNotifier<bool>(true);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          _ToggleEnabledHarness(enabled: enabled),
          theme: DesignSystemTheme.light(),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(() {
        enabled.dispose();
        return gesture.removePointer();
      });
      await gesture.addPointer();
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.byType(DesignSystemToggle)));
      await tester.pump();

      expect(
        (_toggleTrack(tester).decoration! as BoxDecoration).color,
        dsTokensLight.colors.interactive.hover,
      );

      enabled.value = false;
      await tester.pump();
      enabled.value = true;
      await tester.pump();

      expect(
        (_toggleTrack(tester).decoration! as BoxDecoration).color,
        dsTokensLight.colors.interactive.enabled,
      );
    });

    test('asserts when neither a label nor semantics label is provided', () {
      expect(
        () => DesignSystemToggle(
          value: false,
          onChanged: _noopToggle,
        ),
        throwsAssertionError,
      );
    });
  });
}

class _ToggleHarness extends StatefulWidget {
  const _ToggleHarness();

  @override
  State<_ToggleHarness> createState() => _ToggleHarnessState();
}

class _ToggleHarnessState extends State<_ToggleHarness> {
  bool _value = false;

  @override
  Widget build(BuildContext context) {
    return DesignSystemToggle(
      value: _value,
      label: _value ? 'On' : 'Off',
      onChanged: (value) => setState(() => _value = value),
    );
  }
}

class _ToggleEnabledHarness extends StatelessWidget {
  const _ToggleEnabledHarness({
    required this.enabled,
  });

  final ValueNotifier<bool> enabled;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: enabled,
      builder: (context, isEnabled, child) {
        return DesignSystemToggle(
          value: true,
          label: 'Hover me',
          enabled: isEnabled,
          onChanged: _noopToggle,
        );
      },
    );
  }
}

AnimatedContainer _toggleTrack(WidgetTester tester) {
  return tester.widget<AnimatedContainer>(
    find.byWidgetPredicate(
      (widget) =>
          widget is AnimatedContainer &&
          widget.constraints?.maxWidth == dsTokensLight.spacing.step8 &&
          widget.constraints?.maxHeight == dsTokensLight.spacing.step6,
    ),
  );
}

void _noopToggle(bool value) {}
