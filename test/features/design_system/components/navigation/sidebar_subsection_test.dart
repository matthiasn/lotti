import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/navigation/sidebar_subsection.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('SidebarSubsectionSurface', () {
    testWidgets('uses the sidebar subsection surface tokens', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const SizedBox(
            width: 240,
            child: SidebarSubsectionSurface(
              children: [Text('Child content')],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Child content'), findsOneWidget);
      final tokens = tester
          .element(find.byType(SidebarSubsectionSurface))
          .designTokens;
      final surface = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(SidebarSubsectionSurface),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = surface.decoration as BoxDecoration;

      expect(decoration.color, tokens.colors.surface.enabled);
      expect(decoration.border, isNull);
      expect(decoration.borderRadius, BorderRadius.circular(tokens.radii.m));
    });
  });

  group('SidebarSubsectionAction', () {
    testWidgets('renders inactive icon and calls tap handler', (tester) async {
      var taps = 0;

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          SidebarSubsectionAction(
            label: 'Time Analysis',
            icon: Icons.bar_chart_outlined,
            activeIcon: Icons.bar_chart_rounded,
            active: false,
            onTap: () => taps++,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Time Analysis'), findsOneWidget);
      expect(find.byIcon(Icons.bar_chart_outlined), findsOneWidget);
      expect(find.byIcon(Icons.bar_chart_rounded), findsNothing);
      final tokens = tester
          .element(find.byType(SidebarSubsectionAction))
          .designTokens;
      final rail = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.byWidgetPredicate(
                (widget) =>
                    widget is SizedBox && widget.width == tokens.spacing.step1,
              ),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final railDecoration = rail.decoration as BoxDecoration;
      expect(railDecoration.color, tokens.colors.decorative.level02);

      await tester.tap(find.text('Time Analysis'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('renders active icon, selected surface, and active rail', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          SidebarSubsectionAction(
            label: 'AI Impact',
            icon: Icons.eco_outlined,
            activeIcon: Icons.eco_rounded,
            active: true,
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.eco_rounded), findsOneWidget);
      expect(find.byIcon(Icons.eco_outlined), findsNothing);

      final tokens = tester
          .element(find.byType(SidebarSubsectionAction))
          .designTokens;
      final material = tester.widget<Material>(
        find
            .ancestor(
              of: find.text('AI Impact'),
              matching: find.byType(Material),
            )
            .first,
      );
      final label = tester.widget<Text>(find.text('AI Impact'));
      final inkWell = tester.widget<InkWell>(
        find
            .ancestor(
              of: find.text('AI Impact'),
              matching: find.byType(InkWell),
            )
            .first,
      );
      final rail = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.byWidgetPredicate(
                (widget) =>
                    widget is SizedBox && widget.width == tokens.spacing.step2,
              ),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final railDecoration = rail.decoration as BoxDecoration;

      expect(material.color, tokens.colors.surface.active);
      expect(inkWell.focusColor, tokens.colors.surface.focusPressed);
      expect(railDecoration.color, tokens.colors.interactive.enabled);
      expect(label.style?.fontWeight, tokens.typography.weight.semiBold);
    });
  });
}
