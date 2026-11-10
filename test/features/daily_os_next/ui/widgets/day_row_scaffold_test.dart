import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_row_scaffold.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

const _child = Key('child');
const _leading = Key('leading');
const _trailing = Key('trailing');

Future<void> _pump(
  WidgetTester tester, {
  String time = '9:00 AM',
  String? overline,
  Widget? trailing,
  Widget? below,
  bool active = false,
  double? firstLine,
  double width = 600,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: DayRowScaffold(
            time: time,
            timeOverline: overline,
            firstLine: firstLine,
            leading: const SizedBox.square(key: _leading, dimension: 4),
            trailing: trailing,
            below: below,
            active: active,
            child: const Text('Words', key: _child),
          ),
        ),
      ),
      mediaQueryData: MediaQueryData(
        size: Size(width, 800),
        textScaler: TextScaler.linear(textScale),
      ),
    ),
  );
}

DsTokens _tokens(WidgetTester tester) =>
    tester.element(find.byType(DayRowScaffold)).designTokens;

void main() {
  group('DayRowScaffold', () {
    testWidgets('is at least a tap target tall', (tester) async {
      await _pump(tester);

      expect(
        tester.getSize(find.byType(DayRowScaffold)).height,
        greaterThanOrEqualTo(TapTargets.minimum),
      );
    });

    testWidgets(
      'lays out time, gutter, mark slot, gap and words on fixed lines',
      (tester) async {
        await _pump(tester);
        final tokens = _tokens(tester);
        final time = tester.getRect(find.byKey(const Key('day_row_time')));

        // A phone: the step4 inset; the column as wide as the clock needs.
        expect(time.left, tokens.spacing.step4);
        expect(
          time.width,
          DayRowScaffold.timeColumnWidth(
            tester.element(find.byType(DayRowScaffold)),
          ),
        );
        // The 4 px mark is centred in a caption-glyph-wide slot.
        final slot = tokens.typography.size.caption;
        final markLeft = time.right + tokens.spacing.step2;
        expect(
          tester.getCenter(find.byKey(_leading)).dx,
          closeTo(markLeft + slot / 2, 0.01),
        );
        expect(
          tester.getTopLeft(find.byKey(_child)).dx,
          closeTo(markLeft + slot + tokens.spacing.step3, 0.01),
        );
        // wordsInset names the same edge, from the row's inner edge.
        expect(
          tokens.spacing.step4 +
              DayRowScaffold.wordsInset(
                tester.element(find.byType(DayRowScaffold)),
              ),
          closeTo(tester.getTopLeft(find.byKey(_child)).dx, 0.01),
        );
      },
    );

    testWidgets('a wide pane insets the row by the card padding', (
      tester,
    ) async {
      await _pump(tester, width: kDesktopBreakpoint + 100);
      final tokens = _tokens(tester);

      expect(
        tester.getTopLeft(find.byKey(const Key('day_row_time'))).dx,
        tokens.spacing.cardPadding,
      );
    });

    testWidgets(
      "the time column is as wide as the device clock's widest time, and "
      'grows with the text size',
      (tester) async {
        // A 12-hour clock's widest time is a two-digit hour with its period.
        await _pump(tester, time: '10:55 PM');
        final width = tester
            .getSize(find.byKey(const Key('day_row_time')))
            .width;
        final text = tester.getSize(find.text('10:55 PM')).width;
        expect(width, greaterThanOrEqualTo(text));
        expect(width, lessThan(text + 2), reason: 'no width spent on a guess');

        await _pump(tester, time: '10:55 PM', textScale: 1.5);
        expect(
          tester.getSize(find.byKey(const Key('day_row_time'))).width,
          greaterThan(width * 1.4),
        );
      },
    );

    testWidgets("the column fits a long 'Now' under the time", (tester) async {
      await _pump(tester, overline: 'Now');
      final column = tester.getSize(find.byKey(const Key('day_row_time')));
      expect(
        column.width,
        greaterThanOrEqualTo(tester.getSize(find.text('Now')).width),
      );
    });

    testWidgets(
      'below starts under the words and runs under the trailing column',
      (tester) async {
        await _pump(
          tester,
          trailing: const SizedBox.square(key: _trailing, dimension: 10),
          below: const SizedBox(key: Key('below'), height: 10),
        );
        final below = tester.getRect(find.byKey(const Key('below')));

        expect(
          below.left,
          closeTo(tester.getTopLeft(find.byKey(_child)).dx, 0.01),
        );
        expect(
          below.right,
          closeTo(tester.getTopRight(find.byKey(_trailing)).dx, 0.01),
        );
        expect(
          below.top,
          greaterThan(tester.getBottomLeft(find.byKey(_child)).dy - 0.01),
        );
      },
    );

    testWidgets('an active row carries a teal edge at its start', (
      tester,
    ) async {
      await _pump(tester, active: true);
      final tokens = _tokens(tester);
      final edge = find.byKey(const Key('day_row_active_edge'));

      expect(edge, findsOneWidget);
      expect(tester.getSize(edge).width, tokens.spacing.step1);
      expect(
        tester.getSize(edge).height,
        tester.getSize(find.byType(DayRowScaffold)).height,
      );
      expect(
        tester
            .widget<ColoredBox>(
              find.descendant(of: edge, matching: find.byType(ColoredBox)),
            )
            .color,
        tokens.colors.interactive.enabled,
      );
    });

    testWidgets('a row at rest has no edge', (tester) async {
      await _pump(tester);
      expect(find.byKey(const Key('day_row_active_edge')), findsNothing);
    });

    testWidgets('the time is a quiet, tabular, right-aligned caption', (
      tester,
    ) async {
      await _pump(tester);
      final tokens = _tokens(tester);
      final time = tester.widget<Text>(find.text('9:00 AM'));

      expect(time.textAlign, TextAlign.end);
      expect(time.style!.color, tokens.colors.text.lowEmphasis);
      expect(time.style!.fontFeatures, dayFigures);
      expect(
        tester.getTopRight(find.text('9:00 AM')).dx,
        closeTo(
          tester.getTopRight(find.byKey(const Key('day_row_time'))).dx,
          0.01,
        ),
      );
    });

    testWidgets('an overline sits under the time in high emphasis', (
      tester,
    ) async {
      await _pump(tester, overline: 'Now');
      final tokens = _tokens(tester);

      final overline = tester.widget<Text>(find.text('Now'));
      expect(overline.style!.color, tokens.colors.text.highEmphasis);
      expect(
        tester.getTopLeft(find.text('Now')).dy,
        greaterThan(tester.getTopLeft(find.text('9:00 AM')).dy),
      );
    });

    testWidgets('without an overline the time stands alone', (tester) async {
      await _pump(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('day_row_time')),
          matching: find.byType(Text),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a trailing widget follows the words, a step3 apart', (
      tester,
    ) async {
      await _pump(
        tester,
        trailing: const SizedBox.square(key: _trailing, dimension: 10),
      );
      final tokens = _tokens(tester);

      // The words take the room left; the trailing ends on the inset.
      expect(
        tester.getTopLeft(find.byKey(_trailing)).dx,
        closeTo(
          tester.getTopRight(find.byType(Expanded).first).dx +
              tokens.spacing.step3,
          0.01,
        ),
      );
      expect(
        tester.getTopRight(find.byKey(_trailing)).dx,
        closeTo(600 - tokens.spacing.step4, 0.01),
      );
    });

    testWidgets('the mark centres on a taller first line', (tester) async {
      await _pump(tester, firstLine: 40);
      final tokens = _tokens(tester);
      final rowTop = tester.getTopLeft(find.byType(DayRowScaffold)).dy;

      // The 4 px mark sits in a caption-wide slot centred on a 40 px line.
      final slot = tokens.typography.size.caption;
      expect(
        tester.getCenter(find.byKey(_leading)).dy - rowTop,
        closeTo(tokens.spacing.step3 + (40 - slot) / 2 + slot / 2, 0.01),
      );
    });
  });

  group('DayRowTrailing', () {
    Future<void> pumpTrailing(WidgetTester tester, Widget child) =>
        tester.pumpWidget(
          makeTestableWidgetNoScroll(
            Align(alignment: Alignment.topLeft, child: child),
          ),
        );

    testWidgets('a figure, then the chevron slot', (tester) async {
      await pumpTrailing(
        tester,
        const DayRowTrailing(figure: '1h 30m', icon: LottiIcons.chevronRight),
      );
      final tokens = tester.element(find.byType(DayRowTrailing)).designTokens;

      final figure = tester.widget<Text>(find.text('1h 30m'));
      expect(figure.style!.color, tokens.colors.text.mediumEmphasis);
      expect(figure.style!.fontFeatures, dayFigures);
      expect(
        tester.getTopLeft(find.byIcon(LottiIcons.chevronRight)).dx -
            tester.getTopRight(find.text('1h 30m')).dx,
        closeTo(tokens.spacing.step2, 0.01),
      );
    });

    testWidgets(
      'an empty slot keeps its width, so figures end on one edge',
      (tester) async {
        await pumpTrailing(
          tester,
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              DayRowTrailing(figure: '45m', icon: LottiIcons.chevronRight),
              DayRowTrailing(figure: '45m'),
            ],
          ),
        );
        final tokens = tester.element(find.byType(Column)).designTokens;
        final figures = tester.widgetList(find.text('45m')).toList();
        expect(figures, hasLength(2));
        final rights = [
          for (final e in find.text('45m').evaluate())
            tester.getTopRight(find.byWidget(e.widget)).dx,
        ];
        expect(rights.first, closeTo(rights.last, 0.01));
        expect(
          tester.getSize(find.byType(DayRowTrailing).last).width -
              tester.getSize(find.text('45m').last).width,
          closeTo(DayRowTrailing.slotWidth(tokens), 0.01),
        );
      },
    );

    testWidgets('a slot alone, with no figure', (tester) async {
      await pumpTrailing(
        tester,
        const DayRowTrailing(icon: LottiIcons.chevronDown),
      );

      expect(find.byIcon(LottiIcons.chevronDown), findsOneWidget);
      expect(find.byType(Text), findsNothing);
    });
  });
}
