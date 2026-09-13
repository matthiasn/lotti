import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/captions/ds_tiered_text.dart';

void main() {
  const style = TextStyle(fontSize: 14);
  const tiers = [
    'with Pip · last spoke Sat 1 Aug',
    'with Pip',
    'Pip',
  ];

  Future<void> pump(
    WidgetTester tester, {
    required double width,
    int maxLines = 1,
    String? semanticsLabel,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: DsTieredText(
            tiers: tiers,
            style: style,
            maxLines: maxLines,
            semanticsLabel: semanticsLabel,
            textKey: const ValueKey('tiered'),
          ),
        ),
      ),
    ),
  );

  Text rendered(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('tiered')));

  testWidgets('shows the widest tier that fits on one line', (tester) async {
    await pump(tester, width: 600);
    expect(rendered(tester).data, tiers.first);
    expect(rendered(tester).maxLines, 1);
  });

  testWidgets('sheds whole tiers as the space narrows', (tester) async {
    await pump(tester, width: 140);
    expect(rendered(tester).data, 'with Pip');
    await pump(tester, width: 60);
    expect(rendered(tester).data, 'Pip');
  });

  testWidgets('only the narrowest tier may take more than one line, and it '
      'ellipsizes past that', (tester) async {
    await pump(tester, width: 20, maxLines: 2);
    final text = rendered(tester);
    expect(text.data, 'Pip');
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
    // A tier that fits never gets the fallback line count.
    await pump(tester, width: 600, maxLines: 2);
    expect(rendered(tester).maxLines, 1);
  });

  testWidgets('assistive technology hears the full wording whatever the '
      'screen shows', (tester) async {
    await pump(tester, width: 60);
    expect(rendered(tester).data, 'Pip');
    expect(rendered(tester).semanticsLabel, tiers.first);
    await pump(tester, width: 60, semanticsLabel: 'Status: with Pip');
    expect(rendered(tester).semanticsLabel, 'Status: with Pip');
  });
}
