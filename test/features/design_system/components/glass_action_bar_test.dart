import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('DsGlassRoundButton', () {
    testWidgets('renders the icon and fires onPressed when tapped', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DsGlassRoundButton(
            icon: Icons.mic_rounded,
            semanticLabel: 'Record',
            onPressed: () => taps++,
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      await tester.tap(find.byType(DsGlassRoundButton));
      expect(taps, 1);
    });

    testWidgets('uses the default diameter and honours a custom one', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
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
          theme: DesignSystemTheme.light(),
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
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DsGlassRoundButton(
            icon: Icons.stop,
            semanticLabel: 'Stop',
            iconColor: const Color(0xFFAABBCC),
            onPressed: () {},
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.stop));
      expect(icon.color, const Color(0xFFAABBCC));
    });
  });

  group('DsGlassPill', () {
    testWidgets('renders label and leading icon and fires onTap', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DsGlassPill(
            label: 'Build day',
            icon: Icons.arrow_forward_rounded,
            onTap: () => taps++,
          ),
          theme: DesignSystemTheme.light(),
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
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            width: 320,
            child: DsGlassPill(
              key: const Key('pill'),
              label: 'Wide',
              expand: true,
              onTap: () {},
            ),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(tester.getSize(find.byKey(const Key('pill'))).width, 320);
    });

    testWidgets('applies the foregroundColor override to the label', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DsGlassPill(
            label: 'Tinted',
            foregroundColor: const Color(0xFF112233),
            onTap: () {},
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final text = tester.widget<Text>(find.text('Tinted'));
      expect(text.style?.color, const Color(0xFF112233));
    });
  });
}
