import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/transcript/folded_words.dart';
import 'package:material_ui/material_ui.dart';

import '../../widget_test_utils.dart';

void main() {
  final long = [
    for (var i = 1; i <= 14; i++) 'Sentence $i of what Pip said.',
  ].join(' ');

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(SizedBox(width: 320, child: child)),
    );
    await tester.pump();
  }

  Text words(WidgetTester tester, String id) =>
      tester.widget<Text>(find.byKey(ValueKey('folded-words-$id')));

  testWidgets('words that fit carry no Show more that would reveal nothing', (
    tester,
  ) async {
    await pump(tester, const FoldedWords(id: 'w', words: 'Short.'));

    expect(words(tester, 'w').data, 'Short.');
    expect(find.byKey(const ValueKey('folded-words-more-w')), findsNothing);
  });

  testWidgets('long words fold at three lines in the words tier; Show more '
      'opens them in place and says it is expanded, Show less folds them', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, FoldedWords(id: 'w', words: long));

    final context = tester.element(find.byType(FoldedWords));
    final tokens = context.designTokens;
    expect(words(tester, 'w').maxLines, FoldedWords.foldedLines);
    expect(words(tester, 'w').overflow, TextOverflow.ellipsis);
    final style = words(tester, 'w').style;
    expect(style, FoldedWords.wordsStyle(context));
    expect(style?.color, tokens.colors.text.highEmphasis);
    expect(
      style?.fontSize,
      tokens.typography.styles.body.bodySmall.fontSize,
    );
    expect(
      tester.getSemantics(find.text('Show more')),
      isSemantics(isButton: true, hasExpandedState: true, isExpanded: false),
    );

    await tester.tap(find.text('Show more'));
    await tester.pump();
    expect(words(tester, 'w').maxLines, isNull);
    expect(
      tester.getSemantics(find.text('Show less')),
      isSemantics(isButton: true, hasExpandedState: true, isExpanded: true),
    );

    await tester.tap(find.text('Show less'));
    await tester.pump();
    expect(words(tester, 'w').maxLines, FoldedWords.foldedLines);
    semantics.dispose();
  });

  testWidgets('a summary leads, and Show more opens to the words themselves', (
    tester,
  ) async {
    await pump(
      tester,
      const FoldedWords(id: 'w', words: 'Short words.', summary: 'The gist.'),
    );

    expect(words(tester, 'w').data, 'The gist.');
    // There is more behind a summary even when the words are short.
    await tester.tap(find.text('Show more'));
    await tester.pump();
    expect(words(tester, 'w').data, 'Short words.');
  });

  testWidgets('a host style replaces the words tier', (tester) async {
    const style = TextStyle(fontSize: 11, color: Color(0xFF00FF00));
    await pump(tester, const FoldedWords(id: 'w', words: 'x', style: style));

    expect(words(tester, 'w').style, style);
  });

  testWidgets('Show more answers a pointer with the hover ink', (tester) async {
    await pump(tester, FoldedWords(id: 'w', words: long));
    final tokens = tester.element(find.byType(FoldedWords)).designTokens;
    expect(
      tester.widget<Text>(find.text('Show more')).style?.color,
      tokens.colors.interactive.enabled,
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.text('Show more')));
    await tester.pump();
    expect(
      tester.widget<Text>(find.text('Show more')).style?.color,
      tokens.colors.interactive.hover,
    );
  });

  testWidgets('opened words survive being scrolled out of a lazy list and '
      'back', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: SizedBox(
            width: 320,
            height: 400,
            child: ListView.builder(
              controller: controller,
              itemCount: 60,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: FoldedWords(id: 'row-$i', words: long),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('folded-words-more-row-0')));
    await tester.pump();
    expect(words(tester, 'row-0').maxLines, isNull);

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    expect(find.byKey(const ValueKey('folded-words-more-row-1')), findsNothing);
    controller.jumpTo(0);
    await tester.pump();

    expect(
      words(tester, 'row-0').maxLines,
      isNull,
      reason: "the reader's Show more is not undone by scrolling",
    );
  });
}
