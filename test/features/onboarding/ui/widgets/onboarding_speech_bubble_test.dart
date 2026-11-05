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
    testWidgets('pointing up: the tail sits centred above the body, and the '
        'title and text are centred in it', (tester) async {
      await pumpBubble(
        tester,
        const OnboardingSpeechBubble(title: 'Hi', text: 'One key'),
      );

      final tailRect = tester.getRect(tail());
      final bodyRect = tester.getRect(bubbleBody());
      expect(tailRect.bottom, bodyRect.top);
      expect(tailRect.center.dx, closeTo(bodyRect.center.dx, 0.01));
      expect(tailPainter(tester).tail, OnboardingBubbleTail.up);

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

    testWidgets("pointing left: the tail sits at the body's left edge, "
        'mid-height, and the text starts at the leading edge', (
      tester,
    ) async {
      await pumpBubble(
        tester,
        const OnboardingSpeechBubble(
          text: 'Mistral',
          tail: OnboardingBubbleTail.left,
        ),
      );

      final tailRect = tester.getRect(tail());
      final bodyRect = tester.getRect(bubbleBody());
      expect(tailRect.right, bodyRect.left);
      expect(tailRect.center.dy, closeTo(bodyRect.center.dy, 0.01));
      expect(tailPainter(tester).tail, OnboardingBubbleTail.left);
      expect(
        tester.widget<Text>(find.text('Mistral')).textAlign,
        TextAlign.start,
      );
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

    testWidgets('the body and tail share the raised surface; the title is '
        'high-, the text medium-emphasis', (tester) async {
      await pumpBubble(
        tester,
        const OnboardingSpeechBubble(title: 'Hi', text: 'One key'),
      );
      final tokens = tester.element(tail()).designTokens;

      final decoration =
          tester.widget<DecoratedBox>(bubbleBody()).decoration as BoxDecoration;
      expect(decoration.color, tokens.colors.background.level02);
      expect(tailPainter(tester).color, tokens.colors.background.level02);
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
          tail: OnboardingBubbleTail.left,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(bubbleBody()).width, lessThanOrEqualTo(320));
    });
  });

  group('OnboardingBubbleTailPainter', () {
    test('an upward tail has its tip at the top centre', () {
      final bounds = OnboardingBubbleTailPainter.tailPath(
        const Size(20, 10),
        OnboardingBubbleTail.up,
      ).getBounds();
      expect(bounds, const Rect.fromLTWH(0, 0, 20, 10));
      final path = OnboardingBubbleTailPainter.tailPath(
        const Size(20, 10),
        OnboardingBubbleTail.up,
      );
      expect(path.contains(const Offset(10, 1)), isTrue);
      expect(path.contains(const Offset(1, 1)), isFalse);
      expect(path.contains(const Offset(19, 1)), isFalse);
    });

    test('a leftward tail has its tip at the left middle', () {
      final path = OnboardingBubbleTailPainter.tailPath(
        const Size(10, 20),
        OnboardingBubbleTail.left,
      );
      expect(path.getBounds(), const Rect.fromLTWH(0, 0, 10, 20));
      expect(path.contains(const Offset(1, 10)), isTrue);
      expect(path.contains(const Offset(1, 1)), isFalse);
      expect(path.contains(const Offset(1, 19)), isFalse);
    });

    test('repaints only when its colour or direction changes', () {
      const painter = OnboardingBubbleTailPainter(
        color: Color(0xFF000000),
        tail: OnboardingBubbleTail.up,
      );
      expect(
        painter.shouldRepaint(
          const OnboardingBubbleTailPainter(
            color: Color(0xFF000000),
            tail: OnboardingBubbleTail.up,
          ),
        ),
        isFalse,
      );
      expect(
        painter.shouldRepaint(
          const OnboardingBubbleTailPainter(
            color: Color(0xFFFFFFFF),
            tail: OnboardingBubbleTail.up,
          ),
        ),
        isTrue,
      );
      expect(
        painter.shouldRepaint(
          const OnboardingBubbleTailPainter(
            color: Color(0xFF000000),
            tail: OnboardingBubbleTail.left,
          ),
        ),
        isTrue,
      );
    });
  });
}
