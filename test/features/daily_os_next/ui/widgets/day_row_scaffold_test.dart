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

        // A phone: the step4 inset.
        expect(time.left, tokens.spacing.step4);
        expect(time.width, tokens.spacing.step10);
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

    testWidgets('the time column grows with the text size', (tester) async {
      await _pump(tester, textScale: 1.5);
      final tokens = _tokens(tester);

      expect(
        tester.getSize(find.byKey(const Key('day_row_time'))).width,
        closeTo(tokens.spacing.step10 * 1.5, 0.01),
      );
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
          tester.getTopRight(find.byType(Expanded)).dx + tokens.spacing.step3,
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
}
