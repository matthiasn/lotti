import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_speech_bubble.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pumpBubble(
    WidgetTester tester,
    OnboardingSpeechBubble bubble,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Center(child: SizedBox(width: 320, child: bubble)),
      ),
    );
    await tester.pump();
  }

  Finder tail() => find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter is OnboardingBubbleTailPainter,
  );

  OnboardingBubbleTailPainter tailPainter(WidgetTester tester) =>
      tester.widget<CustomPaint>(tail()).painter!
          as OnboardingBubbleTailPainter;

  Finder bubbleBody() => find.descendant(
    of: find.byType(OnboardingSpeechBubble),
    matching: find.byType(DecoratedBox),
  );

  group('OnboardingSpeechBubble', () {
    testWidgets('the tail sits centred above the body, and the title and '
        'text are centred in it', (tester) async {
      await pumpBubble(
        tester,
        const OnboardingSpeechBubble(title: 'Hi', text: 'One key'),
      );

      final tailRect = tester.getRect(tail());
      final bodyRect = tester.getRect(bubbleBody());
      // The tail reaches over the body's top edge by the outline's width,
      // covering the stretch of outline under it.
      expect(
        tailRect.bottom,
        bodyRect.top + OnboardingBubbleTailPainter.overlap,
      );
      expect(tailRect.center.dx, closeTo(bodyRect.center.dx, 0.01));

      expect(tester.widget<Text>(find.text('Hi')).textAlign, TextAlign.center);
      expect(
        tester.widget<Text>(find.text('One key')).textAlign,
        TextAlign.center,
      );
      expect(
        tester.getBottomLeft(find.text('Hi')).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.text('One key')).dy),
      );
    });

    testWidgets('without a minimum height the body wraps its words', (
      tester,
    ) async {
      await pumpBubble(tester, const OnboardingSpeechBubble(text: 'Mistral'));

      final body = tester.getSize(bubbleBody());
      expect(body.width, lessThan(320));
      expect(
        body.height,
        lessThan(tester.getSize(find.text('Mistral')).height * 3),
      );
    });

    testWidgets('with a minimum height the body spans the width and takes '
        'that height, its words from the top; longer words grow it', (
      tester,
    ) async {
      await pumpBubble(
        tester,
        const OnboardingSpeechBubble(text: 'Mistral', minHeight: 200),
      );

      final body = tester.getRect(bubbleBody());
      expect(body.size, const Size(320, 200));
      // The words start at the top, so the headline is at one height
      // whatever follows it.
      expect(
        tester.getTopLeft(find.text('Mistral')).dy - body.top,
        lessThan(body.height / 4),
      );

      await pumpBubble(
        tester,
        OnboardingSpeechBubble(
          text: List.filled(40, 'word').join(' '),
          minHeight: 40,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(bubbleBody()).height, greaterThan(40));
    });

    testWidgets('without text only the title shows', (tester) async {
      await pumpBubble(tester, const OnboardingSpeechBubble(title: 'Only'));

      expect(
        find.descendant(
          of: find.byType(OnboardingSpeechBubble),
          matching: find.byType(Text),
        ),
        findsOneWidget,
      );
      expect(find.text('Only'), findsOneWidget);
    });

    test('a bubble with neither title nor text is refused', () {
      expect(OnboardingSpeechBubble.new, throwsAssertionError);
    });

    testWidgets('without a title only the text shows', (tester) async {
      await pumpBubble(tester, const OnboardingSpeechBubble(text: 'Just this'));

      expect(
        find.descendant(
          of: find.byType(OnboardingSpeechBubble),
          matching: find.byType(Text),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the body and tail are the panel surface under one outline; '
        'the title is high-, the text medium-emphasis', (tester) async {
      await pumpBubble(
        tester,
        const OnboardingSpeechBubble(title: 'Hi', text: 'One key'),
      );
      final tokens = tester.element(tail()).designTokens;

      final decoration =
          tester.widget<DecoratedBox>(bubbleBody()).decoration as BoxDecoration;
      expect(decoration.color, tokens.colors.background.level01);
      expect(
        (decoration.border! as Border).top.color,
        tokens.colors.decorative.level02,
      );
      expect(tailPainter(tester).color, tokens.colors.background.level01);
      expect(tailPainter(tester).outline, tokens.colors.decorative.level02);
      expect(
        tester.widget<Text>(find.text('Hi')).style?.color,
        tokens.colors.text.highEmphasis,
      );
      expect(
        tester.widget<Text>(find.text('One key')).style?.color,
        tokens.colors.text.mediumEmphasis,
      );
    });

    testWidgets('a long line wraps inside the bubble instead of overflowing', (
      tester,
    ) async {
      await pumpBubble(
        tester,
        OnboardingSpeechBubble(
          text: List.filled(40, 'word').join(' '),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(bubbleBody()).width, lessThanOrEqualTo(320));
    });
  });

  group('OnboardingBubbleTailPainter', () {
    test('the tail has its tip at the top centre', () {
      final path = OnboardingBubbleTailPainter.tailPath(const Size(20, 10));
      expect(path.getBounds(), const Rect.fromLTWH(0, 0, 20, 10));
      expect(path.contains(const Offset(10, 1)), isTrue);
      expect(path.contains(const Offset(1, 1)), isFalse);
      expect(path.contains(const Offset(19, 1)), isFalse);
    });

    test('repaints only when its colour or outline changes', () {
      const painter = OnboardingBubbleTailPainter(
        color: Color(0xFF000000),
        outline: Color(0xFF111111),
      );
      expect(
        painter.shouldRepaint(
          const OnboardingBubbleTailPainter(
            color: Color(0xFF000000),
            outline: Color(0xFF111111),
          ),
        ),
        isFalse,
      );
      expect(
        painter.shouldRepaint(
          const OnboardingBubbleTailPainter(
            color: Color(0xFFFFFFFF),
            outline: Color(0xFF111111),
          ),
        ),
        isTrue,
      );
      expect(
        painter.shouldRepaint(
          const OnboardingBubbleTailPainter(
            color: Color(0xFF000000),
            outline: Color(0xFF222222),
          ),
        ),
        isTrue,
      );
    });
  });
}
