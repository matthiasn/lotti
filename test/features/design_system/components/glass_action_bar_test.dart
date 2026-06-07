import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../widget_test_utils.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
}) {
  return tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      child,
      theme: theme ?? DesignSystemTheme.light(),
    ),
  );
}

/// Reads the styled [Container] (the one carrying the [BoxDecoration]) inside
/// the given root widget type. Both [DsGlassRoundButton] and [DsGlassPill]
/// render exactly one [Container], which is the decorated one.
Container _decoratedContainer(WidgetTester tester, Type rootType) {
  return tester.widget<Container>(
    find.descendant(
      of: find.byType(rootType),
      matching: find.byType(Container),
    ),
  );
}

DsTokens _tokens(WidgetTester tester, Type rootType) {
  return tester.element(find.byType(rootType)).designTokens;
}

void main() {
  group('DsGlassRoundButton', () {
    testWidgets('renders the icon and fires onPressed when tapped', (
      tester,
    ) async {
      var taps = 0;
      await _pump(
        tester,
        DsGlassRoundButton(
          icon: Icons.mic_rounded,
          semanticLabel: 'Record',
          onPressed: () => taps++,
        ),
      );

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      await tester.tap(find.byType(DsGlassRoundButton));
      expect(taps, 1);
    });

    testWidgets('uses the default diameter and honours a custom one', (
      tester,
    ) async {
      await _pump(
        tester,
        Column(
          children: [
            DsGlassRoundButton(
              key: const Key('default'),
              icon: Icons.add,
              semanticLabel: 'Add',
              onPressed: () {},
            ),
            DsGlassRoundButton(
              key: const Key('big'),
              icon: Icons.add,
              semanticLabel: 'Add big',
              diameter: 64,
              onPressed: () {},
            ),
          ],
        ),
      );

      expect(
        tester.getSize(find.byKey(const Key('default'))),
        const Size.square(DsGlassRoundButton.defaultDiameter),
      );
      expect(
        tester.getSize(find.byKey(const Key('big'))),
        const Size.square(64),
      );
    });

    testWidgets('applies the iconColor override', (tester) async {
      await _pump(
        tester,
        DsGlassRoundButton(
          icon: Icons.stop,
          semanticLabel: 'Stop',
          iconColor: const Color(0xFFAABBCC),
          onPressed: () {},
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.stop));
      expect(icon.color, const Color(0xFFAABBCC));
    });

    testWidgets(
      'solid branch fills with backgroundColor and draws no hairline border',
      (tester) async {
        const bg = Color(0xFF123456);
        await _pump(
          tester,
          DsGlassRoundButton(
            icon: Icons.bolt,
            semanticLabel: 'Active',
            backgroundColor: bg,
            onPressed: () {},
          ),
        );

        final container = _decoratedContainer(tester, DsGlassRoundButton);
        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.color, bg);
        // No hairline outline drawn when a solid background is supplied.
        expect(container.foregroundDecoration, isNull);
      },
    );

    testWidgets(
      'translucent branch uses glass fill and a hairline border',
      (tester) async {
        await _pump(
          tester,
          DsGlassRoundButton(
            icon: Icons.bolt,
            semanticLabel: 'Idle',
            onPressed: () {},
          ),
        );

        final tokens = _tokens(tester, DsGlassRoundButton);
        final container = _decoratedContainer(tester, DsGlassRoundButton);
        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.color, dsGlassChipFill(tokens));

        final foreground = container.foregroundDecoration! as BoxDecoration;
        expect(foreground.border, isNotNull);
        expect(foreground.border, dsGlassChipBorder(tokens));
      },
    );

    testWidgets(
      'default iconColor falls back to text.highEmphasis',
      (tester) async {
        await _pump(
          tester,
          DsGlassRoundButton(
            icon: Icons.close,
            semanticLabel: 'Close',
            onPressed: () {},
          ),
        );

        final tokens = _tokens(tester, DsGlassRoundButton);
        final icon = tester.widget<Icon>(find.byIcon(Icons.close));
        expect(icon.color, tokens.colors.text.highEmphasis);
      },
    );

    testWidgets('exposes a button semantics node with its label', (
      tester,
    ) async {
      await _pump(
        tester,
        DsGlassRoundButton(
          icon: Icons.mic_rounded,
          semanticLabel: 'Record',
          onPressed: () {},
        ),
      );

      expect(find.bySemanticsLabel('Record'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Record')),
        matchesSemantics(label: 'Record', isButton: true),
      );
    });
  });

  group('DsGlassPill', () {
    testWidgets('renders label and leading icon and fires onTap', (
      tester,
    ) async {
      var taps = 0;
      await _pump(
        tester,
        DsGlassPill(
          label: 'Build day',
          icon: Icons.arrow_forward_rounded,
          onTap: () => taps++,
        ),
      );

      expect(find.text('Build day'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
      await tester.tap(find.byType(DsGlassPill));
      expect(taps, 1);
    });

    testWidgets('expand stretches the pill to the available width', (
      tester,
    ) async {
      await _pump(
        tester,
        SizedBox(
          width: 320,
          child: DsGlassPill(
            key: const Key('pill'),
            label: 'Wide',
            expand: true,
            onTap: () {},
          ),
        ),
      );

      expect(tester.getSize(find.byKey(const Key('pill'))).width, 320);
    });

    testWidgets('applies the foregroundColor override to the label', (
      tester,
    ) async {
      await _pump(
        tester,
        DsGlassPill(
          label: 'Tinted',
          foregroundColor: const Color(0xFF112233),
          onTap: () {},
        ),
      );

      final text = tester.widget<Text>(find.text('Tinted'));
      expect(text.style?.color, const Color(0xFF112233));
    });

    testWidgets(
      'solid branch fills with fillColor and draws no hairline border',
      (tester) async {
        const fill = Color(0xFF0A7E76);
        await _pump(
          tester,
          DsGlassPill(
            label: 'Primary',
            fillColor: fill,
            onTap: () {},
          ),
        );

        final container = _decoratedContainer(tester, DsGlassPill);
        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.color, fill);
        expect(container.foregroundDecoration, isNull);
      },
    );

    testWidgets(
      'translucent default uses glass fill and a hairline border',
      (tester) async {
        await _pump(
          tester,
          DsGlassPill(
            label: 'Idle',
            onTap: () {},
          ),
        );

        final tokens = _tokens(tester, DsGlassPill);
        final container = _decoratedContainer(tester, DsGlassPill);
        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.color, dsGlassChipFill(tokens));

        final foreground = container.foregroundDecoration! as BoxDecoration;
        expect(foreground.border, isNotNull);
        expect(foreground.border, dsGlassChipBorder(tokens));
      },
    );

    testWidgets(
      'default foreground falls back to text.highEmphasis for label and icon',
      (tester) async {
        await _pump(
          tester,
          DsGlassPill(
            label: 'Neutral',
            icon: Icons.arrow_forward_rounded,
            onTap: () {},
          ),
        );

        final tokens = _tokens(tester, DsGlassPill);
        final text = tester.widget<Text>(find.text('Neutral'));
        expect(text.style?.color, tokens.colors.text.highEmphasis);

        final icon = tester.widget<Icon>(
          find.byIcon(Icons.arrow_forward_rounded),
        );
        expect(icon.color, tokens.colors.text.highEmphasis);
      },
    );

    testWidgets('renders no icon when icon is null', (tester) async {
      await _pump(
        tester,
        DsGlassPill(
          label: 'No icon',
          onTap: () {},
        ),
      );

      expect(
        find.descendant(
          of: find.byType(DsGlassPill),
          matching: find.byType(Icon),
        ),
        findsNothing,
      );
    });

    testWidgets('label truncates with a single-line ellipsis', (tester) async {
      await _pump(
        tester,
        DsGlassPill(
          label: 'A very long label that should be ellipsized',
          onTap: () {},
        ),
      );

      final text = tester.widget<Text>(
        find.text('A very long label that should be ellipsized'),
      );
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets(
      'without expand the pill hugs its content (narrower than parent)',
      (tester) async {
        await _pump(
          tester,
          SizedBox(
            width: 320,
            child: Align(
              alignment: Alignment.centerLeft,
              child: DsGlassPill(
                key: const Key('pill'),
                label: 'Hug',
                onTap: () {},
              ),
            ),
          ),
        );

        final pillWidth = tester.getSize(find.byKey(const Key('pill'))).width;
        expect(pillWidth, lessThan(320));
      },
    );

    testWidgets('uses semanticLabel when it differs from the label', (
      tester,
    ) async {
      await _pump(
        tester,
        DsGlassPill(
          label: 'Go',
          semanticLabel: 'Build the day plan',
          onTap: () {},
        ),
      );

      expect(find.bySemanticsLabel('Build the day plan'), findsOneWidget);
      expect(find.bySemanticsLabel('Go'), findsNothing);
    });

    testWidgets('enabled true wires onTap', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        DsGlassPill(
          label: 'Tap me',
          onTap: () => taps++,
        ),
      );

      await tester.tap(find.byType(DsGlassPill));
      expect(taps, 1);
    });

    testWidgets(
      'enabled false: drops fill, dims foreground, ignores taps, disables a11y',
      (tester) async {
        var taps = 0;
        const fill = Color(0xFF0A7E76);
        await _pump(
          tester,
          DsGlassPill(
            label: 'Disabled',
            fillColor: fill,
            enabled: false,
            onTap: () => taps++,
          ),
        );

        // (a) onTap does not fire.
        await tester.tap(find.byType(DsGlassPill), warnIfMissed: false);
        expect(taps, 0);

        final tokens = _tokens(tester, DsGlassPill);

        // (b) Solid fill is dropped for the translucent glass fill.
        final container = _decoratedContainer(tester, DsGlassPill);
        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.color, dsGlassChipFill(tokens));
        expect(decoration.color, isNot(fill));

        // (c) Foreground dims to text.lowEmphasis.
        final text = tester.widget<Text>(find.text('Disabled'));
        expect(text.style?.color, tokens.colors.text.lowEmphasis);

        // (d) Semantics reports a disabled button.
        expect(
          tester.getSemantics(find.bySemanticsLabel('Disabled')),
          matchesSemantics(
            label: 'Disabled',
            isButton: true,
            hasEnabledState: true,
            // Asserted explicitly: the node carries enabled-state and is off.
            // ignore: avoid_redundant_argument_values
            isEnabled: false,
          ),
        );
      },
    );
  });
}
