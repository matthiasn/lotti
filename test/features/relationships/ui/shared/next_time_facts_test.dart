import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/shared/next_time_facts.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  const attention = ValueKey('fact-attention');
  const avoid = ValueKey('fact-avoid');

  Future<void> pump(WidgetTester tester, List<NextTimeFact> facts) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(NextTimeFacts(facts: facts)),
    );
    await tester.pump();
  }

  testWidgets('each fact is a low-emphasis caption over a body line, the '
      'words carrying the key', (tester) async {
    await pump(tester, const [
      (
        caption: 'Pay attention to',
        text: 'The krill deadline.',
        key: attention,
      ),
    ]);

    final tokens = tester.element(find.byType(NextTimeFacts)).designTokens;
    final caption = tester.widget<Text>(find.text('Pay attention to'));
    final body = tester.widget<Text>(find.byKey(attention));
    expect(body.data, 'The krill deadline.');
    expect(caption.style?.color, tokens.colors.text.lowEmphasis);
    expect(
      caption.style?.fontSize,
      tokens.typography.styles.others.caption.fontSize,
    );
    expect(body.style?.color, tokens.colors.text.highEmphasis);
    expect(
      body.style?.fontSize,
      tokens.typography.styles.body.bodyMedium.fontSize,
    );
    // Flat on the card: no tile of its own around the pair.
    expect(
      find.ancestor(
        of: find.byKey(attention),
        matching: find.byType(DecoratedBox),
      ),
      findsNothing,
    );
  });

  testWidgets('facts stack `step1` inside a pair and `step3` between pairs, '
      'with nothing above the first', (tester) async {
    await pump(tester, const [
      (
        caption: 'Pay attention to',
        text: 'The krill deadline.',
        key: attention,
      ),
      (caption: 'Better to avoid', text: 'Pad-3 again.', key: avoid),
    ]);

    final tokens = tester.element(find.byType(NextTimeFacts)).designTokens;
    final box = tester.getRect(find.byType(NextTimeFacts));
    final firstCaption = tester.getRect(find.text('Pay attention to'));
    final firstBody = tester.getRect(find.byKey(attention));
    final secondCaption = tester.getRect(find.text('Better to avoid'));

    expect(firstCaption.top, box.top, reason: 'no gap above the first fact');
    expect(
      firstBody.top - firstCaption.bottom,
      closeTo(tokens.spacing.step1, 0.5),
    );
    expect(
      secondCaption.top - firstBody.bottom,
      closeTo(tokens.spacing.step3, 0.5),
    );
  });

  testWidgets('an empty list renders nothing and takes no height', (
    tester,
  ) async {
    await pump(tester, const []);
    expect(find.byType(Text), findsNothing);
    expect(tester.getSize(find.byType(NextTimeFacts)).height, 0);
  });
}
