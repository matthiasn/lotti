import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemChip', () {
    testWidgets('renders the enabled label-only chip from tokens', (
      tester,
    ) async {
      var tapCount = 0;

      await _pumpChip(
        tester,
        DesignSystemChip(
          label: 'Plain',
          onPressed: () => tapCount++,
        ),
      );

      final decoration = _chipDecoration(tester);
      final richText = _findTextNode(tester, 'Plain');
      final expectedHeight =
          dsTokensLight.typography.lineHeight.bodySmall +
          (dsTokensLight.spacing.step1 * 2);

      expect(_chipSize(tester).height, expectedHeight);
      expect(decoration.color, dsTokensLight.colors.surface.enabled);
      expect(
        decoration.shape,
        isA<RoundedRectangleBorder>().having(
          (shape) => shape.borderRadius,
          'borderRadius',
          BorderRadius.circular(dsTokensLight.radii.s),
        ),
      );
      _expectTextStyle(
        richText.text.style!,
        dsTokensLight.typography.styles.body.bodySmall,
        dsTokensLight.colors.text.highEmphasis,
      );

      await tester.tap(find.byType(DesignSystemChip));
      await tester.pump();

      expect(tapCount, 1);
    });

    testWidgets('renders the hover chip state from tokens', (tester) async {
      await _pumpChip(
        tester,
        const DesignSystemChip(
          label: 'Hover',
          forcedState: DesignSystemChipVisualState.hover,
          onPressed: _noop,
        ),
      );

      expect(
        _chipDecoration(tester).color,
        dsTokensLight.colors.surface.hover,
      );
    });

    testWidgets('updates to the hover state during mouse interaction', (
      tester,
    ) async {
      await _pumpChip(
        tester,
        const DesignSystemChip(
          label: 'Interactive hover',
          onPressed: _noop,
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer();
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.byType(DesignSystemChip)));
      await tester.pump();

      expect(
        _chipDecoration(tester).color,
        dsTokensLight.colors.surface.hover,
      );
    });

    testWidgets('renders the pressed chip state from tokens', (tester) async {
      await _pumpChip(
        tester,
        const DesignSystemChip(
          label: 'Pressed',
          forcedState: DesignSystemChipVisualState.pressed,
          onPressed: _noop,
        ),
      );

      expect(
        _chipDecoration(tester).color,
        dsTokensLight.colors.surface.focusPressed,
      );
    });

    testWidgets('renders the activated chip state from tokens', (
      tester,
    ) async {
      await _pumpChip(
        tester,
        const DesignSystemChip(
          label: 'Activated',
          forcedState: DesignSystemChipVisualState.activated,
          onPressed: _noop,
        ),
      );

      final semantics = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.button == true,
        ),
      );

      expect(
        _chipDecoration(tester).color,
        dsTokensLight.colors.surface.active,
      );
      expect(semantics.properties.selected, isTrue);
    });

    testWidgets('applies token-driven disabled opacity', (tester) async {
      await _pumpChip(
        tester,
        const DesignSystemChip(
          label: 'Disabled',
          onPressed: null,
        ),
      );

      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      final inkWell = tester.widget<InkWell>(find.byType(InkWell));

      expect(opacity.opacity, dsTokensLight.colors.text.lowEmphasis.a);
      expect(inkWell.onTap, isNull);
    });

    testWidgets('renders the icon and remove affordances from tokens', (
      tester,
    ) async {
      await _pumpChip(
        tester,
        const DesignSystemChip(
          label: 'With icon',
          leadingIcon: Icons.location_on_rounded,
          showRemove: true,
          onPressed: _noop,
        ),
      );

      final iconTheme = tester.widget<IconTheme>(
        find.byWidgetPredicate(
          (widget) =>
              widget is IconTheme &&
              widget.data.size == dsTokensLight.typography.lineHeight.caption &&
              widget.data.color == dsTokensLight.colors.text.mediumEmphasis,
        ),
      );
      final squareSlots = tester.widgetList<SizedBox>(
        find.byWidgetPredicate(
          (widget) =>
              widget is SizedBox &&
              widget.width == dsTokensLight.typography.lineHeight.bodySmall &&
              widget.height == dsTokensLight.typography.lineHeight.bodySmall,
        ),
      );

      expect(iconTheme.data.color, dsTokensLight.colors.text.mediumEmphasis);
      expect(iconTheme.data.size, dsTokensLight.typography.lineHeight.caption);
      expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);
      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
      expect(squareSlots.length, 2);
    });

    testWidgets('renders an avatar chip and clips the avatar to a circle', (
      tester,
    ) async {
      await _pumpChip(
        tester,
        DesignSystemChip(
          label: 'With avatar',
          avatar: Container(color: Colors.red),
          onPressed: _noop,
        ),
      );

      expect(find.byType(ClipOval), findsOneWidget);
      expect(find.text('With avatar'), findsOneWidget);
    });

    test('asserts when both leading icon and avatar are provided', () {
      expect(
        () => DesignSystemChip(
          label: 'Invalid',
          leadingIcon: Icons.schedule_rounded,
          avatar: Container(),
          onPressed: _noop,
        ),
        throwsAssertionError,
      );
    });
  });
}

Future<void> _pumpChip(
  WidgetTester tester,
  Widget child,
) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      child,
      theme: DesignSystemTheme.light(),
    ),
  );
}

ShapeDecoration _chipDecoration(WidgetTester tester) {
  final ink = tester.widget<Ink>(find.byType(Ink));
  return ink.decoration! as ShapeDecoration;
}

Size _chipSize(WidgetTester tester) {
  return tester.getSize(find.byType(Ink));
}

RichText _findTextNode(WidgetTester tester, String label) {
  return tester.widget<RichText>(
    find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText() == label,
    ),
  );
}

void _expectTextStyle(TextStyle actual, TextStyle expected, Color color) {
  expect(actual.fontFamily, expected.fontFamily);
  expect(actual.fontSize, expected.fontSize);
  expect(actual.fontWeight, expected.fontWeight);
  expect(actual.letterSpacing, expected.letterSpacing);
  expect(actual.height, expected.height);
  expect(actual.color, color);
}

void _noop() {}
