import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/timeline/design_system_timeline_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/icon_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pumpRow(
    WidgetTester tester, {
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    bool last = false,
    Widget? body,
    Widget? footer,
    Widget? trailing,
  }) => tester.pumpWidget(
    makeTestableWidget2(
      Scaffold(
        // A Scaffold body is laid out at the full height; the row's own
        // height is what is under test.
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 360,
            child: DesignSystemTimelineRow(
              leading: const DesignSystemTimelineTile(icon: LottiIcons.mic),
              meta: const Text('Sat 1 Aug 12:44 · Call'),
              body: body,
              footer: footer,
              trailing: trailing,
              onTap: onTap,
              onLongPress: onLongPress,
              last: last,
              semanticsLabel: 'Call with Pip, Saturday 1 August',
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('a tappable row answers taps and long presses and is announced '
      'as one button with its sentence', (tester) async {
    var taps = 0;
    var longPresses = 0;
    final handle = tester.ensureSemantics();
    await pumpRow(
      tester,
      onTap: () => taps++,
      onLongPress: () => longPresses++,
      body: const Text('Walked through the launch window.'),
    );

    await tester.tap(find.text('Walked through the launch window.'));
    await tester.longPress(find.text('Sat 1 Aug 12:44 · Call'));

    expect(taps, 1);
    expect(longPresses, 1);
    expect(
      tester.getSemantics(find.byType(DesignSystemTimelineRow)),
      containsSemantics(
        label: 'Call with Pip, Saturday 1 August',
        isButton: true,
        hasTapAction: true,
        hasLongPressAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('a row without a tap is not a button', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpRow(tester);

    final semantics = tester.getSemantics(
      find.byType(DesignSystemTimelineRow),
    );
    expect(semantics.flagsCollection.isButton, isFalse);
    handle.dispose();
  });

  testWidgets('the rail runs on below every row but the last of its '
      'section', (tester) async {
    await pumpRow(tester, body: const Text('body'));
    expect(find.byKey(const ValueKey('timeline-row-rail')), findsOneWidget);

    await pumpRow(tester, body: const Text('body'), last: true);
    expect(find.byKey(const ValueKey('timeline-row-rail')), findsNothing);
  });

  testWidgets('the rail starts just below the tile and runs on past the '
      "row's bottom to just above where the next tile sits", (tester) async {
    await pumpRow(
      tester,
      body: const Text('A body long enough to make the row tall.'),
      footer: const SizedBox(height: 60, child: Text('footer')),
    );

    final rail = tester.getRect(
      find.byKey(const ValueKey('timeline-row-rail')),
    );
    final tile = tester.getRect(find.byType(DesignSystemTimelineTile));
    final row = tester.getRect(find.byType(DesignSystemTimelineRow));
    final spacing = dsTokensDark.spacing;
    // The same step1 gap above and below every tile: the next row's tile
    // sits its own step3 inset below this row's bottom.
    expect(rail.top - tile.bottom, closeTo(spacing.step1, 0.5));
    expect(
      row.bottom + spacing.step3 - rail.bottom,
      closeTo(spacing.step1, 0.5),
    );
    expect(rail.center.dx, closeTo(tile.center.dx, 0.5));
  });

  testWidgets('trailing sits at the row end, beside the meta line', (
    tester,
  ) async {
    await pumpRow(tester, trailing: const Text('Fri'));

    final trailing = tester.getRect(find.text('Fri'));
    final meta = tester.getRect(find.text('Sat 1 Aug 12:44 · Call'));
    final tile = tester.getRect(find.byType(DesignSystemTimelineTile));
    expect(trailing.left, greaterThan(meta.right));
    expect(trailing.center.dy, closeTo(tile.center.dy, 1));
  });

  test('a row without an accessible name is refused at construction', () {
    expect(
      () => DesignSystemTimelineRow(
        leading: const SizedBox(),
        meta: const SizedBox(),
        semanticsLabel: '  ',
      ),
      throwsAssertionError,
    );
  });

  testWidgets('the agent tile wears the AI card colours; every other kind the '
      'one neutral tile', (tester) async {
    late DsTokens tokens;
    await tester.pumpWidget(
      makeTestableWidget2(
        Builder(
          builder: (context) {
            tokens = context.designTokens;
            return const Row(
              children: [
                DesignSystemTimelineTile(
                  key: ValueKey('neutral'),
                  icon: LottiIcons.mic,
                ),
                DesignSystemTimelineTile(
                  key: ValueKey('agent'),
                  icon: LottiIcons.aiSpark,
                  tone: DesignSystemTimelineTileTone.agent,
                ),
              ],
            );
          },
        ),
      ),
    );

    BoxDecoration decorationOf(String key) =>
        tester
                .widget<Container>(
                  find.descendant(
                    of: find.byKey(ValueKey(key)),
                    matching: find.byType(Container),
                  ),
                )
                .decoration!
            as BoxDecoration;
    Color inkOf(String key) => tester
        .widget<Icon>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(Icon),
          ),
        )
        .color!;

    expect(decorationOf('neutral').color, tokens.colors.background.level03);
    expect(decorationOf('neutral').border, isNull);
    expect(inkOf('neutral'), tokens.colors.text.mediumEmphasis);
    expect(decorationOf('agent').color, tokens.colors.aiCard.background);
    expect(decorationOf('agent').border, isNotNull);
    expect(inkOf('agent'), tokens.colors.aiCard.accent);
  });

  testWidgets('the section header is a heading, set in the calm eyebrow as '
      'written', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      makeTestableWidget2(
        const Scaffold(
          body: DesignSystemTimelineSectionHeader(
            label: 'This week',
            trailing: Text('All'),
          ),
        ),
      ),
    );

    expect(find.text('This week'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('This week')).flagsCollection.isHeader,
      isTrue,
    );
    handle.dispose();
  });
}
