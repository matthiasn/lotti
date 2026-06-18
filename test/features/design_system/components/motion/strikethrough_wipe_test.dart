import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/motion/strikethrough_wipe.dart';

import '../../../../widget_test_utils.dart';

void main() {
  const baseStyle = TextStyle(fontSize: 14);
  const struckStyle = TextStyle(
    fontSize: 14,
    decoration: TextDecoration.lineThrough,
  );

  Widget wipe({required bool done, bool animate = true}) => StrikethroughWipe(
    done: done,
    animate: animate,
    text: 'Buy milk',
    baseStyle: baseStyle,
    struckStyle: struckStyle,
  );

  List<TextDecoration?> decorations(WidgetTester tester) => tester
      .widgetList<Text>(find.text('Buy milk'))
      .map((t) => t.style?.decoration)
      .toList();

  testWidgets('not done shows only the un-struck base text', (tester) async {
    await tester.pumpWidget(makeTestableWidget(wipe(done: false)));
    expect(find.text('Buy milk'), findsOneWidget);
    expect(decorations(tester), isNot(contains(TextDecoration.lineThrough)));
  });

  testWidgets('flipping to done wipes the strike on', (tester) async {
    await tester.pumpWidget(makeTestableWidget(wipe(done: false)));
    await tester.pumpWidget(makeTestableWidget(wipe(done: true)));
    // Mid-wipe the struck overlay is revealed over the base.
    await tester.pump(const Duration(milliseconds: 120));
    expect(decorations(tester), contains(TextDecoration.lineThrough));
    await tester.pumpAndSettle();
  });

  testWidgets('already done on first build shows the struck text', (
    tester,
  ) async {
    await tester.pumpWidget(makeTestableWidget(wipe(done: true)));
    await tester.pump();
    expect(decorations(tester), contains(TextDecoration.lineThrough));
  });

  testWidgets('reduced motion applies the struck state instantly', (
    tester,
  ) async {
    Widget tree({required bool done}) => makeTestableWidget(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: wipe(done: done),
        ),
      ),
    );
    await tester.pumpWidget(tree(done: false));
    await tester.pumpWidget(tree(done: true));
    await tester.pump();
    expect(decorations(tester), contains(TextDecoration.lineThrough));
  });

  testWidgets('animate: false applies the struck state instantly', (
    tester,
  ) async {
    await tester.pumpWidget(makeTestableWidget(wipe(done: false)));
    await tester.pumpWidget(
      makeTestableWidget(wipe(done: true, animate: false)),
    );
    // No wipe to wait out: a single frame already shows the struck overlay
    // (an animated wipe would still be at value 0 here).
    await tester.pump();
    expect(decorations(tester), contains(TextDecoration.lineThrough));
  });
}
