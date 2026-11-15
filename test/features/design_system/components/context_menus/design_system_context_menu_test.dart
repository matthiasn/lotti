import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_palette.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

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
              icon: LottiIcons.copy,
            ),
          ],
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(key),
          matching: find.byIcon(LottiIcons.copy),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'a row that starts a group gets a hairline above it, never the first',
      (tester) async {
        const key = Key('grouped-menu');

        await _pumpContextMenu(
          tester,
          const DesignSystemContextMenu(
            key: key,
            items: [
              DesignSystemContextMenuItem(label: 'Edit', startsGroup: true),
              DesignSystemContextMenuItem(label: 'Update now'),
              DesignSystemContextMenuItem(label: 'Delete', startsGroup: true),
            ],
          ),
        );

        final rules = find.descendant(
          of: find.byKey(key),
          matching: find.byType(Divider),
        );
        expect(rules, findsOneWidget);
        // The one rule sits between *Update now* and *Delete*.
        final ruleY = tester.getCenter(rules).dy;
        expect(
          ruleY,
          greaterThan(tester.getCenter(find.text('Update now')).dy),
        );
        expect(ruleY, lessThan(tester.getCenter(find.text('Delete')).dy));
      },
    );

    testWidgets(
      'a checked row draws its state in the icon slot and announces it',
      (tester) async {
        final semantics = tester.ensureSemantics();
        const key = Key('toggle-menu');

        await _pumpContextMenu(
          tester,
          DesignSystemContextMenu(
            key: key,
            items: [
              DesignSystemContextMenuItem(
                label: 'Automatic updates',
                checked: true,
                onTap: () {},
              ),
              DesignSystemContextMenuItem(
                label: 'Read aloud',
                checked: false,
                onTap: () {},
              ),
            ],
          ),
        );

        expect(find.byIcon(LottiIcons.checkboxChecked), findsOneWidget);
        expect(find.byIcon(LottiIcons.checkboxUnchecked), findsOneWidget);
        expect(
          tester.getSemantics(find.bySemanticsLabel('Automatic updates')),
          isSemantics(
            label: 'Automatic updates',
            isButton: true,
            hasCheckedState: true,
            isChecked: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
        expect(
          tester.getSemantics(find.bySemanticsLabel('Read aloud')),
          isSemantics(
            label: 'Read aloud',
            isButton: true,
            hasCheckedState: true,
            isChecked: false,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
        semantics.dispose();
      },
    );

    testWidgets(
      'a fitted menu is as wide as its longest row, capped at its width',
      (tester) async {
        await _pumpContextMenu(
          tester,
          const DesignSystemContextMenu(
            key: Key('fitted'),
            fitContent: true,
            items: [
              DesignSystemContextMenuItem(label: 'Edit', icon: LottiIcons.edit),
              DesignSystemContextMenuItem(
                label: 'Agent internals',
                icon: LottiIcons.tune,
              ),
            ],
          ),
        );

        final width = tester.getSize(find.byKey(const Key('fitted'))).width;
        expect(width, lessThan(DesignSystemContextMenu.defaultWidth));
        // Nothing is cut: the longest label keeps its full width.
        final label = tester.getRect(find.text('Agent internals'));
        final menu = tester.getRect(find.byKey(const Key('fitted')));
        expect(label.right, lessThanOrEqualTo(menu.right));
        expect(
          tester
              .renderObject<RenderParagraph>(find.text('Agent internals'))
              .didExceedMaxLines,
          isFalse,
        );
      },
    );

    testWidgets('a host can raise the surface off a dimmed page', (
      tester,
    ) async {
      const raised = Color(0xFF222222);
      await _pumpContextMenu(
        tester,
        const DesignSystemContextMenu(
          key: Key('raised'),
          surfaceColor: raised,
          items: [DesignSystemContextMenuItem(label: 'Edit')],
        ),
      );

      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const Key('raised')),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((box.decoration! as BoxDecoration).color, raised);
    });

    testWidgets('a long, scrolling menu keeps its group rules', (
      tester,
    ) async {
      await _pumpContextMenu(
        tester,
        DesignSystemContextMenu(
          key: const Key('long'),
          items: [
            for (var i = 0; i < 8; i++)
              DesignSystemContextMenuItem(label: 'Row $i', startsGroup: i == 2),
          ],
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(const Key('long')),
          matching: find.byType(ListView),
        ),
        findsOneWidget,
      );
      final rule = find.descendant(
        of: find.byKey(const Key('long')),
        matching: find.byType(Divider),
      );
      expect(rule, findsOneWidget);
      final y = tester.getCenter(rule).dy;
      expect(y, greaterThan(tester.getCenter(find.text('Row 1')).dy));
      expect(y, lessThan(tester.getCenter(find.text('Row 2')).dy));
    });

    testWidgets(
      'rows hover and press in the primary hue, flat, like the pickers',
      (tester) async {
        await _pumpContextMenu(
          tester,
          DesignSystemContextMenu(
            items: [DesignSystemContextMenuItem(label: 'Action', onTap: () {})],
          ),
        );

        final ink = tester.widget<InkWell>(
          find.ancestor(
            of: find.text('Action'),
            matching: find.byType(InkWell),
          ),
        );
        expect(
          ink.hoverColor,
          DesignSystemListPalette.hoverFill(dsTokensLight),
        );
        expect(
          ink.highlightColor,
          DesignSystemListPalette.pressedFill(dsTokensLight),
        );
        expect(ink.splashFactory, NoSplash.splashFactory);
        // No focus outline on a menu row, so focus must out-weigh hover.
        expect(ink.focusColor, dsTokensLight.colors.surface.focusPressed);
      },
    );

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

    testWidgets('exposes available and unavailable items as named buttons', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpContextMenu(
        tester,
        DesignSystemContextMenu(
          items: [
            DesignSystemContextMenuItem(label: 'Open', onTap: () {}),
            const DesignSystemContextMenuItem(label: 'Unavailable'),
          ],
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Open')),
        matchesSemantics(
          label: 'Open',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Unavailable')),
        matchesSemantics(
          label: 'Unavailable',
          isButton: true,
          hasEnabledState: true,
        ),
      );
      semantics.dispose();
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
        dsTokensLight.colors.alert.error.ink,
      );
    });

    testWidgets('applies card decoration with shadow and no border', (
      tester,
    ) async {
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

      expect(decoration.color, dsTokensLight.colors.background.level01);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(dsTokensLight.radii.s),
      );
      expect(decoration.boxShadow, isNotEmpty);
      expect(decoration.border, isNull);
    });

    testWidgets(
      'edge-to-edge items meet the clipped bottom edge and expose selection',
      (tester) async {
        const menuKey = Key('edge-menu');
        const lastItemKey = Key('last-item');
        final semantics = tester.ensureSemantics();

        await _pumpContextMenu(
          tester,
          const DesignSystemContextMenu(
            key: menuKey,
            header: 'Tue, Aug 11',
            items: [
              DesignSystemContextMenuItem(label: 'Success'),
              DesignSystemContextMenuItem(
                key: lastItemKey,
                label: 'No entry',
                icon: LottiIcons.radioUnselected,
                iconColor: Colors.grey,
                isSelected: true,
              ),
            ],
          ),
        );

        expect(
          tester.getRect(find.byKey(lastItemKey)).bottom,
          tester.getRect(find.byKey(menuKey)).bottom,
          reason: 'the last hover fill must reach the rounded menu edge',
        );
        expect(
          tester.getSemantics(find.bySemanticsLabel('No entry')),
          matchesSemantics(
            label: 'No entry',
            isButton: true,
            hasEnabledState: true,
            isSelected: true,
            hasSelectedState: true,
          ),
        );
        final icon = tester.widget<Icon>(
          find.descendant(
            of: find.byKey(lastItemKey),
            matching: find.byIcon(LottiIcons.radioUnselected),
          ),
        );
        expect(icon.color, Colors.grey);
        semantics.dispose();
      },
    );

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
            (widget) => widget is SizedBox && widget.height == kSmallItemHeight,
          ),
        ),
      );
      expect(sizedBox.height, kSmallItemHeight);
    });

    testWidgets('uses medium size spec by default', (tester) async {
      const key = Key('medium-menu');

      await _pumpContextMenu(
        tester,
        const DesignSystemContextMenu(
          key: key,
          items: [
            DesignSystemContextMenuItem(label: 'Medium item'),
          ],
        ),
      );

      // The non-small branch: row height and text style step up.
      final sizedBox = tester.widget<SizedBox>(
        find.ancestor(
          of: find.text('Medium item'),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SizedBox &&
                widget.height == dsTokensLight.spacing.step9,
          ),
        ),
      );
      expect(sizedBox.height, dsTokensLight.spacing.step9);

      final text = tester.widget<Text>(find.text('Medium item'));
      expect(
        text.style?.fontSize,
        dsTokensLight.typography.styles.body.bodyMedium.fontSize,
      );
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
