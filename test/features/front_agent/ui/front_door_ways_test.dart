import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_palette.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/ui/front_door_ways.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  late List<String> acted;

  setUp(() => acted = []);

  FrontDoorWay way(
    String name, {
    bool enabled = true,
    bool suggested = false,
    bool inFlight = false,
    String? label,
    String? hint,
  }) => FrontDoorWay(
    name: name,
    label: label ?? 'Label $name',
    hint: hint ?? 'Hint $name',
    icon: LottiIcons.note,
    suggested: suggested,
    inFlight: inFlight,
    onTap: enabled ? () => acted.add(name) : null,
  );

  Future<void> pump(
    WidgetTester tester, {
    List<FrontDoorWay>? ways,
    FrontDoorWay? leave,
    double textScale = 1,
    double? width,
  }) async {
    if (width != null) {
      tester.view
        ..physicalSize = Size(width, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      makeTestableWidget(
        MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: FrontDoorWays(
            index: 3,
            ways:
                ways ??
                [way('task', suggested: true), way('goal'), way('note')],
            leave: leave ?? way('decline', label: 'Leave it'),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder row(String name) => find.byKey(ValueKey('front-door-$name-3'));
  Finder inRow(String name, Finder matching) =>
      find.descendant(of: row(name), matching: matching);
  BoxDecoration fill(WidgetTester tester, String name) =>
      tester
              .widget<Ink>(find.byKey(ValueKey('front-door-$name-row-3')))
              .decoration!
          as BoxDecoration;
  DsTokens tokensOf(WidgetTester tester) =>
      tester.element(find.byType(FrontDoorWays)).designTokens;
  DesignSystemButton leaveButton(WidgetTester tester) =>
      tester.widget<DesignSystemButton>(row('decline'));

  group('FrontDoorWays', () {
    testWidgets('lists every way as a row in the order given, each doing '
        'its own thing once on a tap, and the way out under them', (
      tester,
    ) async {
      await pump(tester);

      final tops = [
        for (final name in ['task', 'goal', 'note', 'decline'])
          tester.getTopLeft(row(name)).dy,
      ];
      expect(tops, [...tops]..sort());
      expect(tops.toSet(), hasLength(4));

      for (final name in ['note', 'task', 'goal', 'decline']) {
        await tester.tap(row(name));
      }
      expect(acted, ['note', 'task', 'goal', 'decline']);
    });

    testWidgets('the suggested way is the one tinted, outlined row: its '
        'glyph in the interactive colour, a tag in place of its hint; the '
        'others are neutral rows that say what they do', (tester) async {
      await pump(tester);
      final tokens = tokensOf(tester);
      final accent = tokens.colors.interactive.enabled;

      expect(
        fill(tester, 'task').color,
        DesignSystemListPalette.activatedFill(tokens),
      );
      expect((fill(tester, 'task').border! as Border).top.color, accent);
      expect(
        tester.widget<Icon>(inRow('task', find.byType(Icon))).color,
        accent,
      );
      expect(inRow('task', find.text('Suggested')), findsOne);
      expect(inRow('task', find.text('Hint task')), findsNothing);
      final tag =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(const ValueKey('front-door-task-tag-3')),
                  )
                  .decoration
              as BoxDecoration;
      expect(tag.color, accent);
      expect(
        tester.widget<Text>(find.text('Suggested')).style!.color,
        tokens.colors.text.onInteractiveAlert,
      );

      for (final name in ['goal', 'note']) {
        expect(fill(tester, name).color, tokens.colors.surface.enabled);
        expect(
          (fill(tester, name).border! as Border).top.color,
          Colors.transparent,
          reason: name,
        );
        expect(
          tester.widget<Icon>(inRow(name, find.byType(Icon))).color,
          tokens.colors.text.highEmphasis,
        );
        expect(inRow(name, find.text('Hint $name')), findsOne);
        expect(inRow(name, find.text('Suggested')), findsNothing);
      }
    });

    testWidgets('every row has one height and one glyph size, the '
        'suggested one included, at the default and at a large text size', (
      tester,
    ) async {
      for (final scale in [1.0, 1.5]) {
        await pump(tester, textScale: scale);

        final sizes = {
          for (final name in ['task', 'goal', 'note'])
            tester.getSize(row(name)),
        };
        expect(sizes, hasLength(1), reason: '$scale');
        final glyphs = {
          for (final name in ['task', 'goal', 'note'])
            tester.widget<Icon>(inRow(name, find.byType(Icon))).size,
        };
        expect(glyphs, hasLength(1), reason: '$scale');
      }
    });

    testWidgets('a row is one button that says its name and what it does; '
        'the suggested one says it is suggested', (tester) async {
      await pump(tester);

      Semantics semantics(String name) => tester.widget<Semantics>(row(name));
      expect(semantics('goal').properties.label, 'Label goal. Hint goal');
      expect(semantics('goal').properties.button, isTrue);
      expect(semantics('goal').properties.enabled, isTrue);
      expect(semantics('task').properties.label, 'Label task. Suggested');
    });

    testWidgets('the way out is a quiet button at the start of the list, '
        'not a row: nothing tints or fills it', (tester) async {
      await pump(tester);

      final button = leaveButton(tester);
      expect(button.label, 'Leave it');
      expect(button.variant, DesignSystemButtonVariant.quiet);
      expect(button.isLoading, isFalse);
      expect(
        tester.getTopLeft(row('decline')).dx,
        tester.getTopLeft(row('note')).dx,
      );
      expect(
        find.byKey(const ValueKey('front-door-decline-row-3')),
        findsNothing,
      );
    });

    testWidgets('a way that takes no tap is no enabled button, and does '
        'nothing', (tester) async {
      await pump(
        tester,
        ways: [way('goal', enabled: false)],
        leave: way('decline', enabled: false),
      );

      await tester.tap(row('goal'), warnIfMissed: false);
      await tester.tap(row('decline'), warnIfMissed: false);

      expect(acted, isEmpty);
      expect(
        tester.widget<Semantics>(row('goal')).properties.enabled,
        isFalse,
      );
      expect(leaveButton(tester).onPressed, isNull);
    });

    testWidgets('the way being done shows progress where its glyph was, at '
        'full strength, while the others step back — and the list is as '
        'tall as before', (tester) async {
      await pump(tester);
      final before = tester.getSize(find.byType(FrontDoorWays));

      await pump(
        tester,
        ways: [
          way('task', suggested: true, enabled: false),
          way('goal', enabled: false, inFlight: true),
          way('note', enabled: false),
        ],
        leave: way('decline', enabled: false),
      );

      expect(tester.getSize(find.byType(FrontDoorWays)), before);
      expect(inRow('goal', find.byType(DesignSystemSpinner)), findsOne);
      expect(inRow('goal', find.byType(Icon)), findsNothing);
      expect(inRow('goal', find.byType(Opacity)), findsNothing);
      for (final name in ['task', 'note']) {
        expect(inRow(name, find.byType(DesignSystemSpinner)), findsNothing);
        expect(
          tester.widget<Opacity>(inRow(name, find.byType(Opacity))).opacity,
          tokensOf(tester).colors.text.lowEmphasis.a,
          reason: name,
        );
      }
    });

    testWidgets('leaving it in flight loads the button and steps every row '
        'back', (tester) async {
      await pump(
        tester,
        ways: [way('task', enabled: false), way('note', enabled: false)],
        leave: way('decline', enabled: false, inFlight: true),
      );

      expect(leaveButton(tester).isLoading, isTrue);
      for (final name in ['task', 'note']) {
        expect(inRow(name, find.byType(Opacity)), findsOne, reason: name);
      }
    });

    testWidgets('at rest no row is stepped back', (tester) async {
      await pump(tester);

      expect(find.byType(Opacity), findsNothing);
      expect(find.byType(DesignSystemSpinner), findsNothing);
    });

    testWidgets('the longest labels fit a 360 wide phone: the names and '
        'hints wrap inside their rows, nothing overflows', (tester) async {
      await pump(tester, width: 360);
      final twoLines = tester.getSize(row('goal')).height;

      await pump(
        tester,
        width: 360,
        ways: [
          way(
            'task',
            suggested: true,
            label: 'Eine Aufgabe mit einem Programmier-Prompt daraus machen',
          ),
          way(
            'event',
            label: 'Einen vorläufigen Termin daraus machen',
            hint: 'Ein vorläufiger Termin mit deinen Worten als Titel, heute',
          ),
        ],
        leave: way('decline', label: 'So lassen, es wird nichts angelegt'),
      );

      expect(tester.takeException(), isNull);
      // The tag keeps its place at the row's end, whole and on one line.
      final tag = tester.getRect(
        find.byKey(const ValueKey('front-door-task-tag-3')),
      );
      expect(tag.right, lessThan(tester.getRect(row('task')).right));
      expect(
        tester.getSize(find.text('Suggested')).height,
        lessThan(twoLines / 2),
      );
      // The long names and the long hint wrapped rather than running off.
      for (final name in ['task', 'event']) {
        expect(
          tester.getSize(row(name)).height,
          greaterThan(twoLines),
          reason: name,
        );
        expect(tester.getRect(row(name)).right, lessThanOrEqualTo(360));
      }
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
          child: child,
        );

    testWidgets('gives what the card offers for the ways picked, and what '
        'it offers now after the card rebuilt', (tester) async {
      var builds = 0;
      final reader = Builder(
        builder: (context) {
          builds++;
          final scope = FrontDoorWaysScope.of(context);
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
    });
  });
}
