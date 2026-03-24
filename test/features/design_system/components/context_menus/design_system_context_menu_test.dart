import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemContextMenu', () {
    testWidgets('renders all menu items', (tester) async {
      const key = Key('basic-menu');

      await _pumpContextMenu(
        tester,
        const DesignSystemContextMenu(
          key: key,
          items: [
            DesignSystemContextMenuItem(label: 'Copy'),
            DesignSystemContextMenuItem(label: 'Paste'),
            DesignSystemContextMenuItem(label: 'Cut'),
          ],
        ),
      );

      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Paste'), findsOneWidget);
      expect(find.text('Cut'), findsOneWidget);
    });

    testWidgets('renders items with icons', (tester) async {
      const key = Key('icon-menu');

      await _pumpContextMenu(
        tester,
        const DesignSystemContextMenu(
          key: key,
          items: [
            DesignSystemContextMenuItem(
              label: 'Copy',
              icon: Icons.copy,
            ),
          ],
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(key),
          matching: find.byIcon(Icons.copy),
        ),
        findsOneWidget,
      );
    });

    testWidgets('calls onTap when item is tapped', (tester) async {
      var tapped = false;

      await _pumpContextMenu(
        tester,
        DesignSystemContextMenu(
          items: [
            DesignSystemContextMenuItem(
              label: 'Action',
              onTap: () => tapped = true,
            ),
          ],
        ),
      );

      await tester.tap(find.text('Action'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('applies destructive color to destructive items', (
      tester,
    ) async {
      const key = Key('destructive-menu');

      await _pumpContextMenu(
        tester,
        const DesignSystemContextMenu(
          key: key,
          items: [
            DesignSystemContextMenuItem(label: 'Normal'),
            DesignSystemContextMenuItem(
              label: 'Delete',
              isDestructive: true,
            ),
          ],
        ),
      );

      final deleteText = tester.widget<Text>(find.text('Delete'));

      expect(
        deleteText.style?.color,
        dsTokensLight.colors.alert.error.defaultColor,
      );
    });

    testWidgets('applies card decoration with shadow', (tester) async {
      const key = Key('styled-menu');

      await _pumpContextMenu(
        tester,
        const DesignSystemContextMenu(
          key: key,
          items: [
            DesignSystemContextMenuItem(label: 'Item'),
          ],
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration! as BoxDecoration;

      expect(decoration.color, dsTokensLight.colors.surface.enabled);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(dsTokensLight.radii.s),
      );
      expect(decoration.boxShadow, isNotEmpty);
    });

    testWidgets('uses small size spec', (tester) async {
      const key = Key('small-menu');

      await _pumpContextMenu(
        tester,
        const DesignSystemContextMenu(
          key: key,
          size: DesignSystemContextMenuSize.small,
          items: [
            DesignSystemContextMenuItem(label: 'Small item'),
          ],
        ),
      );

      final sizedBox = tester.widget<SizedBox>(
        find.ancestor(
          of: find.text('Small item'),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SizedBox &&
                widget.height == dsTokensLight.spacing.step8,
          ),
        ),
      );
      expect(sizedBox.height, dsTokensLight.spacing.step8);
    });

    testWidgets('provides semantics label', (tester) async {
      const key = Key('semantics-menu');

      await _pumpContextMenu(
        tester,
        const DesignSystemContextMenu(
          key: key,
          semanticsLabel: 'File options',
          items: [
            DesignSystemContextMenuItem(label: 'Open'),
          ],
        ),
      );

      final semantics = tester.widget<Semantics>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'File options',
          ),
        ),
      );

      expect(semantics.properties.label, 'File options');
    });

    testWidgets('scrolls when more than 6 items', (tester) async {
      const key = Key('scroll-menu');

      await _pumpContextMenu(
        tester,
        DesignSystemContextMenu(
          key: key,
          items: List.generate(
            8,
            (i) => DesignSystemContextMenuItem(label: 'Item ${i + 1}'),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(ListView),
        ),
        findsOneWidget,
      );
    });
  });
}

Future<void> _pumpContextMenu(
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
