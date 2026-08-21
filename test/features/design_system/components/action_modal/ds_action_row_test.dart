import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

/// The wash the row paints behind itself, read off the [AnimatedContainer]
/// the row animates. Transparent means "no wash" — idle.
Color? _rowFill(WidgetTester tester) {
  final container = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.byType(DsActionRow),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return (container.decoration! as BoxDecoration).color;
}

/// The icon tile's fill — the [Container] wrapping the leading glyph.
BoxDecoration _tileDecoration(WidgetTester tester, IconData icon) {
  final container = tester.widget<Container>(
    find
        .ancestor(of: find.byIcon(icon), matching: find.byType(Container))
        .first,
  );
  return container.decoration! as BoxDecoration;
}

Future<void> _hover(WidgetTester tester, Finder finder) async {
  final pointer = TestPointer(1, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(
    pointer.hover(tester.getCenter(finder)),
  );
  await tester.pumpAndSettle();
}

/// The tokens the test theme actually resolved, rather than a hard-coded
/// brightness: the assertions below are about the row reading its palette
/// from the theme, not about which theme the harness picked.
DsTokens _tokens(WidgetTester tester) =>
    tester.element(find.byType(DsActionRow).first).designTokens;

void main() {
  group('DsActionRow content', () {
    testWidgets('renders title, subtitle, trailing value and glyph', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DsActionRow(
            icon: LottiIcons.language,
            title: 'Set language',
            subtitle: 'Drives transcription',
            trailingValue: 'English',
            trailing: DsActionRowTrailing.chevron,
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(LottiIcons.language), findsOneWidget);
      expect(find.text('Set language'), findsOneWidget);
      expect(find.text('Drives transcription'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.byIcon(LottiIcons.chevronRight), findsOneWidget);
    });

    testWidgets('omits the subtitle, value and glyph when not given', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DsActionRow(
            icon: LottiIcons.copy,
            title: 'Copy as text',
            onTap: () {},
          ),
        ),
      );

      // Exactly one Text — the title. A row that acts in place must not grow
      // a second line or a trailing glyph it has no meaning for.
      expect(
        find.descendant(
          of: find.byType(DsActionRow),
          matching: find.byType(Text),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(LottiIcons.chevronRight), findsNothing);
      expect(find.byIcon(LottiIcons.add), findsNothing);
    });

    testWidgets('the add trailing renders a plus, not a chevron', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DsActionRow(
            icon: LottiIcons.note,
            title: 'Write a note',
            subtitle: 'Adds a linked note',
            trailing: DsActionRowTrailing.add,
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(LottiIcons.add), findsOneWidget);
      expect(find.byIcon(LottiIcons.chevronRight), findsNothing);
    });

    testWidgets('title and subtitle come from the type scale', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DsActionRow(
            icon: LottiIcons.note,
            title: 'Write a note',
            subtitle: 'Adds a linked note',
            onTap: () {},
          ),
        ),
      );

      final title = tester.widget<Text>(find.text('Write a note'));
      final subtitle = tester.widget<Text>(find.text('Adds a linked note'));
      expect(title.style?.fontSize, _tokens(tester).typography.size.subtitle2);
      expect(
        title.style?.fontWeight,
        _tokens(tester).typography.weight.semiBold,
      );
      expect(subtitle.style?.fontSize, _tokens(tester).typography.size.caption);
      expect(subtitle.style?.color, _tokens(tester).colors.text.mediumEmphasis);
    });
  });

  group('DsActionRow tone', () {
    testWidgets('neutral tiles are the grey wash, accent tiles the teal', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Column(
            children: [
              DsActionRow(
                icon: LottiIcons.link,
                title: 'Link from',
                onTap: () {},
              ),
              DsActionRow(
                icon: LottiIcons.note,
                title: 'Write a note',
                tone: DsActionRowTone.accent,
                onTap: () {},
              ),
            ],
          ),
        ),
      );

      expect(
        _tileDecoration(tester, LottiIcons.link).color,
        _tokens(tester).colors.surface.enabled,
      );
      expect(
        tester.widget<Icon>(find.byIcon(LottiIcons.link)).color,
        _tokens(tester).colors.text.mediumEmphasis,
      );
      expect(
        _tileDecoration(tester, LottiIcons.note).color,
        _tokens(tester).colors.surface.selected,
      );
      expect(
        tester.widget<Icon>(find.byIcon(LottiIcons.note)).color,
        _tokens(tester).colors.interactive.enabled,
      );
    });

    testWidgets('the destructive tone inks title, glyph and tile in error', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DsActionRow(
            icon: LottiIcons.delete,
            title: 'Delete entry',
            tone: DsActionRowTone.destructive,
            onTap: () {},
          ),
        ),
      );

      final error = _tokens(tester).colors.alert.error.defaultColor;
      expect(
        tester.widget<Text>(find.text('Delete entry')).style?.color,
        error,
      );
      expect(tester.widget<Icon>(find.byIcon(LottiIcons.delete)).color, error);
      expect(
        _tileDecoration(tester, LottiIcons.delete).color,
        DsActionRowPalette.errorWash(_tokens(tester)),
      );
    });
  });

  group('DsActionRow interaction', () {
    testWidgets('taps fire the callback', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DsActionRow(
            icon: LottiIcons.copy,
            title: 'Copy as text',
            onTap: () => taps++,
          ),
        ),
      );

      await tester.tap(find.byType(DsActionRow));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('a null callback disables the row and dims it', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DsActionRow(
            icon: LottiIcons.copy,
            title: 'Copy as text',
            onTap: null,
          ),
        ),
      );

      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(DsActionRow),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, _tokens(tester).colors.text.lowEmphasis.a);
      expect(
        tester
            .widget<InkWell>(
              find.descendant(
                of: find.byType(DsActionRow),
                matching: find.byType(InkWell),
              ),
            )
            .onTap,
        isNull,
      );
    });

    testWidgets("hovering washes the row in the tone's hover fill", (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DsActionRow(
            icon: LottiIcons.link,
            title: 'Link from',
            onTap: () {},
          ),
        ),
      );

      expect(_rowFill(tester), Colors.transparent);
      await _hover(tester, find.byType(DsActionRow));
      expect(_rowFill(tester), _tokens(tester).colors.surface.hover);
    });

    testWidgets('a disabled row never washes', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DsActionRow(
            icon: LottiIcons.link,
            title: 'Link from',
            onTap: null,
          ),
        ),
      );

      await _hover(tester, find.byType(DsActionRow));
      expect(_rowFill(tester), Colors.transparent);
    });

    testWidgets('keyboard focus washes the row and draws a ring', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DsActionRow(
            icon: LottiIcons.link,
            title: 'Link from',
            onTap: () {},
          ),
        ),
      );

      BoxDecoration decoration() =>
          tester
                  .widget<AnimatedContainer>(
                    find.descendant(
                      of: find.byType(DsActionRow),
                      matching: find.byType(AnimatedContainer),
                    ),
                  )
                  .decoration!
              as BoxDecoration;

      expect(decoration().color, Colors.transparent);
      expect((decoration().border! as Border).top.color, Colors.transparent);

      // Tab, not a synthetic focus request: the transparent overlayColor means
      // Ink draws nothing for focus, so what a keyboard user actually sees is
      // the wash and ring below.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(decoration().color, _tokens(tester).colors.surface.focusPressed);
      expect(
        (decoration().border! as Border).top.color,
        _tokens(tester).colors.interactive.enabled,
      );
    });

    testWidgets('focus outranks a pointer resting on another row', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Column(
            children: [
              DsActionRow(
                icon: LottiIcons.link,
                title: 'Link from',
                onTap: () {},
              ),
              DsActionRow(
                icon: LottiIcons.focus,
                title: 'Link to',
                onTap: () {},
              ),
            ],
          ),
        ),
      );

      Color? fillAt(int index) =>
          ((tester
                      .widget<AnimatedContainer>(
                        find
                            .descendant(
                              of: find.byType(DsActionRow).at(index),
                              matching: find.byType(AnimatedContainer),
                            )
                            .first,
                      )
                      .decoration!)
                  as BoxDecoration)
              .color;

      await _hover(tester, find.byType(DsActionRow).first);
      expect(fillAt(0), _tokens(tester).colors.surface.hover);

      // Two tabs lands on the second row while the pointer stays on the first.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // The keyboard would activate row 1, so row 1 is the one that has to
      // look activatable.
      expect(fillAt(1), _tokens(tester).colors.surface.focusPressed);
    });

    testWidgets('the destructive row hovers in its own hue, not grey', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DsActionRow(
            icon: LottiIcons.delete,
            title: 'Delete entry',
            tone: DsActionRowTone.destructive,
            onTap: () {},
          ),
        ),
      );

      await _hover(tester, find.byType(DsActionRow));
      expect(_rowFill(tester), DsActionRowPalette.errorWash(_tokens(tester)));
      expect(_rowFill(tester), isNot(_tokens(tester).colors.surface.hover));
    });
  });

  group('DsActionRow geometry', () {
    testWidgets('rows own the gap below them, so a hidden sibling costs '
        'nothing', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Column(
            children: [
              DsActionRow(
                icon: LottiIcons.link,
                title: 'Link from',
                onTap: () {},
              ),
              const SizedBox.shrink(),
              DsActionRow(
                icon: LottiIcons.focus,
                title: 'Link to',
                onTap: () {},
              ),
            ],
          ),
        ),
      );

      final first = tester.getRect(find.byType(DsActionRow).first);
      final second = tester.getRect(find.byType(DsActionRow).at(1));
      // The rows abut: the 4pt gap lives inside the first row's own bounds.
      expect(second.top, first.bottom);
      // And the gap is really there, between the painted surfaces.
      final firstInk = tester.getRect(
        find
            .descendant(
              of: find.byType(DsActionRow).first,
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      expect(second.top - firstInk.bottom, _tokens(tester).spacing.step2);
    });

    testWidgets('a long trailing value truncates instead of overflowing', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            width: 200,
            child: DsActionRow(
              icon: LottiIcons.language,
              title: 'Set language',
              trailingValue:
                  'Nigerian Pidgin as spoken across the whole federation',
              trailing: DsActionRowTrailing.chevron,
              onTap: () {},
            ),
          ),
        ),
      );

      // A `Padding` is not a flex child: without the Flexible the Row hands
      // the value unbounded width, ellipsis has nothing to measure against,
      // and the row overflows rather than truncating.
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(DsActionRow)).width,
        lessThanOrEqualTo(200),
      );
      final value = tester.widget<Text>(
        find.textContaining('Nigerian Pidgin'),
      );
      expect(value.maxLines, 1);
      expect(value.overflow, TextOverflow.ellipsis);
    });

    testWidgets('the icon tile is a square of the design-system chip size', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DsActionRow(
            icon: LottiIcons.link,
            title: 'Link from',
            onTap: () {},
          ),
        ),
      );

      final tile = tester.getSize(
        find
            .ancestor(
              of: find.byIcon(LottiIcons.link),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(tile, const Size.square(ControlSizes.iconChip));
      expect(
        tester.widget<Icon>(find.byIcon(LottiIcons.link)).size,
        IconSizes.m,
      );
    });
  });
}
