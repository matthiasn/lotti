import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/companion_report_layout.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

const _figureKey = ValueKey<String>('figure');
const _bodyKey = ValueKey<String>('body');
const _leadingKey = ValueKey<String>('leading');

/// A stand-in for her that never ticks, so the layout can settle; it fills
/// the box it is given, as `CompanionSpeaker` does.
const _figure = SizedBox.expand(key: _figureKey);

/// A body that records where the layout put her: under the prose (wrapped in
/// [_leadingKey]) when handed a leading, nowhere when not.
Widget _body(Widget? leading) => Column(
  key: _bodyKey,
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const SizedBox(height: 40, width: double.infinity),
    if (leading != null) KeyedSubtree(key: _leadingKey, child: leading),
  ],
);

Future<void> _pump(WidgetTester tester, double width) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: const CompanionReportLayout(
            companion: _figure,
            buildBody: _body,
          ),
        ),
      ),
    ),
  );
}

double _frameWidth(double height) => height * CompanionFraming.full.aspectRatio;

void main() {
  group('CompanionSlot.overhang', () {
    test('is the side room of the full framing outside the bust window', () {
      const height = 100.0;
      final full = CompanionFraming.full.window;
      final bust = CompanionFraming.bust.window;
      expect(
        CompanionSlot.overhang(height),
        closeTo((full.width - bust.width) / 2 / full.height * height, 1e-9),
      );
    });

    testWidgets('never exceeds the gutters she hangs into, at either size', (
      tester,
    ) async {
      await tester.pumpWidget(makeTestableWidget(const SizedBox()));
      final spacing = tester.element(find.byType(SizedBox)).designTokens;
      for (final height in [
        ControlSizes.companionCardWide,
        ControlSizes.companionCardCompact,
      ]) {
        final overhang = CompanionSlot.overhang(height);
        // Leading: the card padding. Trailing: the gap before the prose.
        expect(overhang, lessThanOrEqualTo(spacing.spacing.cardPadding));
        expect(overhang, lessThanOrEqualTo(spacing.spacing.step5));
      }
    });
  });

  group('on a wide card body', () {
    testWidgets('she stands beside the body at the wide size, her frame '
        'hanging into the gutter by the overhang', (tester) async {
      await _pump(tester, CompanionReportLayout.besideMinWidth);

      const height = ControlSizes.companionCardWide;
      final layout = tester.getRect(find.byType(CompanionReportLayout));
      final her = tester.getRect(find.byKey(_figureKey));
      final body = tester.getRect(find.byKey(_bodyKey));
      final gap = tester
          .element(find.byType(CompanionReportLayout))
          .designTokens
          .spacing
          .step5;

      expect(her.height, height);
      expect(her.width, closeTo(_frameWidth(height), 0.01));
      final overhang = CompanionSlot.overhang(height);
      expect(her.left, closeTo(layout.left - overhang, 0.01));
      expect(body.left, closeTo(her.right - overhang + gap, 0.01));
      expect(body.right, layout.right);
      expect(her.top, body.top);
      expect(find.byKey(_leadingKey), findsNothing);
    });
  });

  group('on a narrow card body', () {
    testWidgets('the body takes the full width and she stands under the '
        'prose at the compact size', (tester) async {
      await _pump(tester, CompanionReportLayout.besideMinWidth - 1);

      const height = ControlSizes.companionCardCompact;
      final layout = tester.getRect(find.byType(CompanionReportLayout));
      final body = tester.getRect(find.byKey(_bodyKey));
      final her = tester.getRect(find.byKey(_figureKey));
      final spacing = tester
          .element(find.byType(CompanionReportLayout))
          .designTokens
          .spacing;

      expect(body.left, layout.left);
      expect(body.width, layout.width);
      expect(her.height, height);
      expect(her.width, closeTo(_frameWidth(height), 0.01));
      expect(
        her.left,
        closeTo(layout.left - CompanionSlot.overhang(height), 0.01),
      );
      // Air between the last line of prose and the crown of her hair.
      expect(her.top, layout.top + 40 + spacing.step3);
      // Her slot keeps the gap on its trailing side for the links beside it.
      final leading = tester.getRect(find.byKey(_leadingKey));
      expect(
        leading.width,
        closeTo(
          _frameWidth(height) -
              2 * CompanionSlot.overhang(height) +
              spacing.step5,
          0.01,
        ),
      );
    });
  });
}
