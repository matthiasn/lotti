import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

import '../widget_test_utils.dart';

void main() {
  setUp(() async {
    await setUpTestGetIt();
  });
  tearDown(tearDownTestGetIt);

  group('EmptyScaffoldWithTitle', () {
    testWidgets('renders the title in a TitleAppBar above the body', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const EmptyScaffoldWithTitle(
            'Nothing here',
            body: Text('body content'),
          ),
        ),
      );
      // Let the TitleAppBar fadeIn animation (1s) finish so no timer leaks.
      await tester.pump(const Duration(seconds: 1));

      final appBarTitle = find.descendant(
        of: find.byType(TitleAppBar),
        matching: find.text('Nothing here'),
      );
      expect(appBarTitle, findsOneWidget);
      expect(find.text('body content'), findsOneWidget);
    });

    testWidgets('renders without a body', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const EmptyScaffoldWithTitle('Just a title'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Just a title'), findsOneWidget);
      expect(tester.widget<Scaffold>(find.byType(Scaffold)).body, isNull);
    });
  });
}
