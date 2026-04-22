import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_palette.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemListItem', () {
    testWidgets('renders title text', (tester) async {
      const itemKey = Key('basic-item');

      await _pumpListItem(
        tester,
        const DesignSystemListItem(
          key: itemKey,
          title: 'Item title',
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(itemKey),
          matching: find.text('Item title'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders title and subtitle for two-line variant', (
      tester,
    ) async {
      const itemKey = Key('two-line-item');

      await _pumpListItem(
        tester,
        const DesignSystemListItem(
          key: itemKey,
          title: 'Title',
          subtitle: 'Subtitle text',
        ),
      );

      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Subtitle text'), findsOneWidget);
    });

    testWidgets('renders custom title content and metadata spans', (
      tester,
    ) async {
      const itemKey = Key('rich-item');

      await _pumpListItem(
        tester,
        const DesignSystemListItem(
          key: itemKey,
          titleContent: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Projects'),
              SizedBox(width: 4),
              Icon(Icons.folder_open, size: 12),
            ],
          ),
          subtitleSpans: [
            TextSpan(text: '78'),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.format_list_bulleted_rounded, size: 12),
              ),
            ),
            TextSpan(text: ' 5 tasks'),
          ],
        ),
      );

      expect(find.text('Projects'), findsOneWidget);
      expect(find.byIcon(Icons.folder_open), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains('78') &&
              widget.text.toPlainText().contains('5 tasks'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders leading and trailing widgets', (tester) async {
      const itemKey = Key('slots-item');

      await _pumpListItem(
        tester,
        DesignSystemListItem(
          key: itemKey,
          title: 'With slots',
          leading: const Icon(Icons.person),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {},
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(itemKey),
          matching: find.byIcon(Icons.person),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(itemKey),
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders leading extra and trailing extra', (tester) async {
      const itemKey = Key('extra-slots');

      await _pumpListItem(
        tester,
        DesignSystemListItem(
          key: itemKey,
          title: 'Extras',
          leadingExtra: const Icon(Icons.circle, size: 8),
          leading: const Icon(Icons.person),
          trailing: const Icon(Icons.notifications),
          trailingExtra: const Icon(Icons.chevron_right),
          onTap: () {},
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(itemKey),
          matching: find.byIcon(Icons.circle),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(itemKey),
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows divider when showDivider is true', (tester) async {
      const itemKey = Key('divider-item');

      await _pumpListItem(
        tester,
        DesignSystemListItem(
          key: itemKey,
          title: 'With divider',
          showDivider: true,
          onTap: () {},
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(itemKey),
          matching: find.byType(Divider),
        ),
        findsOneWidget,
      );
    });

    testWidgets('does not show divider by default', (tester) async {
      const itemKey = Key('no-divider');

      await _pumpListItem(
        tester,
        DesignSystemListItem(
          key: itemKey,
          title: 'No divider',
          onTap: () {},
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(itemKey),
          matching: find.byType(Divider),
        ),
        findsNothing,
      );
    });

    testWidgets(
      'dividerColor overrides the default decorative colour while keeping '
      'the 1 px of reserved vertical space — used by list surfaces that '
      'want to mask the line without shifting layout on hover',
      (tester) async {
        const itemKey = Key('divider-color-item');

        await _pumpListItem(
          tester,
          DesignSystemListItem(
            key: itemKey,
            title: 'With masked divider',
            showDivider: true,
            dividerColor: Colors.transparent,
            onTap: () {},
          ),
        );

        final divider = tester.widget<Divider>(
          find.descendant(
            of: find.byKey(itemKey),
            matching: find.byType(Divider),
          ),
        );
        expect(divider.color, Colors.transparent);
        // Layout still reserves the 1 px the Divider takes up.
        expect(divider.height, 1);
        expect(divider.thickness, 1);
      },
    );

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;

      await _pumpListItem(
        tester,
        DesignSystemListItem(
          title: 'Tappable',
          onTap: () => tapped = true,
        ),
      );

      await tester.tap(find.text('Tappable'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets(
      'applies the subdued interactive.enabled @ 0.12 default for the '
      'activated background — same tint task-list rows use so the look '
      'stays consistent across the app',
      (tester) async {
        const itemKey = Key('activated-item');

        await _pumpListItem(
          tester,
          DesignSystemListItem(
            key: itemKey,
            title: 'Activated',
            activated: true,
            onTap: () {},
          ),
        );

        final ink = tester.widget<Ink>(
          find.descendant(
            of: find.byKey(itemKey),
            matching: find.byType(Ink),
          ),
        );
        final decoration = ink.decoration! as BoxDecoration;

        final expected = DesignSystemListPalette.activatedFill(dsTokensLight);
        expect(decoration.color, expected);
      },
    );

    testWidgets(
      'onHoverChanged fires when the pointer enters and leaves the row '
      'so parent lists can coordinate cross-row state such as hiding the '
      'divider below the currently-hovered item',
      (tester) async {
        const itemKey = Key('hover-item');
        final events = <bool>[];

        await _pumpListItem(
          tester,
          DesignSystemListItem(
            key: itemKey,
            title: 'Hoverable',
            onTap: () {},
            onHoverChanged: events.add,
          ),
        );

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer(location: Offset.zero);
        await gesture.moveTo(tester.getCenter(find.byKey(itemKey)));
        await tester.pumpAndSettle();
        await gesture.moveTo(const Offset(-100, -100));
        await tester.pumpAndSettle();

        expect(events, [true, false]);
      },
    );

    testWidgets(
      'onHoverChanged still fires when forcedState is set so parent lists '
      'can coordinate cross-row state even during previews that pin the '
      'internal visual state',
      (tester) async {
        const itemKey = Key('forced-hover-item');
        final events = <bool>[];

        await _pumpListItem(
          tester,
          DesignSystemListItem(
            key: itemKey,
            title: 'Forced idle, external hover',
            forcedState: DesignSystemListItemVisualState.idle,
            onTap: () {},
            onHoverChanged: events.add,
          ),
        );

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer(location: Offset.zero);
        await gesture.moveTo(tester.getCenter(find.byKey(itemKey)));
        await tester.pumpAndSettle();
        await gesture.moveTo(const Offset(-100, -100));
        await tester.pumpAndSettle();

        expect(events, [true, false]);
      },
    );

    testWidgets('uses overridden activated background color', (tester) async {
      const itemKey = Key('custom-activated-item');
      const activeColor = Colors.orange;

      await _pumpListItem(
        tester,
        const DesignSystemListItem(
          key: itemKey,
          title: 'Activated',
          activated: true,
          activatedBackgroundColor: activeColor,
        ),
      );

      final ink = tester.widget<Ink>(
        find.descendant(
          of: find.byKey(itemKey),
          matching: find.byType(Ink),
        ),
      );
      final decoration = ink.decoration! as BoxDecoration;

      expect(decoration.color, activeColor);
    });

    testWidgets('applies hover background via forced state', (tester) async {
      const itemKey = Key('hover-item');

      await _pumpListItem(
        tester,
        DesignSystemListItem(
          key: itemKey,
          title: 'Hovered',
          forcedState: DesignSystemListItemVisualState.hover,
          onTap: () {},
        ),
      );

      final ink = tester.widget<Ink>(
        find.descendant(
          of: find.byKey(itemKey),
          matching: find.byType(Ink),
        ),
      );
      final decoration = ink.decoration! as BoxDecoration;

      expect(decoration.color, dsTokensLight.colors.surface.hover);
    });

    testWidgets('applies disabled opacity when onTap is null', (
      tester,
    ) async {
      const itemKey = Key('disabled-item');

      await _pumpListItem(
        tester,
        const DesignSystemListItem(
          key: itemKey,
          title: 'Disabled',
          leading: Icon(Icons.person),
        ),
      );

      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byKey(itemKey),
          matching: find.byType(Opacity),
        ),
      );

      expect(opacity.opacity, dsTokensLight.colors.text.lowEmphasis.a);
    });

    testWidgets('provides semantics label', (tester) async {
      const itemKey = Key('semantics-item');

      await _pumpListItem(
        tester,
        DesignSystemListItem(
          key: itemKey,
          title: 'Item',
          semanticsLabel: 'Select item',
          onTap: () {},
        ),
      );

      final semantics = tester.widget<Semantics>(
        find.descendant(
          of: find.byKey(itemKey),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Select item',
          ),
        ),
      );

      expect(semantics.properties.label, 'Select item');
    });

    testWidgets('divider has default indent matching horizontal padding', (
      tester,
    ) async {
      const itemKey = Key('divider-indent-item');

      await _pumpListItem(
        tester,
        DesignSystemListItem(
          key: itemKey,
          title: 'With divider',
          showDivider: true,
          onTap: () {},
        ),
      );

      final divider = tester.widget<Divider>(
        find.descendant(
          of: find.byKey(itemKey),
          matching: find.byType(Divider),
        ),
      );

      // Default indent equals horizontal padding (step5 = 16)
      expect(divider.indent, dsTokensLight.spacing.step5);
    });

    testWidgets('divider uses custom dividerIndent when provided', (
      tester,
    ) async {
      const itemKey = Key('custom-divider-indent');
      const customIndent = 60.0;

      await _pumpListItem(
        tester,
        DesignSystemListItem(
          key: itemKey,
          title: 'Custom indent',
          showDivider: true,
          dividerIndent: customIndent,
          onTap: () {},
        ),
      );

      final divider = tester.widget<Divider>(
        find.descendant(
          of: find.byKey(itemKey),
          matching: find.byType(Divider),
        ),
      );

      expect(divider.indent, customIndent);
    });

    testWidgets('uses small size spec with reduced padding', (tester) async {
      const itemKey = Key('small-item');

      await _pumpListItem(
        tester,
        DesignSystemListItem(
          key: itemKey,
          title: 'Small',
          size: DesignSystemListItemSize.small,
          onTap: () {},
        ),
      );

      final padding = tester.widget<Padding>(
        find.descendant(
          of: find.byKey(itemKey),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Padding &&
                widget.padding ==
                    EdgeInsets.symmetric(
                      horizontal: dsTokensLight.spacing.step5,
                      vertical: dsTokensLight.spacing.step3,
                    ),
          ),
        ),
      );

      expect(
        padding.padding,
        EdgeInsets.symmetric(
          horizontal: dsTokensLight.spacing.step5,
          vertical: dsTokensLight.spacing.step3,
        ),
      );
    });
  });
}

Future<void> _pumpListItem(
  WidgetTester tester,
  Widget child,
) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      SizedBox(width: 400, child: child),
      theme: DesignSystemTheme.light(),
    ),
  );
}
