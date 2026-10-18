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

    test('needs a proportionally wider body at a larger text scale', () {
      const min = CompanionPlacement.besideMinWidth;
      const large = TextScaler.linear(TextScales.large);
      expect(
        CompanionPlacement.forBodyWidth(min, textScaler: large),
        CompanionPlacement.header,
      );
      expect(
        CompanionPlacement.forBodyWidth(
          min * TextScales.large,
          textScaler: large,
        ),
        CompanionPlacement.beside,
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
    // A floor under her shoes: the row ends step4 below her, and the column
    // beside her is at least that tall, its footer at the foot — so under
    // short content the footer closes the card instead of floating.
    expect(layout.bottom, her.bottom + spacing.step4);
    final footer = tester.getRect(find.byKey(_footerKey));
    expect(footer.left, header.left);
    expect(footer.bottom, layout.bottom);
    expect(footer.top, greaterThan(body.bottom));
  });

  group('CompanionReportScaffold', () {
    late List<CompanionHeaderSlot> slots;
    late List<CompanionFraming> framings;

    Future<void> pump(
      WidgetTester tester, {
      required double width,
      bool companion = true,
      VoidCallback? onFigureTap,
    }) async {
      slots = [];
      framings = [];
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          // A column hands it unbounded height, as a card surface does.
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: width,
                child: CompanionReportScaffold(
                  companion: companion
                      ? (framing) {
                          framings.add(framing);
                          return const SizedBox.expand(key: _figureKey);
                        }
                      : null,
                  onFigureTap: onFigureTap,
                  header: (slot) {
                    slots.add(slot);
                    return SizedBox(
                      key: _headerKey,
                      height: 40,
                      child: slot.figure,
                    );
                  },
                  body: const SizedBox(key: _bodyKey, height: 40),
                  footer: const SizedBox(key: _footerKey, height: 24),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // The card body is its width less a card padding on each side; the test
    // app wears the light tokens.
    double widthFor(double body) =>
        body + 2 * dsTokensLight.spacing.cardPadding;

    testWidgets('on a wide card she stands beside header, body and footer, '
        'and the header keeps no badge and offers no tap', (tester) async {
      await pump(
        tester,
        width: widthFor(CompanionPlacement.besideMinWidth),
        onFigureTap: () {},
      );

      expect(find.byType(CompanionBesideReport), findsOneWidget);
      expect(framings, [CompanionFraming.full]);
      expect(slots.single.figure, isNull);
      expect(slots.single.badge, isFalse);
      expect(slots.single.onFigureTap, isNull);
    });

    testWidgets('on a narrow card her bust is the header figure, with the '
        'tap, and the blocks stack', (tester) async {
      var taps = 0;
      await pump(
        tester,
        width: widthFor(CompanionPlacement.besideMinWidth - 1),
        onFigureTap: () => taps++,
      );

      expect(find.byType(CompanionBesideReport), findsNothing);
      expect(framings, [CompanionFraming.bust]);
      final slot = slots.single;
      expect(slot.figure, isNotNull);
      expect(slot.badge, isTrue);
      slot.onFigureTap!();
      expect(taps, 1);
      // Header, body and footer stack in reading order.
      final header = tester.getRect(find.byKey(_headerKey));
      final body = tester.getRect(find.byKey(_bodyKey));
      final footer = tester.getRect(find.byKey(_footerKey));
      expect(body.top, header.bottom);
      expect(footer.top, body.bottom);
    });

    testWidgets('without her the header keeps its badge, at any width', (
      tester,
    ) async {
      await pump(tester, width: 900, companion: false, onFigureTap: () {});

      expect(find.byType(CompanionBesideReport), findsNothing);
      expect(framings, isEmpty);
      expect(slots.single.figure, isNull);
      expect(slots.single.badge, isTrue);
      expect(slots.single.onFigureTap, isNull);
    });
  });
}
