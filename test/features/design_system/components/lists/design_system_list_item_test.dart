import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list_corners.dart';
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

    testWidgets('title line cap can be removed for accessible wrapping', (
      tester,
    ) async {
      const title = 'A deliberately long title that should wrap freely';
      await _pumpListItem(
        tester,
        const DesignSystemListItem(
          title: title,
          titleMaxLines: null,
        ),
      );

      final text = tester.widget<Text>(find.text(title));
      expect(text.maxLines, isNull);
      expect(text.overflow, TextOverflow.clip);
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

    testWidgets(
      'subtitle defaults to single-line ellipsis so legacy callers '
      "don't suddenly grow vertically",
      (tester) async {
        await _pumpListItem(
          tester,
          const DesignSystemListItem(
            title: 'Title',
            subtitle:
                'A reasonably long description that would otherwise '
                'wrap onto multiple lines if the cap were lifted',
          ),
        );

        final subtitle = tester.widget<Text>(
          find.text(
            'A reasonably long description that would otherwise wrap '
            'onto multiple lines if the cap were lifted',
          ),
        );
        expect(subtitle.maxLines, 1);
        expect(subtitle.overflow, TextOverflow.ellipsis);
      },
    );

    testWidgets(
      'subtitleMaxLines: null lifts the cap and lets long descriptions '
      'wrap freely',
      (tester) async {
        await _pumpListItem(
          tester,
          const DesignSystemListItem(
            title: 'Title',
            subtitle: 'A long description that should be allowed to wrap',
            subtitleMaxLines: null,
          ),
        );

        final subtitle = tester.widget<Text>(
          find.text('A long description that should be allowed to wrap'),
        );
        expect(subtitle.maxLines, isNull);
        expect(subtitle.overflow, TextOverflow.clip);
      },
    );

    testWidgets('subtitleMaxLines also honored on the subtitleSpans path', (
      tester,
    ) async {
      await _pumpListItem(
        tester,
        const DesignSystemListItem(
          title: 'Title',
          subtitleSpans: [TextSpan(text: 'inline')],
          subtitleMaxLines: 3,
        ),
      );

      final richText = tester.widget<RichText>(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('inline'),
        ),
      );
      expect(richText.maxLines, 3);
      expect(richText.overflow, TextOverflow.ellipsis);
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

        final expected = DesignSystemListPalette.activatedFill(dsTokensLight);
        expect(_inkDecoration(tester, itemKey).color, expected);
      },
    );

    // onHoverChanged must fire [true, false] across the pointer enter/leave
    // cycle regardless of whether the internal visual state is free-running
    // or pinned via forcedState, so parent lists can coordinate cross-row
    // state (e.g. hiding the divider below the hovered item) even during
    // previews. Parameterised over the forcedState dimension to avoid two
    // near-identical bodies.
    for (final forcedState in <DesignSystemListItemVisualState?>[
      null,
      DesignSystemListItemVisualState.idle,
    ]) {
      testWidgets(
        'onHoverChanged fires [true, false] on enter/leave '
        '(forcedState: $forcedState)',
        (tester) async {
          const itemKey = Key('hover-item');
          final events = <bool>[];

          await _pumpListItem(
            tester,
            DesignSystemListItem(
              key: itemKey,
              title: 'Hoverable',
              forcedState: forcedState,
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
          await tester.pump();
          await gesture.moveTo(const Offset(-100, -100));
          await tester.pump();

          expect(events, [true, false]);
        },
      );
    }

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

      expect(_inkDecoration(tester, itemKey).color, activeColor);
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

      expect(
        _inkDecoration(tester, itemKey).color,
        dsTokensLight.colors.surface.hover,
      );
    });

    testWidgets('applies pressed background via forced state', (tester) async {
      const itemKey = Key('pressed-item');

      await _pumpListItem(
        tester,
        DesignSystemListItem(
          key: itemKey,
          title: 'Pressed',
          forcedState: DesignSystemListItemVisualState.pressed,
          onTap: () {},
        ),
      );

      expect(
        _inkDecoration(tester, itemKey).color,
        dsTokensLight.colors.surface.focusPressed,
      );
    });

    testWidgets('uses overridden pressed background color', (tester) async {
      const itemKey = Key('custom-pressed-item');
      const pressedColor = Colors.purple;

      await _pumpListItem(
        tester,
        DesignSystemListItem(
          key: itemKey,
          title: 'Pressed',
          forcedState: DesignSystemListItemVisualState.pressed,
          pressedBackgroundColor: pressedColor,
          onTap: () {},
        ),
      );

      expect(_inkDecoration(tester, itemKey).color, pressedColor);
    });

    testWidgets(
      'excludeFromSemantics removes the internal semantics node while the '
      'row stays visible',
      (tester) async {
        const itemKey = Key('exclude-semantics-item');
        final handle = tester.ensureSemantics();
        // The inner label merges with the row text, so match a substring.
        final label = RegExp('Row label');

        await _pumpListItem(
          tester,
          DesignSystemListItem(
            key: itemKey,
            title: 'Row',
            semanticsLabel: 'Row label',
            onTap: () {},
          ),
        );
        expect(find.bySemanticsLabel(label), findsOneWidget);

        await _pumpListItem(
          tester,
          DesignSystemListItem(
            key: itemKey,
            title: 'Row',
            semanticsLabel: 'Row label',
            excludeFromSemantics: true,
            onTap: () {},
          ),
        );
        expect(find.bySemanticsLabel(label), findsNothing);
        expect(find.text('Row'), findsOneWidget);

        handle.dispose();
      },
    );

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

    testWidgets(
      'real keyboard focus paints the accent border and reports '
      'onFocusChanged on gain and loss',
      (tester) async {
        const itemKey = Key('keyboard-focus-item');
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);
        final events = <bool>[];

        await _pumpListItem(
          tester,
          DesignSystemListItem(
            key: itemKey,
            title: 'Focusable',
            focusNode: focusNode,
            onTap: () {},
            onFocusChanged: events.add,
          ),
        );

        focusNode.requestFocus();
        await tester.pump();
        expect(events, [true]);
        expect(
          _inkDecoration(tester, itemKey).border!.top.color,
          dsTokensLight.colors.interactive.enabled,
        );

        focusNode.unfocus();
        await tester.pump();
        expect(events, [true, false]);
        // The focus-loss callback lands after the first frame; one more
        // frame renders the reverted border.
        await tester.pump();
        expect(
          _inkDecoration(tester, itemKey).border!.top.color,
          Colors.transparent,
        );
      },
    );

    testWidgets(
      'changing forcedState clears stale transient focus visuals',
      (tester) async {
        const itemKey = Key('reset-item');
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);

        Future<void> pump(DesignSystemListItemVisualState? forcedState) {
          return _pumpListItem(
            tester,
            DesignSystemListItem(
              key: itemKey,
              title: 'Resettable',
              focusNode: focusNode,
              forcedState: forcedState,
              onTap: () {},
            ),
          );
        }

        await pump(null);
        focusNode.requestFocus();
        await tester.pump();
        expect(
          _inkDecoration(tester, itemKey).border!.top.color,
          dsTokensLight.colors.interactive.enabled,
        );

        await pump(DesignSystemListItemVisualState.idle);
        expect(
          _inkDecoration(tester, itemKey).border!.top.color,
          Colors.transparent,
        );

        // Back to free-running: the reset cleared the stale focus flag, so
        // the border stays idle even though the node itself kept focus.
        await pump(null);
        expect(focusNode.hasFocus, isTrue);
        expect(
          _inkDecoration(tester, itemKey).border!.top.color,
          Colors.transparent,
        );
      },
    );

    testWidgets(
      'focus border stays square outside a grouped list',
      (tester) async {
        const itemKey = Key('ungrouped-focused-item');

        await _pumpListItem(
          tester,
          DesignSystemListItem(
            key: itemKey,
            title: 'Focused',
            forcedState: DesignSystemListItemVisualState.focused,
            onTap: () {},
          ),
        );

        expect(_inkDecoration(tester, itemKey).borderRadius, isNull);
      },
    );

    testWidgets(
      'focus border follows the grouped-list corner scope so it is not '
      'cropped by the group clip',
      (tester) async {
        const itemKey = Key('grouped-focused-item');
        final corners = BorderRadius.vertical(
          top: Radius.circular(dsTokensLight.radii.m),
        );

        await _pumpListItem(
          tester,
          DesignSystemGroupedListCorners(
            borderRadius: corners,
            child: DesignSystemListItem(
              key: itemKey,
              title: 'Focused edge row',
              forcedState: DesignSystemListItemVisualState.focused,
              onTap: () {},
            ),
          ),
        );

        final decoration = _inkDecoration(tester, itemKey);
        expect(decoration.borderRadius, corners);
        expect(
          decoration.border!.top.color,
          dsTokensLight.colors.interactive.enabled,
        );
      },
    );

    testWidgets(
      'focused edge row inside a real DesignSystemGroupedList rounds to '
      'the group corner radius',
      (tester) async {
        const firstKey = Key('grouped-list-first-item');

        await _pumpListItem(
          tester,
          DesignSystemGroupedList(
            padding: EdgeInsets.zero,
            children: [
              DesignSystemListItem(
                key: firstKey,
                title: 'First',
                forcedState: DesignSystemListItemVisualState.focused,
                onTap: () {},
              ),
              DesignSystemListItem(title: 'Last', onTap: () {}),
            ],
          ),
        );

        final decoration = _inkDecoration(tester, firstKey);
        expect(
          decoration.borderRadius,
          BorderRadius.vertical(top: Radius.circular(dsTokensLight.radii.m)),
        );
        expect(
          decoration.border!.top.color,
          dsTokensLight.colors.interactive.enabled,
        );
      },
    );

    testWidgets(
      'state fill also rounds to the corner scope when the row is not '
      'focused',
      (tester) async {
        const itemKey = Key('grouped-hover-item');
        final corners = BorderRadius.vertical(
          bottom: Radius.circular(dsTokensLight.radii.m),
        );

        await _pumpListItem(
          tester,
          DesignSystemGroupedListCorners(
            borderRadius: corners,
            child: DesignSystemListItem(
              key: itemKey,
              title: 'Hovered edge row',
              forcedState: DesignSystemListItemVisualState.hover,
              onTap: () {},
            ),
          ),
        );

        final decoration = _inkDecoration(tester, itemKey);
        expect(decoration.borderRadius, corners);
        expect(decoration.border!.top.color, Colors.transparent);
      },
    );

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

BoxDecoration _inkDecoration(WidgetTester tester, Key itemKey) {
  final ink = tester.widget<Ink>(
    find.descendant(
      of: find.byKey(itemKey),
      matching: find.byType(Ink),
    ),
  );
  return ink.decoration! as BoxDecoration;
}
