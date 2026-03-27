import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/breadcrumbs/design_system_breadcrumbs.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemBreadcrumbs', () {
    testWidgets('renders a trail with a selected current item', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            width: 600,
            child: DesignSystemBreadcrumbs(
              items: [
                DesignSystemBreadcrumbItem(label: 'Home', onPressed: () {}),
                DesignSystemBreadcrumbItem(label: 'Projects', onPressed: () {}),
                const DesignSystemBreadcrumbItem(
                  label: 'Breadcrumbs',
                  selected: true,
                  showChevron: false,
                ),
              ],
            ),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final home = tester.widget<Text>(find.text('Home'));
      final current = tester.widget<Text>(find.text('Breadcrumbs'));

      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(2));
      expect(home.style?.color, dsTokensLight.colors.text.highEmphasis);
      expect(current.style?.color, dsTokensLight.colors.interactive.enabled);
    });

    testWidgets('renders hover and disabled styles from tokens', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DesignSystemBreadcrumbs(
                items: [
                  DesignSystemBreadcrumbItem(
                    label: 'Breadcrumb',
                    onPressed: () {},
                    forcedState: DesignSystemBreadcrumbVisualState.hover,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DesignSystemBreadcrumbs(
                items: const [
                  DesignSystemBreadcrumbItem(
                    label: 'Disabled',
                    enabled: false,
                  ),
                ],
              ),
            ],
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final hoverBackground = tester.widget<DecoratedBox>(
        find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color ==
                  dsTokensLight.colors.surface.enabled,
        ),
      );
      final disabledText = tester.widget<Text>(find.text('Disabled'));

      expect(
        (hoverBackground.decoration as BoxDecoration).color,
        dsTokensLight.colors.surface.enabled,
      );
      expect(disabledText.style?.color, dsTokensLight.colors.text.lowEmphasis);
    });

    testWidgets('InkWell wraps entire content row including chevron', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            width: 600,
            child: DesignSystemBreadcrumbs(
              items: [
                DesignSystemBreadcrumbItem(
                  label: 'Home',
                  onPressed: () {},
                  forcedState: DesignSystemBreadcrumbVisualState.hover,
                ),
              ],
            ),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      // The InkWell should wrap the full Row (label + chevron)
      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(inkWell.child, isA<Row>());
    });

    testWidgets('chevron is inside the interactive InkWell area', (
      tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            width: 600,
            child: DesignSystemBreadcrumbs(
              items: [
                DesignSystemBreadcrumbItem(
                  label: 'Home',
                  onPressed: () => tapped = true,
                ),
              ],
            ),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      // Tapping the chevron should also trigger the callback
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });
}
