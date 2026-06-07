import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/typing_indicator.dart';

void main() {
  Future<void> pumpIndicator(
    WidgetTester tester, {
    required bool isUser,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TypingIndicator(isUser: isUser)),
      ),
    );
  }

  List<Container> dotsOf(WidgetTester tester) => tester
      .widgetList<Container>(
        find.descendant(
          of: find.byType(TypingIndicator),
          matching: find.byType(Container),
        ),
      )
      .toList();

  testWidgets('renders three 4x4 dots', (tester) async {
    await pumpIndicator(tester, isUser: false);

    final dots = dotsOf(tester);
    expect(dots, hasLength(3));
    for (final dot in dots) {
      expect(dot.constraints?.maxWidth, 4);
      expect(dot.constraints?.maxHeight, 4);
      expect((dot.decoration! as BoxDecoration).shape, BoxShape.circle);
    }
  });

  testWidgets('dot color follows the message side', (tester) async {
    await pumpIndicator(tester, isUser: true);
    final theme = Theme.of(tester.element(find.byType(TypingIndicator)));

    Color baseColorOf(Container dot) =>
        ((dot.decoration! as BoxDecoration).color!).withValues(alpha: 1);

    expect(
      baseColorOf(dotsOf(tester).first),
      theme.colorScheme.onPrimary.withValues(alpha: 1),
    );

    await pumpIndicator(tester, isUser: false);
    expect(
      baseColorOf(dotsOf(tester).first),
      theme.colorScheme.onSurfaceVariant.withValues(alpha: 1),
    );
  });

  testWidgets('animation pulses the dot opacities over time', (tester) async {
    await pumpIndicator(tester, isUser: false);

    double alphaOfFirstDot() =>
        (dotsOf(tester).first.decoration! as BoxDecoration).color!.a;

    final initial = alphaOfFirstDot();
    // Advance partway through the 1.5s repeat cycle: the alpha must flip
    // between the 0.3 and 1.0 steps at some sampled frame.
    var changed = false;
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (alphaOfFirstDot() != initial) {
        changed = true;
        break;
      }
    }
    expect(changed, isTrue, reason: 'dot opacity must animate');
  });

  testWidgets('disposes its animation controller without leaking timers', (
    tester,
  ) async {
    await pumpIndicator(tester, isUser: false);
    // Replacing the tree disposes the state; the repeating controller must
    // not leave a pending ticker behind (the test would fail on teardown).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
