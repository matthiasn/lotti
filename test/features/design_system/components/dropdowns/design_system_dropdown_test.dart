import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/dropdowns/design_system_dropdown.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  _panelHeightGroup();

  // The app stacks these two components in both search sizes: the link modal
  // puts a dropdown above a *small* search field, the AI settings header puts
  // one under a *medium* one. They were built independently and diverged —
  // opaque `level01` at radius `xl` behind a 2px border against a translucent
  // overlay behind a hairline — so each pair read as two different products.
  // Nothing enforced the match, which is why it drifted; this is that
  // enforcement. It lives here rather than in the search test because the
  // dropdown is the side that moved.
  group('DesignSystemDropdown field surface matches DesignSystemSearch', () {
    // Both real pairings, so fixing one cannot leave the other mismatched.
    final pairings = [
      (
        'small (link modal)',
        DesignSystemSearchSize.small,
        DesignSystemDropdownSize.small,
        (DsTokens t) => t.radii.l,
      ),
      (
        'medium (AI settings header)',
        DesignSystemSearchSize.medium,
        DesignSystemDropdownSize.medium,
        (DsTokens t) => t.radii.m,
      ),
    ];

    for (final (name, theme, tokens) in [
      ('light', DesignSystemTheme.light(), dsTokensLight),
      ('dark', DesignSystemTheme.dark(), dsTokensDark),
    ]) {
      for (final (pairName, searchSize, dropdownSize, radius) in pairings) {
        testWidgets('$pairName in $name theme', (tester) async {
          await _pumpDropdown(
            tester,
            SizedBox(
              width: 320,
              child: Column(
                children: [
                  DesignSystemSearch(hintText: 'Search', size: searchSize),
                  DesignSystemDropdown(
                    label: 'Label',
                    inputLabel: 'Input',
                    size: dropdownSize,
                    items: const [
                      DesignSystemDropdownItem(id: 'a', label: 'Title'),
                    ],
                  ),
                ],
              ),
            ),
            theme: theme,
          );

          final field = _triggerDecoration(tester);
          final fieldShape = field.shape as RoundedRectangleBorder;
          final shell =
              tester
                      .widget<DecoratedBox>(
                        find.byKey(const Key('design-system-search-shell')),
                      )
                      .decoration
                  as BoxDecoration;

          expect(
            field.color,
            shell.color,
            reason: 'both fields must react to their host surface the same way',
          );
          expect(fieldShape.side.color, shell.border!.top.color);
          expect(fieldShape.side.width, shell.border!.top.width);
          expect(
            fieldShape.borderRadius,
            shell.borderRadius,
            reason: 'the stacked pair must read as one family',
          );
          // Pinned against the tokens too, so a change that moves *both* in
          // the same wrong direction still fails rather than agreeing
          // vacuously. Radius included: comparing only the two components
          // leaves them free to drift off the documented contract together.
          expect(field.color, tokens.colors.surface.enabled);
          expect(fieldShape.side.color, tokens.colors.decorative.level01);
          expect(fieldShape.side.width, tokens.spacing.step1 / 2);
          expect(
            fieldShape.borderRadius,
            BorderRadius.circular(radius(tokens)),
          );
        });
      }
    }
  });

  group('DesignSystemDropdown', () {
    testWidgets('renders the closed dropdown trigger from tokens', (
      tester,
    ) async {
      await _pumpDropdown(
        tester,
        SizedBox(
          width: 320,
          child: DesignSystemDropdown(
            label: 'Label',
            inputLabel: 'Input',
            items: _items(['Title']),
          ),
        ),
      );

      final decoration = _triggerDecoration(tester);
      final shape = decoration.shape as RoundedRectangleBorder;
      final labelText = _findTextNode(tester, 'Label');
      final inputText = _findTextNode(tester, 'Input');

      expect(_triggerSize(tester).height, 56);
      expect(decoration.color, dsTokensLight.colors.surface.enabled);
      expect(shape.side.color, dsTokensLight.colors.decorative.level01);
      expect(shape.side.width, dsTokensLight.spacing.step1 / 2);
      // Default size is medium, matching the field's own height and the
      // medium search field it pairs with in the AI settings header.
      expect(
        shape.borderRadius,
        BorderRadius.circular(dsTokensLight.radii.m),
      );
      expectTextStyle(
        labelText.text.style!,
        dsTokensLight.typography.styles.others.caption,
        dsTokensLight.colors.text.mediumEmphasis,
      );
      expectTextStyle(
        inputText.text.style!,
        // bodyMedium: the field's value must not outrank the content it
        // describes on hosting surfaces.
        dsTokensLight.typography.styles.body.bodyMedium,
        dsTokensLight.colors.text.highEmphasis,
      );
      expect(find.byIcon(LottiIcons.chevronDown), findsOneWidget);
      expect(find.byType(RawScrollbar), findsNothing);
    });

    testWidgets('opens the menu and notifies expansion changes', (
      tester,
    ) async {
      final expansionStates = <bool>[];

      await _pumpDropdown(
        tester,
        SizedBox(
          width: 320,
          child: DesignSystemDropdown(
            label: 'Label',
            inputLabel: 'Input',
            items: _items(['First option', 'Second option']),
            onExpandedChanged: expansionStates.add,
          ),
        ),
      );

      await tester.tap(find.text('Input'));
      await tester.pump();

      expect(expansionStates, [true]);
      expect(find.text('First option'), findsOneWidget);
      expect(find.byType(RawScrollbar), findsOneWidget);
    });

    testWidgets('calls the item callback and closes a single-select menu', (
      tester,
    ) async {
      DesignSystemDropdownItem? selectedItem;

      await _pumpDropdown(
        tester,
        SizedBox(
          width: 320,
          child: DesignSystemDropdown(
            label: 'Label',
            inputLabel: 'Input',
            initiallyExpanded: true,
            items: _items(['Alpha', 'Beta']),
            onItemPressed: (item) => selectedItem = item,
          ),
        ),
      );

      await tester.tap(find.text('Beta'));
      await tester.pump();

      expect(selectedItem?.id, 'item-1');
      expect(find.byType(RawScrollbar), findsNothing);
      expect(find.text('Beta'), findsNothing);
    });

    testWidgets('renders multiselect chips and selected rows from tokens', (
      tester,
    ) async {
      await _pumpDropdown(
        tester,
        const SizedBox(
          width: 320,
          child: DesignSystemDropdown(
            label: 'Label',
            inputLabel: 'Input',
            type: DesignSystemDropdownType.multiselect,
            initiallyExpanded: true,
            items: [
              DesignSystemDropdownItem(
                id: 'item-0',
                label: 'Title',
                chipLabel: 'Chip label',
                selected: true,
              ),
              DesignSystemDropdownItem(
                id: 'item-1',
                label: 'Title',
                chipLabel: 'Chip label',
              ),
            ],
          ),
        ),
      );

      expect(find.text('Chip label'), findsOneWidget);
      expect(find.byIcon(LottiIcons.confirm), findsOneWidget);
      expect(find.byType(RawScrollbar), findsOneWidget);
      expect(find.byType(DesignSystemDropdown), findsOneWidget);
    });

    testWidgets(
      'a single-choice list marks its current value, so an open list of '
      'similar options still states what is already chosen',
      (tester) async {
        await _pumpDropdown(
          tester,
          const SizedBox(
            width: 320,
            child: DesignSystemDropdown(
              label: 'Label',
              inputLabel: 'Blocks',
              initiallyExpanded: true,
              items: [
                DesignSystemDropdownItem(id: 'a', label: 'Blocks'),
                DesignSystemDropdownItem(
                  id: 'b',
                  label: 'Is blocked by',
                  selected: true,
                ),
                DesignSystemDropdownItem(id: 'c', label: 'Relates to'),
              ],
            ),
          ),
        );

        // Exactly one mark, on the selected row — not a checkbox column.
        expect(find.byIcon(LottiIcons.confirm), findsOneWidget);
        expect(
          find.descendant(
            of: find
                .ancestor(
                  of: find.text('Is blocked by'),
                  matching: find.byType(Row),
                )
                .first,
            matching: find.byIcon(LottiIcons.confirm),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('applies token-driven disabled opacity and blocks taps', (
      tester,
    ) async {
      final expansionStates = <bool>[];

      await _pumpDropdown(
        tester,
        SizedBox(
          width: 320,
          child: DesignSystemDropdown(
            label: 'Label',
            inputLabel: 'Input',
            enabled: false,
            items: _items(['Alpha']),
            onExpandedChanged: expansionStates.add,
          ),
        ),
      );

      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, dsTokensLight.colors.text.lowEmphasis.a);

      await tester.tap(find.text('Input'));
      await tester.pump();

      expect(expansionStates, isEmpty);
      expect(find.text('Alpha'), findsNothing);
    });

    testWidgets('collapses when disabled while expanded', (tester) async {
      var enabled = true;
      final expansionStates = <bool>[];

      await _pumpDropdown(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            return SizedBox(
              width: 320,
              child: Column(
                children: [
                  TextButton(
                    onPressed: () => setState(() => enabled = false),
                    child: const Text('Disable'),
                  ),
                  DesignSystemDropdown(
                    label: 'Label',
                    inputLabel: 'Input',
                    enabled: enabled,
                    initiallyExpanded: true,
                    items: _items(['Alpha']),
                    onExpandedChanged: expansionStates.add,
                  ),
                ],
              ),
            );
          },
        ),
      );

      expect(find.text('Alpha'), findsOneWidget);

      await tester.tap(find.text('Disable'));
      await tester.pump();

      expect(expansionStates, [false]);
      expect(find.text('Alpha'), findsNothing);
    });

    testWidgets('calls onChipRemoved when a chip is tapped', (tester) async {
      final removedItems = <DesignSystemDropdownItem>[];

      await _pumpDropdown(
        tester,
        SizedBox(
          width: 320,
          child: DesignSystemDropdown(
            label: 'Label',
            inputLabel: 'Input',
            type: DesignSystemDropdownType.multiselect,
            items: const [
              DesignSystemDropdownItem(
                id: 'a',
                label: 'Alpha',
                selected: true,
              ),
              DesignSystemDropdownItem(
                id: 'b',
                label: 'Beta',
                selected: true,
              ),
            ],
            onChipRemoved: removedItems.add,
          ),
        ),
      );

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);

      await tester.tap(find.text('Beta'));
      await tester.pump();

      expect(removedItems, hasLength(1));
      expect(removedItems.single.id, 'b');
    });

    testWidgets(
      'renders chip with resolvedChipLabel and checkbox for selected item',
      (tester) async {
        await _pumpDropdown(
          tester,
          const SizedBox(
            width: 320,
            child: DesignSystemDropdown(
              label: 'Label',
              inputLabel: 'Input',
              type: DesignSystemDropdownType.multiselect,
              initiallyExpanded: true,
              items: [
                DesignSystemDropdownItem(
                  id: 'item-0',
                  label: 'Full name',
                  chipLabel: 'Short',
                  selected: true,
                ),
                DesignSystemDropdownItem(
                  id: 'item-1',
                  label: 'Other',
                ),
              ],
            ),
          ),
        );

        // Chip shows chipLabel, not the full label
        expect(find.text('Short'), findsOneWidget);
        // Only the selected row shows a checkmark
        expect(find.byIcon(LottiIcons.confirm), findsOneWidget);
        // Both menu rows are visible
        expect(find.text('Full name'), findsOneWidget);
        expect(find.text('Other'), findsOneWidget);
      },
    );

    testWidgets('hides chip remove icon when onChipRemoved is null', (
      tester,
    ) async {
      await _pumpDropdown(
        tester,
        const SizedBox(
          width: 320,
          child: DesignSystemDropdown(
            label: 'Label',
            inputLabel: 'Input',
            type: DesignSystemDropdownType.multiselect,
            items: [
              DesignSystemDropdownItem(
                id: 'a',
                label: 'Alpha',
                selected: true,
              ),
            ],
          ),
        ),
      );

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.byIcon(LottiIcons.closeCircled), findsNothing);
    });

    testWidgets('exposes selected semantics on multiselect rows', (
      tester,
    ) async {
      await _pumpDropdown(
        tester,
        const SizedBox(
          width: 320,
          child: DesignSystemDropdown(
            label: 'Label',
            inputLabel: 'Input',
            type: DesignSystemDropdownType.multiselect,
            initiallyExpanded: true,
            items: [
              DesignSystemDropdownItem(
                id: 'a',
                label: 'Selected row',
                chipLabel: 'Sel chip',
                selected: true,
              ),
              DesignSystemDropdownItem(
                id: 'b',
                label: 'Unselected row',
              ),
            ],
          ),
        ),
      );

      final selectedSemantics = tester.getSemantics(
        find.text('Selected row'),
      );
      final unselectedSemantics = tester.getSemantics(
        find.text('Unselected row'),
      );

      expect(
        selectedSemantics.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expect(
        unselectedSemantics.getSemanticsData().flagsCollection.isSelected,
        Tristate.isFalse,
      );
    });

    testWidgets('uses the active dark theme tokens', (tester) async {
      await _pumpDropdown(
        tester,
        SizedBox(
          width: 320,
          child: DesignSystemDropdown(
            label: 'Label',
            inputLabel: 'Input',
            items: _items(['Title']),
          ),
        ),
        theme: DesignSystemTheme.dark(),
      );

      final decoration = _triggerDecoration(tester);
      final shape = decoration.shape as RoundedRectangleBorder;

      expect(decoration.color, dsTokensDark.colors.surface.enabled);
      expect(shape.side.color, dsTokensDark.colors.decorative.level01);
    });

    testWidgets('uses semanticsLabel when the visible label is omitted', (
      tester,
    ) async {
      await _pumpDropdown(
        tester,
        SizedBox(
          width: 320,
          child: DesignSystemDropdown(
            label: '',
            semanticsLabel: 'Project picker',
            inputLabel: 'Input',
            items: _items(['Title']),
          ),
        ),
      );

      final triggerSemantics = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Project picker',
        ),
      );

      expect(triggerSemantics.properties.label, 'Project picker');
    });

    testWidgets('menu panel shadow uses black-based color in dark mode', (
      tester,
    ) async {
      await _pumpDropdown(
        tester,
        SizedBox(
          width: 320,
          child: DesignSystemDropdown(
            label: 'Label',
            inputLabel: 'Input',
            initiallyExpanded: true,
            items: _items(['Alpha', 'Beta']),
          ),
        ),
        theme: DesignSystemTheme.dark(),
      );

      final panelDecoratedBox = tester.widget<DecoratedBox>(
        find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).boxShadow != null &&
              (widget.decoration as BoxDecoration).boxShadow!.isNotEmpty,
        ),
      );
      final decoration = panelDecoratedBox.decoration as BoxDecoration;
      final shadowColor = decoration.boxShadow!.first.color;

      // Shadow should be black-based, not a light decorative token
      expect(shadowColor.r, 0);
      expect(shadowColor.g, 0);
      expect(shadowColor.b, 0);
      expect(shadowColor.a, closeTo(0.25, 0.01));
    });

    test(
      'asserts when neither a visible label nor semanticsLabel is provided',
      () {
        expect(
          () => DesignSystemDropdown(
            label: '',
            inputLabel: 'Input',
            items: _items(['Title']),
          ),
          throwsAssertionError,
        );
      },
    );
  });
}

/// The open panel must end on a row boundary.
///
/// Its ceiling is computed from a size spec, while the row height comes from
/// whatever text style the rows actually render. When those two drift apart the
/// widget tree still looks right and the panel visibly slices its last option
/// through the glyphs — so this measures both from the laid-out result.
void _panelHeightGroup() {
  group('DesignSystemDropdown open panel', () {
    testWidgets(
      'the ceiling scales with the text size the rows render at — an unscaled '
      'ceiling stops mid-row exactly where enlarged text needs it not to',
      (tester) async {
        await _pumpDropdown(
          tester,
          const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: SizedBox(
              width: 320,
              child: DesignSystemDropdown(
                label: 'Label',
                inputLabel: 'Input',
                items: [
                  DesignSystemDropdownItem(id: 'a', label: 'Alpha'),
                  DesignSystemDropdownItem(id: 'b', label: 'Bravo'),
                  DesignSystemDropdownItem(id: 'c', label: 'Charlie'),
                  DesignSystemDropdownItem(id: 'd', label: 'Delta'),
                  DesignSystemDropdownItem(id: 'e', label: 'Echo'),
                  DesignSystemDropdownItem(id: 'f', label: 'Foxtrot'),
                  DesignSystemDropdownItem(id: 'g', label: 'Golf'),
                  DesignSystemDropdownItem(id: 'h', label: 'Hotel'),
                  DesignSystemDropdownItem(id: 'i', label: 'India'),
                ],
              ),
            ),
          ),
        );

        await tester.tap(find.text('Input'));
        await tester.pumpAndSettle();

        final rowHeight =
            tester.getTopLeft(find.text('Bravo')).dy -
            tester.getTopLeft(find.text('Alpha')).dy;
        final viewportHeight = tester
            .getSize(
              find
                  .ancestor(
                    of: find.text('Alpha'),
                    matching: find.byType(ListView),
                  )
                  .first,
            )
            .height;

        // A tolerance, not equality: the scaled row height is a float, so an
        // exact modulo leaves sub-picometre residue that means nothing.
        expect(
          viewportHeight % rowHeight,
          closeTo(0, 0.01),
          reason:
              'at 1.6x the panel is $viewportHeight tall against $rowHeight '
              'rows — the last option is cut through its glyphs',
        );
      },
    );

    testWidgets(
      'shows whole options — the scroll viewport is an exact multiple of the '
      'height its rows actually render at',
      (tester) async {
        await _pumpDropdown(
          tester,
          SizedBox(
            width: 320,
            child: DesignSystemDropdown(
              label: 'Label',
              inputLabel: 'Input',
              // More options than the panel can show, so it is at its ceiling.
              items: _items([
                'Alpha',
                'Bravo',
                'Charlie',
                'Delta',
                'Echo',
                'Foxtrot',
                'Golf',
                'Hotel',
                'India',
              ]),
            ),
          ),
        );

        await tester.tap(find.text('Input'));
        await tester.pumpAndSettle();

        // The pitch between two adjacent options is the row height, whatever
        // the size spec believes it to be.
        final rowHeight =
            tester.getTopLeft(find.text('Bravo')).dy -
            tester.getTopLeft(find.text('Alpha')).dy;
        final viewportHeight = tester
            .getSize(
              find
                  .ancestor(
                    of: find.text('Alpha'),
                    matching: find.byType(ListView),
                  )
                  .first,
            )
            .height;

        expect(
          viewportHeight % rowHeight,
          0,
          reason:
              'panel is $viewportHeight tall but rows are $rowHeight — the '
              'last visible option is cut through its glyphs',
        );
      },
    );
  });
}

Future<void> _pumpDropdown(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      child,
      theme: theme ?? DesignSystemTheme.light(),
    ),
  );
}

List<DesignSystemDropdownItem> _items(List<String> labels) {
  return [
    for (var index = 0; index < labels.length; index++)
      DesignSystemDropdownItem(
        id: 'item-$index',
        label: labels[index],
      ),
  ];
}

ShapeDecoration _triggerDecoration(WidgetTester tester) {
  final ink = tester.widget<Ink>(find.byType(Ink).first);
  return ink.decoration! as ShapeDecoration;
}

Size _triggerSize(WidgetTester tester) {
  return tester.getSize(
    find.byKey(const ValueKey('design-system-dropdown-trigger')),
  );
}

RichText _findTextNode(WidgetTester tester, String label) {
  return tester.widget<RichText>(
    find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText() == label,
    ),
  );
}
