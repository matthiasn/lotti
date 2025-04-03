import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/manual/widget/showcase_with_widget.dart';
import 'package:showcaseview/showcaseview.dart';

void main() {
  testWidgets('Displays description', (WidgetTester tester) async {
    final showcaseKey = GlobalKey();
    const Widget description = Text('This is a description');
    const Widget child = Text('Child Widget');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShowCaseWidget(
            builder: (context) => ShowcaseWithWidget(
              showcaseKey: showcaseKey,
              description: description,
              startNav: true,
              child: child,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    ShowCaseWidget.of(tester.element(find.byType(ShowcaseWithWidget)))
        .startShowCase([showcaseKey]);

    await tester.pumpAndSettle();

    expect(find.text('This is a description'), findsOneWidget);
  });

  testWidgets('Display of child Widget', (WidgetTester tester) async {
    final showcaseKey1 = GlobalKey();
    const Widget description1 = Text('This is a description');
    const Widget child1 = Text('Child Widget');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShowCaseWidget(
            builder: (context) => ShowcaseWithWidget(
              showcaseKey: showcaseKey1,
              description: description1,
              child: child1,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Child Widget'), findsOneWidget);
  });
}
