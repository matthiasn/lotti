import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/companion_report_layout.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

const _figureKey = ValueKey<String>('figure');
const _bodyKey = ValueKey<String>('body');
const _headerKey = ValueKey<String>('header');
const _footerKey = ValueKey<String>('footer');

double _frameWidth(double height) => height * CompanionFraming.full.aspectRatio;

void main() {
  group('CompanionPlacement', () {
    test('keeps her beside the prose from besideMinWidth up, in the header '
        'below it', () {
      const min = CompanionPlacement.besideMinWidth;
      expect(CompanionPlacement.forBodyWidth(min), CompanionPlacement.beside);
      expect(
        CompanionPlacement.forBodyWidth(min - 1),
        CompanionPlacement.header,
      );
    });

    test('draws her head to toe beside the prose and as a bust in the '
        'header', () {
      expect(CompanionPlacement.beside.framing, CompanionFraming.full);
      expect(CompanionPlacement.header.framing, CompanionFraming.bust);
    });
  });

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

    testWidgets('never exceeds the gutters she hangs into on the card', (
      tester,
    ) async {
      await tester.pumpWidget(makeTestableWidget(const SizedBox()));
      final spacing = tester
          .element(find.byType(SizedBox))
          .designTokens
          .spacing;
      final overhang = CompanionSlot.overhang(ControlSizes.companionCard);
      // Leading: the card padding. Trailing: the gap before the prose.
      expect(overhang, lessThanOrEqualTo(spacing.cardPadding));
      expect(overhang, lessThanOrEqualTo(spacing.step5));
    });
  });

  testWidgets('CompanionBesideReport stands her on the card padding, heading '
      'the header, body and footer on one edge beside her', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        // A column hands her unbounded height, as the card surface does.
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 600,
              child: CompanionBesideReport(
                // Never ticks, so the layout can settle; it fills the box it is
                // given, as `CompanionSpeaker` does.
                companion: SizedBox.expand(key: _figureKey),
                header: SizedBox(key: _headerKey, height: 40),
                body: SizedBox(key: _bodyKey, height: 40),
                footer: SizedBox(key: _footerKey, height: 24),
              ),
            ),
          ],
        ),
      ),
    );

    const height = ControlSizes.companionCard;
    final layout = tester.getRect(find.byType(CompanionBesideReport));
    final her = tester.getRect(find.byKey(_figureKey));
    final header = tester.getRect(find.byKey(_headerKey));
    final body = tester.getRect(find.byKey(_bodyKey));
    final spacing = tester
        .element(find.byType(CompanionBesideReport))
        .designTokens
        .spacing;

    expect(her.height, height);
    expect(her.width, closeTo(_frameWidth(height), 0.01));
    final overhang = CompanionSlot.overhang(height);
    expect(
      her.left,
      closeTo(layout.left + spacing.cardPadding - overhang, 0.01),
    );
    expect(her.top, layout.top + spacing.step4);
    // The header and body start where her slot ends, on one edge.
    expect(header.left, closeTo(her.right - overhang, 0.01));
    expect(body.left, header.left);
    expect(header.right, layout.right);
    expect(body.top, header.bottom);
    // A floor under her shoes: the row ends step3 below her, and the column
    // beside her is at least that tall, its footer at the foot — so under
    // short content the footer closes the card instead of floating.
    expect(layout.bottom, her.bottom + spacing.step3);
    final footer = tester.getRect(find.byKey(_footerKey));
    expect(footer.left, header.left);
    expect(footer.bottom, layout.bottom);
    expect(footer.top, greaterThan(body.bottom));
  });
}
