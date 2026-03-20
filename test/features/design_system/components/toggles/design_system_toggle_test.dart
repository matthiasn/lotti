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

      expect(
        (track.decoration! as BoxDecoration).color,
        dsTokensLight.colors.background.level02,
      );
      expect(
        (thumb.decoration! as BoxDecoration).color,
        dsTokensLight.colors.background.level01,
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
      const hoverKey = Key('toggle-hover');
      const disabledKey = Key('toggle-disabled');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DesignSystemToggle(
                key: hoverKey,
                value: true,
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
        dsTokensLight.colors.interactive.hover,
      );
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
      const toggleKey = Key('toggle-iconless');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemToggle(
            key: toggleKey,
            value: false,
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

void _noopToggle(bool value) {}
