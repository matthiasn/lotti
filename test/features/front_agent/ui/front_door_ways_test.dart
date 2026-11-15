import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/ui/front_door_ways.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  late List<String> acted;

  setUp(() => acted = []);

  FrontDoorWay way(String name, {bool enabled = true}) => FrontDoorWay(
    name: name,
    label: 'Label $name',
    hint: 'Hint $name',
    icon: LottiIcons.note,
    onTap: enabled ? () => acted.add(name) : null,
  );

  Future<void> pump(
    WidgetTester tester, {
    List<FrontDoorWay>? ways,
    double textScale = 1,
    bool scrolled = false,
  }) async {
    final list = FrontDoorWays(
      index: 3,
      ways: ways ?? [way('goal'), way('note')],
      leave: FrontDoorWay(
        name: 'decline',
        label: 'Leave it',
        hint: 'Nothing is made',
        icon: LottiIcons.inbox,
        onTap: () => acted.add('decline'),
      ),
      onClose: () => acted.add('close'),
    );
    await tester.pumpWidget(
      makeTestableWidget(
        MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: scrolled
              ? SizedBox(
                  height: 300,
                  child: SingleChildScrollView(
                    key: const ValueKey('view'),
                    // Taller than the view: the list starts below its fold.
                    child: Column(
                      children: [const SizedBox(height: 600), list],
                    ),
                  ),
                )
              : list,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder row(String name) => find.byKey(ValueKey('front-door-$name-3'));
  Color? inkOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

  group('FrontDoorWays', () {
    testWidgets('lists each way as its name over what it does, under the '
        'heading, with leaving it last', (tester) async {
      await pump(tester);

      expect(
        find.byKey(const ValueKey('front-door-ways-heading-3')),
        findsOneWidget,
      );
      final tops = [
        for (final text in [
          'Or make it something else',
          'Label goal',
          'Hint goal',
          'Label note',
          'Hint note',
          'Leave it',
          'Nothing is made',
        ])
          tester.getTopLeft(find.text(text)).dy,
      ];
      expect(tops, [...tops]..sort());
      expect(tops.toSet(), hasLength(tops.length));
    });

    testWidgets('a tap takes the way it lands on', (tester) async {
      await pump(tester);

      await tester.tap(row('note'));
      await tester.tap(find.text('Hint goal'));
      await tester.tap(row('decline'));

      expect(acted, ['note', 'goal', 'decline']);
    });

    testWidgets('a way with nothing to do is announced disabled and takes '
        'no tap', (tester) async {
      await pump(tester, ways: [way('goal', enabled: false)]);

      await tester.tap(row('goal'));

      expect(acted, isEmpty);
      expect(
        tester.getSemantics(row('goal')),
        isSemantics(
          label: 'Label goal. Hint goal',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
    });

    testWidgets('a way is announced as one button: its name, then what it '
        'does', (tester) async {
      await pump(tester);

      expect(
        tester.getSemantics(row('note')),
        isSemantics(
          label: 'Label note. Hint note',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
    });

    testWidgets('three levels: a way leads with its name, strong and '
        'heavier than what it does; the label over them is quiet; leaving it '
        'is the quiet last', (tester) async {
      await pump(tester);

      final tokens = tester.element(find.byType(FrontDoorWays)).designTokens;
      final styles = tokens.typography.styles;
      TextStyle styleOf(String text) =>
          tester.widget<Text>(find.text(text)).style!;

      expect(inkOf(tester, 'Label note'), tokens.colors.text.highEmphasis);
      expect(
        styleOf('Label note').fontWeight,
        styles.subtitle.subtitle2.fontWeight,
      );
      expect(
        styleOf('Label note').fontWeight!.value,
        greaterThan(styleOf('Hint note').fontWeight!.value),
      );
      for (final quiet in [
        'Hint note',
        'Or make it something else',
        'Leave it',
        'Nothing is made',
      ]) {
        expect(
          inkOf(tester, quiet),
          tokens.colors.text.mediumEmphasis,
          reason: quiet,
        );
      }
      expect(
        styleOf('Leave it').fontWeight,
        styles.body.bodySmall.fontWeight,
      );
    });

    testWidgets('a way that makes something wears a tile, as the item '
        'does; leaving it wears none', (tester) async {
      await pump(tester);

      BoxDecoration tile(String name) =>
          tester
                  .widget<Container>(
                    find.byKey(ValueKey('front-door-$name-tile-3')),
                  )
                  .decoration!
              as BoxDecoration;
      final tokens = tester.element(find.byType(FrontDoorWays)).designTokens;

      expect(tile('note').color, tokens.colors.surface.enabled);
      expect(tile('goal').color, tokens.colors.surface.enabled);
      expect(tile('decline').color, isNull);
      expect(
        tester.getSize(find.byKey(const ValueKey('front-door-note-tile-3'))),
        const Size.square(ControlSizes.iconChipCompact),
      );
      // The glyphs: strong on a tile, quiet without one.
      final glyphs = tester.widgetList<Icon>(find.byType(Icon)).toList();
      expect(glyphs.first.color, tokens.colors.text.highEmphasis);
      expect(glyphs.last.color, tokens.colors.text.mediumEmphasis);
    });

    testWidgets('leaving it is set apart: further from the last way than '
        'the ways are from each other', (tester) async {
      await pump(tester);

      final pitch =
          tester.getTopLeft(row('note')).dy - tester.getTopLeft(row('goal')).dy;
      final apart =
          tester.getTopLeft(row('decline')).dy -
          tester.getTopLeft(row('note')).dy;
      expect(apart, greaterThan(pitch));
    });

    testWidgets("a way's tile is centred on its two lines, at any text "
        'size', (tester) async {
      for (final scale in [1.0, 2.0]) {
        await pump(tester, ways: [way('note')], textScale: scale);

        final name = tester.getRect(find.text('Label note'));
        final hint = tester.getRect(find.text('Hint note'));
        final tile = tester.getCenter(
          find.byKey(const ValueKey('front-door-note-tile-3')),
        );
        expect(
          tile.dy,
          moreOrLessEquals((name.top + hint.bottom) / 2, epsilon: 1),
          reason: 'scale $scale',
        );
      }
    });

    testWidgets('Escape closes the list', (tester) async {
      await pump(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);

      expect(acted, ['close']);
    });

    testWidgets('Escape closes it from a row that holds focus too', (
      tester,
    ) async {
      await pump(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        isNot('front-door-ways'),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);

      expect(acted, ['close']);
    });

    testWidgets(
      "a way's glyph grows with the text, short of filling the tile's "
      'column',
      (tester) async {
        final sizes = <double, double?>{};
        for (final scale in [1.0, 1.25, 3.0]) {
          await pump(tester, ways: [way('note')], textScale: scale);
          sizes[scale] = tester.widget<Icon>(find.byIcon(LottiIcons.note)).size;
        }

        expect(sizes, {
          1.0: IconSizes.s,
          1.25: IconSizes.s * 1.25,
          3.0: IconSizes.l,
        });
      },
    );

    testWidgets('the heading stands further from what is over it than '
        'from the ways it heads', (tester) async {
      await pump(tester);

      final heading = tester.getRect(find.text('Or make it something else'));
      final list = tester.getRect(find.byType(FrontDoorWays));
      final first = tester.getRect(find.text('Label goal'));
      expect(heading.top - list.top, greaterThan(first.top - heading.bottom));
      // And further than the ways stand from each other.
      final second = tester.getRect(find.text('Label note'));
      final hint = tester.getRect(find.text('Hint goal'));
      expect(
        heading.top - list.top,
        greaterThanOrEqualTo(second.top - hint.bottom),
      );
    });

    testWidgets('no other key does, nor Escape let go', (tester) async {
      await pump(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);

      expect(acted, isEmpty);
    });

    testWidgets('Escape pressed while focus is elsewhere is not its own', (
      tester,
    ) async {
      final other = FocusNode();
      addTearDown(other.dispose);
      await tester.pumpWidget(
        makeTestableWidget(
          Column(
            children: [
              Focus(focusNode: other, child: const SizedBox.square()),
              FrontDoorWays(
                index: 3,
                ways: [way('note')],
                leave: way('decline'),
                onClose: () => acted.add('close'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      other.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);

      expect(acted, isEmpty);
    });

    testWidgets('opened below the fold, it is brought into view', (
      tester,
    ) async {
      await pump(tester, scrolled: true);

      final view = tester.getRect(find.byKey(const ValueKey('view')));
      final list = tester.getRect(find.byType(FrontDoorWays));
      expect(list.bottom, lessThanOrEqualTo(view.bottom));
      expect(list.top, greaterThanOrEqualTo(view.top));
    });
  });

  group('FrontDoorWaysScope', () {
    FrontDoorWaysScope scope({required String label, required Widget child}) =>
        FrontDoorWaysScope(
          index: 3,
          waysFor: (picked) => [
            for (final name in picked ?? ['every'])
              FrontDoorWay(
                name: name,
                label: label,
                hint: 'hint',
                icon: LottiIcons.code,
                onTap: null,
              ),
          ],
          leave: way('decline'),
          onClose: () => acted.add('close'),
          child: child,
        );

    testWidgets('gives what the card offers for the ways picked, and what '
        'it offers now after the card rebuilt', (tester) async {
      var builds = 0;
      final reader = Builder(
        builder: (context) {
          builds++;
          final scope = FrontDoorWaysScope.of(context);
          scope.onClose();
          final said = [
            for (final way in scope.waysFor(const ['goal'])) way.label,
            for (final way in scope.waysFor(null)) way.name,
            scope.leave.name,
            '${scope.index}',
          ];
          return Text(said.join(' '), textDirection: TextDirection.ltr);
        },
      );

      await tester.pumpWidget(scope(label: 'then', child: reader));
      expect(find.text('then every decline 3'), findsOne);

      // The same reader under a card built anew: it reads the new ways.
      await tester.pumpWidget(scope(label: 'now', child: reader));
      expect(find.text('now every decline 3'), findsOne);
      expect(builds, 2);
      expect(acted, ['close', 'close']);
    });
  });

  group('FrontDoorWaysToggle', () {
    final toggleNode = find
        .descendant(
          of: find.byType(FrontDoorWaysToggle),
          matching: find.byType(Semantics),
        )
        .first;
    Future<void> pumpToggle(
      WidgetTester tester, {
      required bool open,
      bool enabled = true,
    }) => tester.pumpWidget(
      makeTestableWidget(
        FrontDoorWaysToggle(
          open: open,
          onPressed: enabled ? () => acted.add('toggle') : null,
        ),
      ),
    );

    testWidgets('closed, it points down and says what it opens', (
      tester,
    ) async {
      await pumpToggle(tester, open: false);

      expect(find.byIcon(LottiIcons.chevronDown), findsOneWidget);
      expect(find.byTooltip('Or make it something else'), findsOneWidget);
      expect(
        tester.getSemantics(toggleNode),
        isSemantics(
          label: 'Or make it something else',
          isButton: true,
          hasExpandedState: true,
          isExpanded: false,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      await tester.tap(find.byType(FrontDoorWaysToggle));
      expect(acted, ['toggle']);
    });

    testWidgets('open, it points up, in the stronger ink', (tester) async {
      await pumpToggle(tester, open: false);
      final closedInk = tester
          .widget<Icon>(find.byIcon(LottiIcons.chevronDown))
          .color;
      await pumpToggle(tester, open: true);

      final glyph = tester.widget<Icon>(find.byIcon(LottiIcons.chevronUp));
      expect(glyph.color, isNot(closedInk));
      expect(
        glyph.color,
        tester
            .element(find.byType(FrontDoorWaysToggle))
            .designTokens
            .colors
            .text
            .highEmphasis,
      );
      expect(
        tester.getSemantics(toggleNode),
        isSemantics(
          label: 'Or make it something else',
          isButton: true,
          hasExpandedState: true,
          isExpanded: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
    });

    testWidgets('its chevron grows with the text, within its slot', (
      tester,
    ) async {
      final sizes = <double, double?>{};
      for (final scale in [1.0, 1.25, 3.0]) {
        await tester.pumpWidget(
          makeTestableWidget(
            MediaQuery.withClampedTextScaling(
              minScaleFactor: scale,
              maxScaleFactor: scale,
              child: FrontDoorWaysToggle(open: false, onPressed: () {}),
            ),
          ),
        );
        sizes[scale] = tester
            .widget<IconButton>(find.byType(IconButton))
            .iconSize;
      }

      expect(sizes, {
        1.0: IconSizes.m,
        1.25: IconSizes.m * 1.25,
        3.0: IconSizes.l,
      });
    });

    testWidgets('is a full touch target', (tester) async {
      await pumpToggle(tester, open: false);

      final size = tester.getSize(find.byType(FrontDoorWaysToggle));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('with nothing to press it takes no tap', (tester) async {
      await pumpToggle(tester, open: false, enabled: false);

      await tester.tap(find.byType(FrontDoorWaysToggle));

      expect(acted, isEmpty);
    });
  });
}
