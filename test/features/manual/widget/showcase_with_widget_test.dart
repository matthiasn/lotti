import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/manual/widget/showcase_with_widget.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:showcaseview/showcaseview.dart';

void main() {
  Widget createTestWidget({
    required GlobalKey showcaseKey,
    required Widget description,
    required Widget child,
    bool startNav = false,
  }) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.light(
          surfaceContainerHigh: Colors.grey[200],
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.dark(
          surfaceContainerHigh: Colors.grey[800],
        ),
        useMaterial3: true,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ShowCaseWidget(
          builder: (context) => ShowcaseWithWidget(
            showcaseKey: showcaseKey,
            description: description,
            startNav: startNav,
            child: child,
          ),
        ),
      ),
    );
  }

  testWidgets('Displays description', (WidgetTester tester) async {
    final showcaseKey = GlobalKey();
    const Widget description = Text('This is a description');
    const Widget child = Text('Child Widget');

    await tester.pumpWidget(
      createTestWidget(
        showcaseKey: showcaseKey,
        description: description,
        child: child,
        startNav: true,
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
      createTestWidget(
        showcaseKey: showcaseKey1,
        description: description1,
        child: child1,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Child Widget'), findsOneWidget);
  });
}
